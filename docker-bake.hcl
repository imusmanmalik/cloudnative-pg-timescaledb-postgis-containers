// TimescaleDB-PostGIS bake matrix, layered on top of cloudnative-pg/postgres-containers'
// docker-bake.hcl. In CI the reusable workflow checks that repo out at ./source and passes
// bake_files: "./source/docker-bake.hcl,./docker-bake.hcl". Locally, fetch it the same way:
//   curl -sSL https://raw.githubusercontent.com/cloudnative-pg/postgres-containers/main/docker-bake.hcl -o source/docker-bake.hcl
//   docker buildx bake -f source/docker-bake.hcl -f docker-bake.hcl --print postgis
//
// Inherited from source: registry, environment, revision, now, postgreSQLVersions,
// postgreSQLPreviewVersions, getPgVersions, cleanVersion, getMajor, isPreview.

fullname = (environment == "testing") ? "${registry}/timescaledb-postgis-testing" : "${registry}/timescaledb-postgis"

variable "postgisMajorVersions" {
  default = ["3"]
}

variable "distributions" {
  default = [
    "bookworm",
    "trixie",
  ]
}

variable "imageTypes" {
  default = [
    "standard",
    "system",
  ]
}

// PostGIS apt pins, mirroring cloudnative-pg/postgis-containers' postgisMatrix.
postgisMatrix = {
  bookworm = {
    // renovate: suite=bookworm-pgdg depName=postgis
    "3" = "3.6.4+dfsg-2.pgdg12+1"
  }
  trixie = {
    // renovate: suite=trixie-pgdg depName=postgis
    "3" = "3.6.4+dfsg-2.pgdg13+1"
  }
}

// TimescaleDB + toolkit apt pins per distro and PG major (packagecloud). A (distro, major)
// pair absent here is dropped from the build matrix: pg14 has no trixie packages, and any
// preview major (e.g. 19) has none at all. pg14 bookworm is frozen at 2.19.3 upstream, and
// its toolkit is pinned to 1.19.0 - the newest version present on BOTH amd64 and arm64
// (arm64's 1.20.0 has no amd64 build, so a single multi-arch pin cannot use it).
// Each pin sits on its own line with a renovate marker so the custom regex manager can
// bump tsdb and toolkit independently (datasource=deb against the packagecloud repo).
timescaledbMatrix = {
  bookworm = {
    "14" = {
      // renovate: datasource=deb suite=bookworm depName=timescaledb-2-postgresql-14
      tsdb = "2.19.3~debian12"
      // renovate: datasource=deb suite=bookworm depName=timescaledb-toolkit-postgresql-14
      toolkit = "1:1.19.0~debian12"
    }
    "15" = {
      // renovate: datasource=deb suite=bookworm depName=timescaledb-2-postgresql-15
      tsdb = "2.28.3~debian12-1518"
      // renovate: datasource=deb suite=bookworm depName=timescaledb-toolkit-postgresql-15
      toolkit = "1:1.23.0~debian12"
    }
    "16" = {
      // renovate: datasource=deb suite=bookworm depName=timescaledb-2-postgresql-16
      tsdb = "2.28.3~debian12-1614"
      // renovate: datasource=deb suite=bookworm depName=timescaledb-toolkit-postgresql-16
      toolkit = "1:1.23.0~debian12"
    }
    "17" = {
      // renovate: datasource=deb suite=bookworm depName=timescaledb-2-postgresql-17
      tsdb = "2.28.3~debian12-1710"
      // renovate: datasource=deb suite=bookworm depName=timescaledb-toolkit-postgresql-17
      toolkit = "1:1.23.0~debian12"
    }
    "18" = {
      // renovate: datasource=deb suite=bookworm depName=timescaledb-2-postgresql-18
      tsdb = "2.28.3~debian12-1804"
      // renovate: datasource=deb suite=bookworm depName=timescaledb-toolkit-postgresql-18
      toolkit = "1:1.23.0~debian12"
    }
  }
  trixie = {
    "15" = {
      // renovate: datasource=deb suite=trixie depName=timescaledb-2-postgresql-15
      tsdb = "2.28.3~debian13-1518"
      // renovate: datasource=deb suite=trixie depName=timescaledb-toolkit-postgresql-15
      toolkit = "1:1.23.0~debian13"
    }
    "16" = {
      // renovate: datasource=deb suite=trixie depName=timescaledb-2-postgresql-16
      tsdb = "2.28.3~debian13-1614"
      // renovate: datasource=deb suite=trixie depName=timescaledb-toolkit-postgresql-16
      toolkit = "1:1.23.0~debian13"
    }
    "17" = {
      // renovate: datasource=deb suite=trixie depName=timescaledb-2-postgresql-17
      tsdb = "2.28.3~debian13-1710"
      // renovate: datasource=deb suite=trixie depName=timescaledb-toolkit-postgresql-17
      toolkit = "1:1.23.0~debian13"
    }
    "18" = {
      // renovate: datasource=deb suite=trixie depName=timescaledb-2-postgresql-18
      tsdb = "2.28.3~debian13-1804"
      // renovate: datasource=deb suite=trixie depName=timescaledb-toolkit-postgresql-18
      toolkit = "1:1.23.0~debian13"
    }
  }
}

function getPostgisPackage {
  params = [distro, postgisMajor]
  result = postgisMatrix[distro][postgisMajor]
}

// Extract the upstream PostGIS version (e.g. "3.6.4") from the apt pin string
// "3.6.4+dfsg-2.pgdg13+1". Used in image tags so the catalog generator's regex can
// parse <pgFull>-<postgisFull>-<date> out of them.
function getPostgisVersion {
  params = [distro, postgisMajor]
  result = regex("^[0-9]+\\.[0-9]+\\.[0-9]+", postgisMatrix[distro][postgisMajor])
}

function hasTimescaledb {
  params = [distro, pgMajor]
  result = contains(keys(timescaledbMatrix[distro]), pgMajor)
}

function getTimescaledb {
  params = [distro, pgMajor]
  result = timescaledbMatrix[distro][pgMajor].tsdb
}

function getTimescaledbToolkit {
  params = [distro, pgMajor]
  result = timescaledbMatrix[distro][pgMajor].toolkit
}

function getBaseImage {
  params = [pgVersion, imageType, distro]
  result = format("ghcr.io/cloudnative-pg/postgresql:%s-%s-%s", cleanVersion(pgVersion), imageType, distro)
}

// Precompute the buildable cells. A bake matrix is a pure cartesian product with no native
// exclude, so we filter here with hasTimescaledb() and feed the surviving cells in as a
// single object-valued matrix key.
cells = flatten([
  for tgt in imageTypes : flatten([
    for distro in distributions : [
      for pgVersion in getPgVersions(postgreSQLVersions, postgreSQLPreviewVersions) : {
        tgt       = tgt
        distro    = distro
        pgVersion = pgVersion
        pgMajor   = getMajor(pgVersion)
      }
      if hasTimescaledb(distro, getMajor(pgVersion))
    ]
  ])
])

target "postgis" {
  matrix = {
    postgisMajor = postgisMajorVersions
    cell         = cells
  }
  name = "postgis-${postgisMajor}-${cell.pgMajor}-${cell.tgt}-${cell.distro}"

  context    = "."
  dockerfile = "cwd://Dockerfile"
  platforms  = ["linux/amd64", "linux/arm64"]

  args = {
    BASE                        = getBaseImage(cell.pgVersion, cell.tgt, cell.distro)
    PG_MAJOR                    = cell.pgMajor
    POSTGIS_MAJOR               = postgisMajor
    POSTGIS_VERSION             = getPostgisPackage(cell.distro, postgisMajor)
    TIMESCALEDB_VERSION         = getTimescaledb(cell.distro, cell.pgMajor)
    TIMESCALEDB_TOOLKIT_VERSION = getTimescaledbToolkit(cell.distro, cell.pgMajor)
  }

  // Tag shape mirrors upstream postgis so the catalog generator can parse
  // <pgFull>-<postgisFull>-<YYYYMMDDhhmm> from the dated tag. TimescaleDB version is
  // carried in labels, not the tag.
  tags = [
    "${fullname}:${cell.pgMajor}-${getPostgisVersion(cell.distro, postgisMajor)}-${cell.tgt}-${cell.distro}",
    "${fullname}:${cleanVersion(cell.pgVersion)}-${getPostgisVersion(cell.distro, postgisMajor)}-${cell.tgt}-${cell.distro}",
    "${fullname}:${cleanVersion(cell.pgVersion)}-${getPostgisVersion(cell.distro, postgisMajor)}-${formatdate("YYYYMMDDhhmm", now)}-${cell.tgt}-${cell.distro}",
  ]

  labels = {
    "org.opencontainers.image.title" = "timescaledb-postgis"
    "org.opencontainers.image.revision" = "${revision}"
    "io.timescaledb.version" = getTimescaledb(cell.distro, cell.pgMajor)
    "io.timescaledb.toolkit.version" = getTimescaledbToolkit(cell.distro, cell.pgMajor)
    "io.postgis.version" = getPostgisPackage(cell.distro, postgisMajor)
  }

  output = ["type=image,oci-mediatypes=true,oci-artifact=true"]
  attest = ["type=provenance,mode=max", "type=sbom"]
}
