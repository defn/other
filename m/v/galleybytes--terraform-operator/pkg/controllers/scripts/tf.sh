#!/bin/bash -e
set -o errexit

# Runner pods run as ubuntu (UID 1000). Mise shims are on PATH via .bashrc.
export HOME=/home/ubuntu
export PATH="/home/ubuntu/.local/share/mise/shims:$PATH"

function join_by {
  local d="$1" f=${2:-$(</dev/stdin)};
  if [[ -z "$f" ]]; then return 1; fi
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  else
    join_by "$d" $f
  fi
}

cd "$TFO_MAIN_MODULE"
out="$TFO_ROOT_PATH"/generations/$TFO_GENERATION
mkdir -p "$out"
vardir="$out/tfvars"
vars=
if [[ $(ls $vardir | wc -l) -gt 0 ]]; then
  vars="-var-file $(find $vardir -type f | sort -n | join_by ' -var-file ')"
fi

# archive_config snapshots the rendered tofu config (module sources,
# backend_override.tf, and tfvars) to the same S3 bucket that holds the
# state, so an out-of-band tool can later destroy the configuration. The
# defn fork removes destroy from the operator entirely; this archive is
# the durable record an external destroyer needs.
#
# The archive is written before any tofu task runs (init), so a runner
# pod that dies between apply and a hypothetical post-hoc upload still
# leaves a usable archive in the bucket. Bucket versioning provides
# history; the SHA-256 sidecar provides integrity.
archive_config() {
    local backend_file="$TFO_MAIN_MODULE/backend_override.tf"
    if [[ ! -f "$backend_file" ]]; then
        echo "archive_config: no backend_override.tf, skipping archive"
        return 0
    fi

    # Parse bucket and key out of the s3 backend block. Tolerates either
    # "bucket = \"...\"" or "bucket=\"...\"" with arbitrary whitespace.
    local bucket key
    bucket=$(grep -E '^[[:space:]]*bucket[[:space:]]*=' "$backend_file" \
        | head -1 | sed -E 's/[^"]*"([^"]+)".*/\1/')
    key=$(grep -E '^[[:space:]]*key[[:space:]]*=' "$backend_file" \
        | head -1 | sed -E 's/[^"]*"([^"]+)".*/\1/')

    if [[ -z "$bucket" || -z "$key" ]]; then
        echo "archive_config: backend is not s3 (no bucket/key parsed), skipping archive"
        return 0
    fi

    local stage archive sum
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' RETURN

    # Stage module sources (includes backend_override.tf) and tfvars.
    mkdir -p "$stage/module"
    cp -aL "$TFO_MAIN_MODULE"/. "$stage/module/"
    if [[ -d "$vardir" ]] && [[ $(ls -A "$vardir" 2>/dev/null | wc -l) -gt 0 ]]; then
        mkdir -p "$stage/tfvars"
        cp -aL "$vardir"/. "$stage/tfvars/"
    fi

    archive="$out/config.tar.zst"
    tar -C "$stage" -cf - . | zstd -q -o "$archive"
    sum=$(sha256sum "$archive" | awk '{print $1}')
    echo "$sum  $(basename "$archive")" > "$archive.sha256"

    # Sibling keys next to <prefix>/<workspace>.tfstate.
    local archive_key="${key%.tfstate}.tar.zst"
    local sum_key="${archive_key}.sha256"

    echo "archive_config: uploading s3://${bucket}/${archive_key} (sha256=${sum})"
    aws s3 cp "$archive"        "s3://${bucket}/${archive_key}"
    aws s3 cp "$archive.sha256" "s3://${bucket}/${sum_key}"
}

case "$TFO_TASK" in
    init)
        archive_config
        tofu init 2>&1
        ;;
    plan)
        tofu plan $vars -out tfplan 2>&1
        plan_status=${PIPESTATUS[0]}
        if [[ $plan_status -gt 0 ]]; then
            exit $plan_status
        fi
        # Plan-to-apply binding: hash the binary plan file and persist
        # the hash to the PVC alongside it. The apply task verifies the
        # hash before invoking tofu apply, so a stale or substituted
        # tfplan is rejected. Surfaces the hash in pod logs so an
        # approver can record what they reviewed.
        sha=$(sha256sum tfplan | awk '{print $1}')
        echo "$sha" > tfplan.sha256
        echo "plan_sha256: $sha"

        # Action summary -- counts each resource_change action class
        # in the JSON-rendered plan. delete/replace counts surface
        # moved-block hazards (where state migration produces a
        # delete-then-create plan). Warn-only -- approval is the gate.
        if tofu show -json tfplan > tfplan.json 2>/dev/null && [[ -s tfplan.json ]]; then
            jq -r '
                .resource_changes // [] |
                map(.change.actions) |
                {
                    create:  map(select(. == ["create"])) | length,
                    update:  map(select(. == ["update"])) | length,
                    delete:  map(select(. == ["delete"])) | length,
                    replace: map(select((index("delete") != null) and (index("create") != null))) | length,
                    noop:    map(select(. == ["no-op"])) | length,
                    read:    map(select(. == ["read"])) | length
                } |
                "plan_actions: create=\(.create) update=\(.update) delete=\(.delete) replace=\(.replace) noop=\(.noop) read=\(.read)"
            ' tfplan.json
            cp tfplan.json "$out/tfplan.json" 2>/dev/null || true
        fi
        ;;
    apply)
        # Refuse to apply a plan whose hash doesn't match what was
        # captured at plan time. tfplan.sha256 was written by the plan
        # task in the same generation directory.
        if [[ ! -f tfplan ]]; then
            echo "apply: tfplan missing; refusing to apply" >&2
            exit 1
        fi
        if [[ ! -f tfplan.sha256 ]]; then
            echo "apply: tfplan.sha256 missing; this fork requires plan hashing" >&2
            exit 1
        fi
        expected=$(cat tfplan.sha256)
        actual=$(sha256sum tfplan | awk '{print $1}')
        if [[ "$expected" != "$actual" ]]; then
            echo "apply: tfplan hash mismatch (expected $expected, got $actual); refusing to apply" >&2
            exit 1
        fi
        echo "plan_sha256_verified: $actual"
        tofu apply tfplan 2>&1
        ;;
    init-delete | plan-delete | apply-delete)
        # Destroy is removed from this fork. Destruction is handled out of
        # band. Nullify any destroy task as a successful no-op so the
        # workflow cannot tear down infrastructure even if the controller
        # somehow schedules a destroy pod.
        echo "destroy task '$TFO_TASK' is disabled in this fork; no-op"
        exit 0
        ;;
    *)
        echo "tf.sh: unknown TFO_TASK='$TFO_TASK'" >&2
        exit 1
        ;;
esac
status=${PIPESTATUS[0]}
if [[ $status -gt 0 ]];then exit $status;fi

# Outputs are written to status by the controller, not by the runner pod.
# The controller reads outputs from the tofu state after apply completes.
