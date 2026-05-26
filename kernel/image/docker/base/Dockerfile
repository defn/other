# Dockerfile.base - Heavy base image, rebuilt infrequently.
# Contains: apt packages, mise, git repo snapshot, all mise tools baked in.
# Image: defn.dev/devcontainer/dev:base
#
# Build with:
# docker build --secret id=GITHUB_TOKEN,env=GITHUB_TOKEN ...

# FROM: index.docker.io/library/ubuntu:noble
# OCI digest pinned in m/oci/images.edn, verified by: mise run dev-pull
# We reference by tag, not digest -- Docker rewrites OCI digests on load,
# producing a local digest unrelated to the source.
FROM defn.dev/external/ubuntu:noble AS base

ENV DEBIAN_FRONTEND=noninteractive

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bind9-dnsutils \
    build-essential \
    ca-certificates \
    curl \
    file \
    fuse3 \
    git \
    git-lfs \
    gnupg \
    htop \
    iptables \
    iproute2 \
    iputils-ping \
    jq \
    less \
    locales \
    lsof \
    net-tools \
    nginx \
    netcat-openbsd \
    pigz \
    nginx \
    openssh-client \
    postgresql-client \
    redis-tools \
    strace \
    sudo \
    tcpdump \
    tini \
    traceroute \
    tzdata \
    unzip \
    vim-nox \
    wget \
    zlib1g-dev \
    zsh \
    zstd \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo "America/Los_Angeles" > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TZ=America/Los_Angeles

# Install Docker CLI from official Docker repo
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | tee /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Configure ubuntu user (already exists in noble) with zsh and passwordless sudo.
# Remove default bash config files -- we use zsh with our own .zshrc.
RUN usermod -s /bin/zsh ubuntu \
    && echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ubuntu \
    && rm -f /home/ubuntu/.bash_logout /home/ubuntu/.bashrc /home/ubuntu/.profile

# Install mise
RUN curl -fsSL https://mise.run | sh \
    && mv /root/.local/bin/mise /usr/local/bin/mise

# GitHub SSH known hosts
RUN mkdir -p /home/ubuntu/.ssh \
    && ssh-keyscan github.com >> /home/ubuntu/.ssh/known_hosts 2>/dev/null \
    && chown -R ubuntu:ubuntu /home/ubuntu/.ssh \
    && chmod 700 /home/ubuntu/.ssh \
    && chmod 644 /home/ubuntu/.ssh/known_hosts

USER ubuntu
SHELL ["/bin/zsh", "-c"]
WORKDIR /home/ubuntu

# Pre-create mount points for docker-compose named volumes under
# /home/ubuntu/. Docker initializes a fresh named volume from the
# image's directory at the mount path; if the directory doesn't
# exist, Docker creates the mount point as root. Creating these as
# ubuntu-owned means the volume comes up writable by the ubuntu user
# even before post-start.clj runs its chown pass.
#
# Mirrors the named-volume mounts in m/.devcontainer/docker-compose.yml.
RUN mkdir -p /home/ubuntu/.local/share/mise \
    /home/ubuntu/.cache \
    /home/ubuntu/.config \
    /home/ubuntu/.claude \
    /home/ubuntu/.dotfiles \
    /home/ubuntu/.local/share/code-server/extensions

# Copy git repo and restore working tree
COPY --chown=ubuntu:ubuntu .git /home/ubuntu/.git
RUN git checkout -- .

# Bake mise shims into PATH
ENV PATH="/home/ubuntu/m/bin:/home/ubuntu/.local/share/mise/shims:/home/ubuntu/.local/bin:/usr/local/bin:/usr/bin:/bin"

# Trust all mise configs upfront (mise walks parent dirs)
RUN mise trust /home/ubuntu/mise.toml \
    && mise trust /home/ubuntu/m/mise.toml

# Install all tools (m/mise.toml + parent ~/mise.toml)
# GITHUB_TOKEN secret avoids GitHub API rate limits during tool downloads
# Read secret from file -- env= parameter needs explicit export for Docker secrets
#
# Two RUNs:
# 1. python/uv/pipx (ansible needs pipx) and java -- no downloads cache mount.
# mise's install path renames downloads/<extracted>/ -> installs/<version>/
# atomically when both are on the same fs. Cross-fs (cache mount on
# downloads/) forces a copy fallback that follows relative symlinks --
# graalvm's LICENSE_NATIVEIMAGE.txt -> lib/svm/... triggers ENOENT.
# 2. Everything else, with the downloads cache mount preserving archives
# across fresh base builds. Tools installed in step 1 are skipped here.
WORKDIR /home/ubuntu/m
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    --mount=type=cache,id=mise-cache,target=/home/ubuntu/.cache/mise,uid=1000,gid=1000 \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) \
    && mise install python uv pipx \
    && mise reshim \
    && mise install java
RUN --mount=type=secret,id=GITHUB_TOKEN,uid=1000 \
    --mount=type=cache,id=mise-cache,target=/home/ubuntu/.cache/mise,uid=1000,gid=1000 \
    --mount=type=cache,id=mise-downloads,target=/home/ubuntu/.local/share/mise/downloads,uid=1000,gid=1000 \
    export GITHUB_TOKEN=$(cat /run/secrets/GITHUB_TOKEN) \
    MISE_ALWAYS_KEEP_DOWNLOAD=true \
    && mise install
