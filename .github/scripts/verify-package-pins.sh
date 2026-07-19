#!/usr/bin/env bash
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")/../.."

pins_file="TimescaleDB-PostGIS/timescaledb-pins.json"
packages_file="$(mktemp)"
trap 'rm -f "$packages_file"' EXIT

curl -fsSL \
	"https://packagecloud.io/timescale/timescaledb/debian/dists/bullseye/main/binary-amd64/Packages" \
	>"$packages_file"

package_exists() {
	local package="$1"
	local version="$2"

	awk -v package="$package" -v version="$version" '
		BEGIN { RS = ""; FS = "\n" }
		$0 ~ "Package: " package "(\n|$)" {
			foundVersion = 0
			for (i = 1; i <= NF; i++) {
				if ($i == "Version: " version) {
					foundVersion = 1
				}
			}
			if (foundVersion) {
				found = 1
			}
		}
		END { exit !found }
	' "$packages_file"
}

mapfile -t versions < <(jq -r 'keys[]' "$pins_file" | sort -V)

for version in "${versions[@]}"; do
	version_file="TimescaleDB-PostGIS/${version}/.versions.json"
	dockerfile="TimescaleDB-PostGIS/${version}/Dockerfile"

	timescaledb_package=$(jq -r --arg version "$version" '.[$version].timescaledb.package' "$pins_file")
	timescaledb_version=$(jq -r --arg version "$version" '.[$version].timescaledb.version' "$pins_file")
	toolkit_package=$(jq -r --arg version "$version" '.[$version].toolkit.package' "$pins_file")
	toolkit_version=$(jq -r --arg version "$version" '.[$version].toolkit.version' "$pins_file")

	package_exists "timescaledb-2-loader-postgresql-${version}" "$timescaledb_version"
	package_exists "$timescaledb_package" "$timescaledb_version"
	package_exists "$toolkit_package" "$toolkit_version"

	test "$(jq -r '.TIMESCALEDB_VERSION' "$version_file")" = "$timescaledb_version"
	test "$(jq -r '.TIMESCALEDB_TOOLKIT_VERSION' "$version_file")" = "$toolkit_version"

	grep -Fq "\"timescaledb-2-loader-postgresql-\${PG_MAJOR}=${timescaledb_version}\"" "$dockerfile"
	grep -Fq "\"timescaledb-2-postgresql-\${PG_MAJOR}=${timescaledb_version}\"" "$dockerfile"
	grep -Fq "\"timescaledb-toolkit-postgresql-\${PG_MAJOR}=${toolkit_version}\"" "$dockerfile"

	echo "ok PostgreSQL ${version}: TimescaleDB ${timescaledb_version}, Toolkit ${toolkit_version}"
done
