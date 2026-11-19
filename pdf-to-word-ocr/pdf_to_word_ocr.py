"""
PDF to Word converter with OCR support.

- Text-based PDFs  -> converted with pdf2docx (keeps layout, tables, images)
- Scanned PDFs     -> each page rendered as an image, read with Tesseract OCR,
                      text written into a .docx

Install:
    pip install pymupdf pdf2docx pytesseract python-docx pillow
    + Tesseract OCR engine:
        Windows: https://github.com/UB-Mannheim/tesseract/wiki  (tick "Malay" in languages)
        macOS:   brew install tesseract tesseract-lang
        Linux:   sudo apt install tesseract-ocr tesseract-ocr-msa

Usage:
    python pdf_to_word_ocr.py input.pdf                  # auto-detect
    python pdf_to_word_ocr.py input.pdf -o output.docx
    python pdf_to_word_ocr.py input.pdf --ocr            # force OCR
    python pdf_to_word_ocr.py input.pdf --lang eng+msa   # English + Malay
"""

import argparse
import io
import sys
from pathlib import Path

import fitz  # PyMuPDF
import pytesseract
from docx import Document
from docx.shared import Pt
from PIL import Image

# Windows users: uncomment and set the path if Tesseract isn't on PATH
# pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


def is_scanned(pdf_path: Path, min_chars: int = 50) -> bool:
    """Return True if the PDF has little or no selectable text."""
    with fitz.open(pdf_path) as doc:
        text_chars = sum(len(page.get_text().strip()) for page in doc)
        return text_chars < min_chars * len(doc)


def convert_text_pdf(pdf_path: Path, out_path: Path) -> None:
    from pdf2docx import Converter

    cv = Converter(str(pdf_path))
    try:
        cv.convert(str(out_path))
    finally:
        cv.close()


def convert_with_ocr(pdf_path: Path, out_path: Path, lang: str, dpi: int) -> None:
    document = Document()
    style = document.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    with fitz.open(pdf_path) as pdf:
        total = len(pdf)
        for i, page in enumerate(pdf, start=1):
            print(f"OCR page {i}/{total}...", flush=True)
            pix = page.get_pixmap(dpi=dpi)
            img = Image.open(io.BytesIO(pix.tobytes("png")))

            text = pytesseract.image_to_string(img, lang=lang)

            # Keep paragraph breaks (blank lines), join wrapped lines
            for block in text.split("\n\n"):
                para = " ".join(line.strip() for line in block.splitlines() if line.strip())
                if para:
                    document.add_paragraph(para)

            if i < total:
                document.add_page_break()

    document.save(out_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert PDF to Word (with OCR).")
    parser.add_argument("pdf", help="Input PDF file")
    parser.add_argument("-o", "--output", help="Output .docx (default: same name)")
    parser.add_argument("--ocr", action="store_true", help="Force OCR mode")
    parser.add_argument("--lang", default="eng", help="Tesseract language(s), e.g. eng+msa")
    parser.add_argument("--dpi", type=int, default=300, help="Render DPI for OCR (default 300)")
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    if not pdf_path.exists():
        sys.exit(f"File not found: {pdf_path}")
    out_path = Path(args.output) if args.output else pdf_path.with_suffix(".docx")

    if args.ocr or is_scanned(pdf_path):
        print("Scanned PDF detected -> using OCR")
        convert_with_ocr(pdf_path, out_path, args.lang, args.dpi)
    else:
        print("Text PDF detected -> converting with layout")
        convert_text_pdf(pdf_path, out_path)

    print(f"Done: {out_path}")


if __name__ == "__main__":
    main()
