// Phase 1 only: a self-contained single-cell target to validate the Dockerfile
// through docker buildx bake. Phase 2 replaces this with the matrixed "postgis"
// target layered over cloudnative-pg/postgres-containers' source docker-bake.hcl.

variable "REGISTRY" {
  default = "localhost"
}

target "local" {
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/arm64"]
  tags       = ["${REGISTRY}/timescaledb-postgis:17-3-standard-trixie-local"]
  args = {
    BASE                        = "ghcr.io/cloudnative-pg/postgresql:17.10-standard-trixie"
    PG_MAJOR                    = "17"
    POSTGIS_MAJOR               = "3"
    POSTGIS_VERSION             = "3.6.4+dfsg-2.pgdg13+1"
    TIMESCALEDB_VERSION         = "2.28.3~debian13-1710"
    TIMESCALEDB_TOOLKIT_VERSION = "1:1.23.0~debian13"
  }
}
