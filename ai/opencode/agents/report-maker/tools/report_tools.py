#!/usr/bin/env python3
"""Small local helpers for preparing and validating Typst reports.

Examples:
  python3 report_tools.py preflight
  python3 report_tools.py packages modern-g7-32 gost-table tituls
  python3 report_tools.py preflight Rep1.typ
  python3 report_tools.py prepare assignment.pdf --assets assets --out .tmp/prep
  python3 report_tools.py assets assets --out .tmp/assets.jpg
  python3 report_tools.py check report.typ [report.pdf]
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


def default_package_root() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return data_home / "typst/packages/local"


def imports_from(source: Path | None) -> list[tuple[str, str]]:
    if source is None:
        return []
    text = source.read_text(encoding="utf-8")
    return sorted(set(re.findall(r"@local/([A-Za-z0-9_-]+):([A-Za-z0-9.+_-]+)", text)))


def package_info(root: Path, name: str, version: str | None = None) -> tuple[bool, str]:
    """Validate a Typst local package. Path checks intentionally follow symlinks."""
    package_dir = root / name
    if package_dir.is_symlink() and not package_dir.exists():
        try:
            package_dir.resolve(strict=True)
        except (OSError, RuntimeError) as exc:
            return False, f"BROKEN SYMLINK: {package_dir} ({exc})"
    if not package_dir.exists():
        return False, f"MISSING: {name}: no directory at {package_dir}"
    if not package_dir.is_dir():
        return False, f"INVALID: package path is not a directory: {package_dir}"

    try:
        versions = [package_dir / version] if version else sorted(
            (p for p in package_dir.iterdir() if p.is_dir() or p.is_symlink()),
            key=lambda p: p.name,
        )
    except OSError as exc:
        return False, f"INVALID: cannot inspect package directory {package_dir} ({exc})"
    if not versions:
        return False, f"MISSING: {name}: no version directories at {package_dir}"

    errors: list[str] = []
    found: list[str] = []
    for version_dir in versions:
        manifest = version_dir / "typst.toml"
        # is_file() follows symlinks. resolve(strict=True) also exposes broken links.
        try:
            resolved = version_dir.resolve(strict=True)
        except (OSError, RuntimeError) as exc:
            errors.append(f"{version_dir.name}: broken/unresolvable path ({exc})")
            continue
        if not manifest.is_file():
            errors.append(f"{version_dir.name}: missing typst.toml at {manifest}")
            continue
        try:
            metadata = tomllib.loads(manifest.read_text(encoding="utf-8"))
            package = metadata["package"]
            actual_name = str(package["name"])
            actual_version = str(package["version"])
            entrypoint = str(package["entrypoint"])
        except (OSError, KeyError, TypeError, tomllib.TOMLDecodeError) as exc:
            errors.append(f"{version_dir.name}: invalid package manifest ({exc})")
            continue

        if actual_name != name:
            errors.append(f"{version_dir.name}: manifest name is {actual_name!r}, expected {name!r}")
            continue
        if actual_version != version_dir.name:
            errors.append(f"{version_dir.name}: manifest version is {actual_version!r}, folder name differs")
            continue
        if version and actual_version != version:
            errors.append(f"{version_dir.name}: import requests {version}, manifest says {actual_version}")
            continue
        if not (version_dir / entrypoint).is_file():
            errors.append(f"{version_dir.name}: entrypoint does not exist: {entrypoint}")
            continue
        link_note = f" (symlink -> {resolved})" if version_dir.is_symlink() else ""
        found.append(f"OK: {name}:{actual_version} — {version_dir}{link_note}; entrypoint {entrypoint}")

    if found:
        return True, "\n".join(found)
    return False, "\n".join(errors) if errors else f"MISSING: {name}"


def packages(args: argparse.Namespace) -> None:
    root = args.package_root.expanduser()
    if not root.is_dir():
        raise RuntimeError(f"Typst local package root not found: {root}")

    requested = set(args.name or [])
    imported = imports_from(args.source)
    requested.update(name for name, _ in imported)
    if not requested:
        requested.update(p.name for p in root.iterdir() if p.is_dir() or p.is_symlink())

    requested_versions: dict[str, set[str]] = {}
    for name, version in imported:
        requested_versions.setdefault(name, set()).add(version)

    failures = 0
    print(f"Typst local package root: {root} (resolved: {root.resolve()})")
    for name in sorted(requested):
        versions = requested_versions.get(name)
        if versions:
            for version in sorted(versions):
                ok, message = package_info(root, name, version)
                print(message)
                failures += not ok
        else:
            ok, message = package_info(root, name)
            print(message)
            failures += not ok
    if failures:
        raise RuntimeError(f"{failures} package check(s) failed")


def preflight(args: argparse.Namespace) -> None:
    failures: list[str] = []
    root = args.package_root.expanduser()
    doc_root = args.doc_root.expanduser()

    print("== Report-Maker preflight ==")
    print(f"Package root: {root}")
    print(f"Package root resolved: {root.resolve() if root.exists() else '(missing)'}")
    if args.source:
        source = args.source.resolve()
        if not source.is_file():
            failures.append(f"Source file not found: {source}")
            imports: list[tuple[str, str]] = []
        else:
            imports = imports_from(source)
            print(f"Source: {source}")
        for name, version in imports:
            ok, message = package_info(root, name, version)
            print(message)
            if not ok:
                failures.append(f"Imported package not available: {name}:{version}")
        for name in args.require or []:
            if any(imported == name for imported, _ in imports):
                continue
            ok, message = package_info(root, name)
            print(message)
            if not ok:
                failures.append(f"Required package not available: {name}")

        text = source.read_text(encoding="utf-8") if source.is_file() else ""
        missing_images = [
            raw for raw in re.findall(r'image\(\s*["\']([^"\']+)["\']', text)
            if not (source.parent / raw).resolve().is_file()
        ]
        print(f"Referenced images: {'OK' if not missing_images else 'MISSING: ' + ', '.join(missing_images)}")
        if missing_images:
            failures.append("One or more referenced images are missing")
    elif args.require:
        for name in args.require:
            ok, message = package_info(root, name)
            print(message)
            if not ok:
                failures.append(f"Required package not available: {name}")
    else:
        print("No Typst source or required package names supplied; package imports were not checked.")

    required_docs = ("typst-gost-guide.md", "tituls.md")
    for filename in required_docs:
        path = doc_root / filename
        state = "OK" if path.is_file() else "MISSING"
        print(f"Guide {filename}: {state} ({path})")
        if not path.is_file():
            failures.append(f"Required guide not found: {path}")

    for command in ("typst", "pdfinfo", "pdftotext", "pdftoppm"):
        found = shutil.which(command)
        print(f"Command {command}: {found or 'MISSING'}")
        if not found:
            failures.append(f"Required command not found: {command}")

    try:
        import PIL  # noqa: F401
        print("Python Pillow: OK")
    except ImportError:
        print("Python Pillow: MISSING")
        failures.append("Python Pillow is not installed")

    if failures:
        raise RuntimeError("Preflight failed:\n- " + "\n- ".join(failures))
    print("Preflight: OK")


def require_tool(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"Required command not found: {name}")
    return path


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/dejavu/DejaVuSans.ttf",
    ):
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def contact_sheet(paths: list[Path], output: Path, columns: int, width: int, title: str) -> None:
    if not paths:
        raise RuntimeError("No images found to place in contact sheet")
    label_font = font(15)
    margin, gap, label_h = 14, 12, 34
    thumb_h = round(width * 0.63)
    cell_w, cell_h = width + gap, thumb_h + label_h + gap
    rows = (len(paths) + columns - 1) // columns
    canvas = Image.new("RGB", (margin * 2 + columns * cell_w, 64 + rows * cell_h), "#eeeeee")
    draw = ImageDraw.Draw(canvas)
    draw.text((margin, 14), title, fill="#111111", font=font(22))
    for index, path in enumerate(paths):
        with Image.open(path) as original:
            im = ImageOps.contain(original.convert("RGB"), (width, thumb_h))
        x = margin + (index % columns) * cell_w
        y = 54 + (index // columns) * cell_h
        canvas.paste(im, (x + (width - im.width) // 2, y + (thumb_h - im.height) // 2))
        draw.rectangle((x, y, x + width, y + thumb_h), outline="#999999")
        label = path.name
        while draw.textbbox((0, 0), label, font=label_font)[2] > width and len(label) > 12:
            label = label[:-4] + "…" + path.suffix
        draw.text((x, y + thumb_h + 5), label, fill="#111111", font=label_font)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, quality=88)
    print(f"Contact sheet: {output} ({len(paths)} images)")


def prepare(args: argparse.Namespace) -> None:
    pdf = args.pdf.resolve()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    require_tool("pdfinfo")
    info = subprocess.run(["pdfinfo", str(pdf)], check=True, text=True, capture_output=True).stdout
    pages_match = re.search(r"^Pages:\s+(\d+)\s*$", info, re.MULTILINE)
    if not pages_match:
        raise RuntimeError("Could not determine PDF page count")
    page_count = int(pages_match.group(1))
    (out / "pdfinfo.txt").write_text(info, encoding="utf-8")

    require_tool("pdftotext")
    text = subprocess.run(
        ["pdftotext", "-layout", str(pdf), str(out / "extracted.txt")],
        text=True,
        capture_output=True,
    )
    extracted_text = (out / "extracted.txt").read_text(encoding="utf-8", errors="replace")
    text_available = text.returncode == 0 and bool(extracted_text.strip())

    require_tool("pdftoppm")
    prefix = out / "page"
    subprocess.run(
        ["pdftoppm", "-png", "-scale-to", str(args.page_width), str(pdf), str(prefix)],
        check=True,
        capture_output=True,
    )
    pages = sorted(out.glob("page-*.png"), key=lambda p: int(re.search(r"-(\d+)\.png$", p.name).group(1)))
    if pages:
        contact_sheet(pages, out / "pdf-contact.jpg", args.columns, args.page_width, f"{pdf.name} — {page_count} pages")

    assets_dir = args.assets.resolve() if args.assets else None
    if assets_dir and assets_dir.is_dir():
        images = sorted(p for p in assets_dir.iterdir() if p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"})
        if images:
            contact_sheet(images, out / "assets-contact.jpg", args.columns, args.asset_width, f"Assets — {len(images)} images")
    print(f"Text extraction: {'available' if text_available else 'empty/unavailable (scanned or protected PDF)'}")
    print(f"Rendered {len(pages)} of {page_count} PDF pages into {out}")


def assets(args: argparse.Namespace) -> None:
    directory = args.directory.resolve()
    if not directory.is_dir():
        raise RuntimeError(f"Not a directory: {directory}")
    paths = sorted(p for p in directory.iterdir() if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"})
    contact_sheet(paths, args.out.resolve(), args.columns, args.width, f"{directory.name} — {len(paths)} images")


def check(args: argparse.Namespace) -> None:
    source = args.source.resolve()
    output = args.pdf.resolve() if args.pdf else source.with_suffix(".pdf")
    output.parent.mkdir(parents=True, exist_ok=True)
    require_tool("typst")
    subprocess.run(["typst", "compile", str(source), str(output)], check=True)
    require_tool("pdfinfo")
    info = subprocess.run(["pdfinfo", str(output)], check=True, text=True, capture_output=True).stdout
    require_tool("pdftotext")
    extracted = subprocess.run(["pdftotext", "-layout", str(output), "-"], check=True, text=True, capture_output=True).stdout

    # Typst image() paths are resolved relative to the source file.
    missing = []
    for raw in re.findall(r'image\(\s*["\']([^"\']+)["\']', source.read_text(encoding="utf-8")):
        asset = (source.parent / raw).resolve()
        if not asset.is_file():
            missing.append(raw)
    page_match = re.search(r"^Pages:\s+(\d+)\s*$", info, re.MULTILINE)
    print(f"PDF: {output}")
    print(f"Pages: {page_match.group(1) if page_match else 'unknown'}")
    print(f"Extracted text: {len(extracted)} characters")
    print(f"Referenced images: {'OK' if not missing else 'MISSING: ' + ', '.join(missing)}")
    if missing:
        raise RuntimeError("One or more referenced image files are missing")
    if not extracted.strip():
        raise RuntimeError("PDF text extraction returned no text")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    prep = commands.add_parser("prepare", help="Extract PDF metadata/text and create page/assets contact sheets")
    prep.add_argument("pdf", type=Path)
    prep.add_argument("--assets", type=Path)
    prep.add_argument("--out", type=Path, default=Path(".tmp/report-prep"))
    prep.add_argument("--columns", type=int, default=3)
    prep.add_argument("--page-width", type=int, default=440)
    prep.add_argument("--asset-width", type=int, default=360)
    prep.set_defaults(func=prepare)

    sheet = commands.add_parser("assets", help="Create a labeled contact sheet for image assets")
    sheet.add_argument("directory", type=Path)
    sheet.add_argument("--out", type=Path, default=Path(".tmp/assets-contact.jpg"))
    sheet.add_argument("--columns", type=int, default=4)
    sheet.add_argument("--width", type=int, default=360)
    sheet.set_defaults(func=assets)

    build = commands.add_parser("check", help="Compile Typst and check PDF text and referenced images")
    build.add_argument("source", type=Path)
    build.add_argument("pdf", nargs="?", type=Path)
    build.set_defaults(func=check)

    package_check = commands.add_parser(
        "packages",
        help="List or validate local Typst packages, following symlinks",
    )
    package_check.add_argument("name", nargs="*", help="Package names to inspect (default: all found)")
    package_check.add_argument("--source", type=Path, help="Also validate @local imports in a Typst source")
    package_check.add_argument("--package-root", type=Path, default=default_package_root())
    package_check.set_defaults(func=packages)

    verify = commands.add_parser(
        "preflight",
        help="Check report toolchain, required guides, package imports, and image paths",
    )
    verify.add_argument("source", nargs="?", type=Path, help="Typst source to inspect")
    verify.add_argument("--require", nargs="+", help="Additional required package names")
    verify.add_argument("--package-root", type=Path, default=default_package_root())
    verify.add_argument(
        "--doc-root",
        type=Path,
        default=Path.home() / ".config/opencode/docs/report-maker",
    )
    verify.set_defaults(func=preflight)

    args = parser.parse_args()
    try:
        args.func(args)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"report-tools: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
