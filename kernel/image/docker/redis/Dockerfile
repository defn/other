# Dockerfile.redis - Minimal Redis server image.
# Image: defn.dev/devcontainer/redis

# FROM: index.docker.io/library/ubuntu:noble
# OCI digest pinned in m/oci/images.edn, verified by: mise run dev-pull
FROM defn.dev/external/ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 6379

CMD ["redis-server", "--bind", "127.0.0.1", "--maxmemory", "128mb", "--maxmemory-policy", "allkeys-lru", "--save", "", "--appendonly", "no"]
