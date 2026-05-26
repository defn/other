# Dockerfile.edge - Incremental layer on base, rebuilt frequently.
# Copies fresh .git and reinstalls only if mise.toml changed.
# Image: defn.dev/devcontainer/dev:edge
#
# Build with:
# docker build --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN ...

# Global ARGs -- declared before any FROM so they're available to FROM
# statements. Must be re-declared inside each stage that references them
# in non-FROM instructions.
#
ARG BASE_IMAGE=defn.dev/devcontainer/dev:base
# GIT_COMMIT is set by dev-edge.clj from the current HEAD SHA. Surfaced
# as an image label and /etc/defn-git-sha so operators can verify which
# revision a running container was built from.
ARG GIT_COMMIT=unknown

# ---- main edge stage ----
FROM ${BASE_IMAGE}
ARG GIT_COMMIT
LABEL org.opencontainers.image.revision=${GIT_COMMIT}
RUN echo "${GIT_COMMIT}" | sudo tee /etc/defn-git-sha >/dev/null

WORKDIR /home/ubuntu

# Refresh git repo from local copy
COPY --chown=ubuntu:ubuntu .git /home/ubuntu/.git
RUN git reset --hard && git clean -fd

# Reinstall tools if mise.toml changed.
# Two RUNs (see base/Dockerfile for rationale): java first without the
# downloads cache mount (mise's cross-fs copy fallback mishandles graalvm's
# relative symlinks), then the rest with the downloads cache mount.
WORKDIR /home/ubuntu/m
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    --mount=type=cache,id=mise-cache,target=/home/ubuntu/.cache/mise,uid=1000,gid=1000 \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) \
    && mise trust /home/ubuntu/mise.toml \
    && mise trust /home/ubuntu/m/mise.toml \
    && mise install java
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    --mount=type=cache,id=mise-cache,target=/home/ubuntu/.cache/mise,uid=1000,gid=1000 \
    --mount=type=cache,id=mise-downloads,target=/home/ubuntu/.local/share/mise/downloads,uid=1000,gid=1000 \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) \
    MISE_ALWAYS_KEEP_DOWNLOAD=true \
    && mise install

# Add bazel symlink inside bazelisk install dir so mise reshim creates a bazel shim;
# also keep /usr/local/bin/bazel for VSCode which searches non-mise paths
RUN ln -sf bazelisk "$(mise where bazelisk)/bazel" && mise reshim \
    && sudo ln -nfs "$(mise where bazelisk)/bazelisk" /usr/local/bin/bazel

# Provide /opt/homebrew/bin -> mise shims so a macOS host gitconfig
# mounted into the container resolves Homebrew-style absolute paths
# (e.g. core.sshCommand=/opt/homebrew/bin/gh) against mise tools.
RUN sudo mkdir -p /opt/homebrew \
    && sudo ln -nfs /home/ubuntu/.local/share/mise/shims /opt/homebrew/bin

# Build and install defn from the in-tree fork. defn afs subsumes what
# /usr/local/bin/artifact-fs used to do (forwards to the fork's cli.Run),
# so pitchfork can call /usr/local/bin/defn afs daemon ... instead of an
# upstream binary. Runtime fuse3 package is supplied by base.
#
# Build via bazelisk (not plain `go build`): the defn CLI imports from
# m/v/cloudflare--artifact-fs/ through a thin re-export wrapper, but
# some transitive paths still cross Go's internal-package rule; Bazel
# doesn't enforce that rule and produces the same binary.
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    --mount=type=cache,id=bazel-cache,target=/home/ubuntu/.cache/bazel,uid=1000,gid=1000 \
    --mount=type=cache,id=bazelisk-cache,target=/home/ubuntu/.cache/bazelisk,uid=1000,gid=1000 \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) \
    && mise exec -- bazelisk build //tenant/defn/go/cmd/defn:defn \
    && sudo install -m 0755 bazel-bin/tenant/defn/go/cmd/defn/defn_/defn /usr/local/bin/defn \
    && mise exec -- bazelisk shutdown \
    && rm -f bazel-bin bazel-m bazel-out bazel-testlogs

# Pre-create the CLI's default state dir with ubuntu ownership so the
# home-afs named volume inherits these permissions on first mount.
RUN sudo mkdir -p /var/lib/artifact-fs \
    && sudo chown ubuntu:ubuntu /var/lib/artifact-fs

WORKDIR /home/ubuntu
