# Curated Taxonomy

`api/config/curated_taxonomy.json` is the canonical source of truth for the built-in Aliolo taxonomy.

It defines:
- pillar order, names, and descriptions
- curated folder names
- curated subject placement
- curated subject display names and descriptions

Implementation notes:
- subject IDs must remain stable
- user-created folders and subjects may exist under any pillar
- the curated catalog should avoid `Other` unless a subject genuinely does not fit a stronger pillar

Use `scripts/python/generate_taxonomy_sql.py` to generate SQL updates from this manifest.
