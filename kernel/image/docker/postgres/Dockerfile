# Dockerfile.postgres - Minimal PostgreSQL server image.
# Image: defn.dev/devcontainer/postgres

# FROM: index.docker.io/library/ubuntu:noble
# OCI digest pinned in m/oci/images.edn, verified by: mise run dev-pull
FROM defn.dev/external/ubuntu:noble

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql \
    && rm -rf /var/lib/apt/lists/*

ENV PGDATA=/var/lib/postgresql/data/pgdata

# Initialize the database cluster as postgres user
RUN mkdir -p "$PGDATA" \
    && chown -R postgres:postgres /var/lib/postgresql \
    && su - postgres -c "/usr/lib/postgresql/16/bin/initdb -D $PGDATA"

EXPOSE 5432

USER postgres

CMD ["/usr/lib/postgresql/16/bin/postgres", "-D", "/var/lib/postgresql/data/pgdata", "-c", "listen_addresses=127.0.0.1"]
