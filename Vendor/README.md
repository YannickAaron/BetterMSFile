# Vendored dependencies

The Linux UI library and the packages it depends on, copied here so builds don't depend on Codeberg
(where upstream is hosted and which has had outages). All are MIT-licensed (see each `LICENSE.md`).

| Package | Upstream | Commit |
|---|---|---|
| adwaita-swift | https://git.aparoksha.dev/aparoksha/adwaita-swift | af5598fbd6f2425841f426ad388d7a7edd6c90e6 |
| meta | https://git.aparoksha.dev/aparoksha/meta | 4d274f3cd0 |
| meta-sqlite | https://git.aparoksha.dev/aparoksha/meta-sqlite | 1009b02b69 |
| levenshtein-transformations | https://git.aparoksha.dev/aparoksha/levenshtein-transformations | 06577a2c4c |

Local changes: only the `Package.swift` files, where references between these four packages point to `../<name>`
instead of their Codeberg URLs (marked `// vendored (BetterMSFile)`). The `Icons/` folder of adwaita-swift was left out.

To update: copy the new upstream sources over the folder (without `.git`), re-apply the `Package.swift` path changes,
update this table, and build on Linux.
