# AI data contract fixtures

These files are small, synthetic schema-contract fixtures. They are not operational AI data
and do not demonstrate 195k-segment performance or production category coverage.

Production-scale files must remain outside the application JAR and be selected through
`HALO_AI_DATA_SEGMENTS_PATH`, `HALO_AI_DATA_WSI_SCORES_PATH`, and
`HALO_AI_DATA_SAFEZONES_PATH`.

`data_vintage: "DUMMY"` and identifiers such as `REAL7KM` are fixture metadata and must not be
shown to users as a data date or place name.
