# Image catalogs

`ClusterImageCatalog` resources for the `timescaledb-postgis` images, one per
`<imageType>-<distro>` combination:

- `timescaledb-postgis-standard-bookworm.yaml`
- `timescaledb-postgis-standard-trixie.yaml`
- `timescaledb-postgis-system-bookworm.yaml`
- `timescaledb-postgis-system-trixie.yaml`

These files are generated, not hand-edited. The `Update Catalogs` workflow
(`.github/workflows/catalogs.yml`) regenerates them from the digests published to
`ghcr.io/imusmanmalik/timescaledb-postgis` after each scheduled/production bake, then
commits the result. They will appear here after the first such run.

Apply a catalog with:

```bash
kubectl apply -f https://raw.githubusercontent.com/imusmanmalik/cloudnative-pg-timescaledb-postgis-containers/main/image-catalogs/timescaledb-postgis-standard-trixie.yaml
```

then reference it from a `Cluster`:

```yaml
spec:
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: timescaledb-postgis-standard-trixie
    major: 17
```
