#!/usr/bin/env bash
#
# Regenerate Dockerfiles and version metadata after TimescaleDB pin changes.
#
set -Eeuo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

PINS_FILE="timescaledb-pins.json"
POSTGRESQL_LATEST_MAJOR_RELEASE=17

record_version() {
	local versionFile="$1"
	local component="$2"
	local componentVersion="$3"

	jq -S --arg component "${component}" \
		--arg componentVersion "${componentVersion}" \
		'.[$component] = $componentVersion' <"${versionFile}" >>"${versionFile}.new"

	mv "${versionFile}.new" "${versionFile}"
}

pin_value() {
	local version="$1"
	local component="$2"
	local pin

	pin=$(jq -r --arg version "$version" --arg component "$component" \
		'.[$version][$component].version // ""' "$PINS_FILE")
	if [ -z "$pin" ]; then
		echo "No ${component} pin configured for PostgreSQL ${version}" >&2
		exit 1
	fi
	echo "$pin"
}

render_dockerfile() {
	local version="$1"
	local versionFile="$version/.versions.json"
	local dockerTemplate="Dockerfile.template"

	if [[ ${version} -gt "${POSTGRESQL_LATEST_MAJOR_RELEASE}" ]]; then
		dockerTemplate="Dockerfile-beta.template"
	fi

	cp -r src/* "$version/"

	sed -e 's/%%POSTGIS_IMAGE_VERSION%%/'"$(jq -r '.POSTGIS_IMAGE_VERSION' "$versionFile")"'/g' \
		-e 's/%%IMAGE_RELEASE_VERSION%%/'"$(jq -r '.IMAGE_RELEASE_VERSION' "$versionFile")"'/g' \
		-e 's/%%TIMESCALEDB_VERSION%%/'"$(jq -r '.TIMESCALEDB_VERSION' "$versionFile")"'/g' \
		-e 's/%%TIMESCALEDB_TOOLKIT_VERSION%%/'"$(jq -r '.TIMESCALEDB_TOOLKIT_VERSION' "$versionFile")"'/g' \
		"${dockerTemplate}" \
		>"$version/Dockerfile"
}

versions=("$@")
if [ ${#versions[@]} -eq 0 ]; then
	for version in */; do
		[[ $version = src/ ]] && continue
		versions+=("$version")
	done
fi
versions=("${versions[@]%/}")

for version in "${versions[@]}"; do
	versionFile="${version}/.versions.json"
	if [ ! -f "$versionFile" ]; then
		echo "Version file not found: $versionFile" >&2
		exit 1
	fi

	timescaledbVersion=$(pin_value "$version" "timescaledb")
	timescaledbToolkitVersion=$(pin_value "$version" "toolkit")
	oldTimescaledbVersion=$(jq -r '.TIMESCALEDB_VERSION // ""' "$versionFile")
	oldTimescaledbToolkitVersion=$(jq -r '.TIMESCALEDB_TOOLKIT_VERSION // ""' "$versionFile")
	oldImageReleaseVersion=$(jq -r '.IMAGE_RELEASE_VERSION' "$versionFile")
	newRelease=false

	if [ "$oldTimescaledbVersion" != "$timescaledbVersion" ]; then
		echo "TimescaleDB changed from $oldTimescaledbVersion to $timescaledbVersion"
		record_version "$versionFile" "TIMESCALEDB_VERSION" "$timescaledbVersion"
		newRelease=true
	fi

	if [ "$oldTimescaledbToolkitVersion" != "$timescaledbToolkitVersion" ]; then
		echo "TimescaleDB Toolkit changed from $oldTimescaledbToolkitVersion to $timescaledbToolkitVersion"
		record_version "$versionFile" "TIMESCALEDB_TOOLKIT_VERSION" "$timescaledbToolkitVersion"
		newRelease=true
	fi

	if [ "$newRelease" = "true" ]; then
		record_version "$versionFile" "IMAGE_RELEASE_VERSION" "$((oldImageReleaseVersion + 1))"
	fi

	render_dockerfile "$version"
done
