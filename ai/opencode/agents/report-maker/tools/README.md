# Report-Maker local tools

Run from the report project directory:

```sh
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" --help
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" preflight
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" packages modern-g7-32 gost-table tituls
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" preflight Rep.typ
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" prepare assignment.pdf --assets assets --out .tmp/prep
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" assets assets --out .tmp/assets-contact.jpg
python3 "$HOME/.config/opencode/tools/report-maker/report_tools.py" check Rep.typ Rep.pdf
```

`preflight` checks the report toolchain, required guides, every `@local/name:version` imported by the optional Typst source, required package names passed with `--require`, and literal `image("...")` paths. `packages` lists local packages or validates named packages/imports. Both inspect each package's `typst.toml`, manifest name/version and entrypoint. Path checks follow symbolic links, report their resolved target, and flag broken links; a package is never considered absent based only on a search that ignores symlinks. Override package discovery with `--package-root` if Typst uses a non-default local package directory.

Use `preflight` once at the start of a report task (without a source, to validate the shared toolchain and guides), then again with the source after imports and image paths are known. Use `packages --source Rep.typ` to inspect its imports in isolation. These commands only inspect files; they do not install packages or change sources.

`prepare` records `pdfinfo`, tries layout-preserving text extraction, renders the PDF pages, and makes labeled contact sheets for pages and (optionally) the assets directory. A scanned PDF may have empty extracted text; the contact sheet still supports visual review. `assets` only makes a contact sheet. `check` compiles the Typst source, extracts PDF text, reports the page count, and verifies literal `image("...")` paths in the source. All output goes to the selected output path or the report's PDF path; intermediate files should remain in the project `.tmp/` directory.

Requirements: Python 3.11+ (for `tomllib`), Pillow, Typst, Poppler (`pdfinfo`, `pdftotext`, `pdftoppm`). The scripts do not install software, modify source images, OCR documents, or contact external services.
