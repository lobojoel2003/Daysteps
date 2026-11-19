# Bundled pictograms

`selection.json` is the curated list of symbols (set, source name/hexcode, id, label, category, keywords) plus the category and licence metadata.
`build_symbols.mjs` regenerates `assets/symbols/{mulberry,openmoji}/*.svg`, `assets/symbols/catalog.json` and `assets/symbols/ATTRIBUTION.md` from it:

    node tool/symbols/build_symbols.mjs            # from the repo root; Node 18+
    node tool/symbols/build_symbols.mjs --check    # also compile every SVG with Flutter's vector_graphics_compiler (needs `dart` on PATH)

It downloads Mulberry SVGs (pinned tag) from raw.githubusercontent.com and the OpenMoji npm tarball (integrity-checked), installs svgo into a cache dir outside the repo (`--cache=DIR` or `$SYMBOLS_CACHE`, default: OS temp dir), optimises the files, and fails if any SVG still contains `<style>`, `<text>`, `<image>`, filters or external references.
To add or change a symbol, edit `selection.json` and re-run the script; stale SVGs are removed. Behind an HTTPS proxy, run with `NODE_USE_ENV_PROXY=1` (recent Node 22/24).
