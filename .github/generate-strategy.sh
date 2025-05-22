#!/usr/bin/env bash
#
# Given a list of PostgreSQL versions (defined as directories in the root
# folder of the project), this script generates a JSON object that will be used
# inside the Github workflows as a strategy to create a matrix of jobs to run.
# The JSON object contains, for each PostgreSQL version, the tags of the
# container image to be built.
#
set -eu

# Check for required dependencies
command -v curl >/dev/null 2>&1 || {
	echo "Error: curl is required but not installed."
	exit 1
}
command -v jq >/dev/null 2>&1 || {
	echo "Error: jq is required but not installed."
	exit 1
}

# Define an optional aliases for some major versions
declare -A aliases=(
	[17]='latest'
)

GITHUB_ACTIONS=${GITHUB_ACTIONS:-false}

# Function to check if a specific PostgreSQL version supports ARM64
check_platform_support() {
	local version=$1
	local postgis_version=$2
	local image="postgis/postgis:${version}-${postgis_version}"
	local api_url="https://hub.docker.com/v2/repositories/postgis/postgis/tags/${version}-${postgis_version}"
	local max_retries=3
	local retry_count=0
	local response=""

	# Try the API request with retries
	while [ $retry_count -lt $max_retries ]; do
		response=$(curl -s -f --connect-timeout 5 --max-time 10 "$api_url" || echo "")

		if [ -n "$response" ]; then
			# Check if the response is valid JSON and contains the expected structure
			if echo "$response" | jq -e '.images' >/dev/null 2>&1; then
				if echo "$response" | jq -e '.images[] | select(.architecture == "arm64")' >/dev/null 2>&1; then
					echo "linux/amd64,linux/arm64"
					return 0
				else
					echo "linux/amd64"
					return 0
				fi
			fi
		fi

		retry_count=$((retry_count + 1))
		if [ $retry_count -lt $max_retries ]; then
			echo "Warning: API request failed, retrying... (${retry_count}/${max_retries})" >&2
			sleep 2
		fi
	done

	# If all retries failed, fall back to amd64
	echo "Warning: Could not determine platform support for ${version}-${postgis_version}, defaulting to amd64" >&2
	echo "linux/amd64"
	return 0
}

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}/..")")"
BASE_DIRECTORY="$(pwd)"

# Retrieve the PostgreSQL versions for TimescaleDB-PostGIS
cd ${BASE_DIRECTORY}/TimescaleDB-PostGIS
for version in */; do
	[[ $version == src/ ]] && continue
	postgis_versions+=("$version")
done
postgis_versions=("${postgis_versions[@]%/}")

# Sort the version numbers with highest first
mapfile -t postgis_versions < <(
	IFS=$'\n'
	sort -rV <<<"${postgis_versions[*]}"
)

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"
	shift
	local out
	printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

entries=()
for version in "${postgis_versions[@]}"; do

	# Read versions from the definition file
	versionFile="${version}/.versions.json"
	if [ ! -f "$versionFile" ]; then
		echo "Error: Version file not found: $versionFile" >&2
		continue
	fi

	postgisVersion=$(jq -r '.POSTGIS_IMAGE_VERSION | split("-") | .[1]' "${versionFile}" 2>/dev/null)
	if [ $? -ne 0 ] || [ -z "$postgisVersion" ]; then
		echo "Error: Could not read PostGIS version from $versionFile" >&2
		continue
	fi

	releaseVersion=$(jq -r '.IMAGE_RELEASE_VERSION' "${versionFile}" 2>/dev/null)
	if [ $? -ne 0 ] || [ -z "$releaseVersion" ]; then
		echo "Error: Could not read release version from $versionFile" >&2
		continue
	fi

	# Initial aliases are:
	# "major version" (of postgres)
	# "optional alias"
	# "major version - postgis version" ("postgis version": "$postgisMajorVersion.$postgisMinorVersion")
	# "major version - postgis version - release version"
	# i.e. "14", "latest", "14-3.2", "14-3.2-1"
	fullTag="${version}-${postgisVersion}-${releaseVersion}"
	versionAliases=(
		"${version}"
		${aliases[$version]:+"${aliases[$version]}"}
		"${version}-${postgisVersion}"
		"${fullTag}"
	)

	# Dynamically check platform support
	platforms=$(check_platform_support "$version" "$postgisVersion")

	# Build the json entry
	entries+=(
		"{\"name\": \"TimescaleDB-PostGIS ${version}-${postgisVersion}\", \"platforms\": \"$platforms\", \"dir\": \"TimescaleDB-PostGIS/$version\", \"file\": \"TimescaleDB-PostGIS/$version/Dockerfile\", \"version\": \"$version\", \"tags\": [\"$(join "\", \"" "${versionAliases[@]}")\"], \"fullTag\": \"${fullTag}\"}"
	)
done

# Build the strategy as a JSON object
strategy="{\"fail-fast\": false, \"matrix\": {\"include\": [$(join ', ' "${entries[@]}")]}}"
jq -C . <<<"$strategy" # sanity check / debugging aid

if [[ "$GITHUB_ACTIONS" == "true" ]]; then
	echo "strategy=$(jq -c . <<<"$strategy")" >>$GITHUB_OUTPUT
fi
