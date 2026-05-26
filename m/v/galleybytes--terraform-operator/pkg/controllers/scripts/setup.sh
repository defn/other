#!/bin/bash -e
set -o errexit

export HOME=/home/ubuntu

out="$TFO_ROOT_PATH"/generations/$TFO_GENERATION
vardir="$out/tfvars"
if [[ "$TFO_CLEANUP_DISK" == "true" ]]; then
    rm -rf "$TFO_ROOT_PATH"/generations/* || true
fi
mkdir -p "$out"
mkdir -p "$vardir"

if [[ -d "$TFO_MAIN_MODULE" ]]; then
    rm -rf "$TFO_MAIN_MODULE" || true
fi

# The controller injects module content into the addons configmap.
# Copy all addon files into the main module directory.
mkdir -p "$TFO_MAIN_MODULE"
false | cp -iLr "$TFO_MAIN_MODULE_ADDONS"/* "$TFO_MAIN_MODULE" 2>/dev/null || true

cd "$TFO_MAIN_MODULE"

# Remove operator metadata files from the module directory.
rm -f .__TFO__*.json

# Load backend override
if stat backend_override.tf >/dev/null 2>/dev/null; then
    echo "Using custom backend"
else
    echo "Loading backend from spec"
    envsubst </backend.tf >"$TFO_ROOT_PATH/backend_override.tf"
    mv "$TFO_ROOT_PATH/backend_override.tf" .
fi
