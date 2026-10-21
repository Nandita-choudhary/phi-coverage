"""
Render the report's PDF export into PNG images for the README.

    .venv/bin/python etl/render_report.py

Reads docs/more-members-less-cover.pdf (exported from Power BI Desktop on the Windows machine)
and writes docs/img/report-page-1.png, -2.png and -3.png at 1800 px wide, with the white margin
the PDF page adds around the report canvas trimmed off. Rendering from the PDF keeps the text
sharp; a screenshot of the remote desktop would not. Run it again whenever the PDF is
re-exported, so the images never lag the report.
"""

from __future__ import annotations

import sys
from pathlib import Path

import fitz  # pymupdf

ROOT = Path(__file__).resolve().parent.parent
PDF = ROOT / "docs" / "more-members-less-cover.pdf"
OUT = ROOT / "docs" / "img"
WIDTH_PX = 1800


def trim_white(pix: fitz.Pixmap, threshold: int = 245) -> fitz.Pixmap:
    """Cut the uniform white margin the PDF page adds around the report canvas."""
    w, h, n = pix.width, pix.height, pix.n
    data = pix.samples
    row_bytes = w * n

    def row_is_white(y: int) -> bool:
        return min(data[y * row_bytes:(y + 1) * row_bytes]) >= threshold

    def col_is_white(x: int) -> bool:
        return all(min(data[y * row_bytes + x * n:y * row_bytes + (x + 1) * n]) >= threshold for y in range(0, h, 4))

    top = next((y for y in range(h) if not row_is_white(y)), 0)
    bottom = next((y for y in range(h - 1, -1, -1) if not row_is_white(y)), h - 1)
    left = next((x for x in range(w) if not col_is_white(x)), 0)
    right = next((x for x in range(w - 1, -1, -1) if not col_is_white(x)), w - 1)
    clip = fitz.IRect(left, top, right + 1, bottom + 1)
    if clip.width < w * 0.5 or clip.height < h * 0.5:   # a blank page would trim to nothing
        return pix
    return fitz.Pixmap(pix, pix.width, pix.height, clip)


def main() -> None:
    if not PDF.exists():
        sys.exit(f"No PDF at {PDF.relative_to(ROOT)}: export it from Power BI Desktop first")
    OUT.mkdir(exist_ok=True)
    with fitz.open(PDF) as doc:
        for number, page in enumerate(doc, 1):
            zoom = WIDTH_PX / page.rect.width
            pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
            pix = trim_white(pix)
            target = OUT / f"report-page-{number}.png"
            pix.save(target)
            print(f"{target.relative_to(ROOT)}  {pix.width}x{pix.height}")
        print(f"{doc.page_count} page(s) rendered from {PDF.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
