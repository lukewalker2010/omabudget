"""Statement parsing for CSV, PDF, and image files."""

import csv
import io
import re
from typing import Any
from datetime import datetime

from pypdf import PdfReader
from PIL import Image
import pytesseract


def _parse_date(date_str: str) -> str:
    """Parse various date formats into ISO format YYYY-MM-DD."""
    date_str = date_str.strip()
    for fmt in ("%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d", "%m-%d-%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(date_str, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return date_str


def _parse_amount(amount_str: str) -> float:
    """Parse amount string to float, handling parentheses for negatives."""
    amount_str = amount_str.strip().replace(",", "").replace("$", "")
    if "(" in amount_str and ")" in amount_str:
        amount_str = amount_str.replace("(", "-").replace(")", "")
    try:
        return float(amount_str)
    except ValueError:
        return 0.0


def _infer_type(description: str, amount: float) -> str:
    """Infer transaction type from description and amount."""
    desc_lower = description.lower()
    if amount < 0:
        return "expense"
    if any(kw in desc_lower for kw in ("income", "salary", "deposit", "refund", "payroll", "transfer in")):
        return "income"
    return "expense"


def parse_csv(filepath: str) -> list[dict[str, Any]]:
    """Parse a CSV bank statement file.

    Expected columns: Date, Description, Amount, Balance (or similar).
    Returns list of transaction dicts with source field.
    """
    transactions = []
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        reader = csv.DictReader(f)
        for row in reader:
            date_val = row.get("Date", row.get("date", ""))
            desc_val = row.get("Description", row.get("description", row.get("Memo", "")))
            amount_val = row.get("Amount", row.get("amount", row.get("Value", "")))

            date = _parse_date(date_val)
            amount = _parse_amount(str(amount_val))
            description = str(desc_val).strip()
            tx_type = _infer_type(description, amount)

            transactions.append({
                "date": date,
                "description": description,
                "amount": amount,
                "type": tx_type,
                "source": "csv",
            })
    return transactions


def parse_pdf(filepath: str) -> list[dict[str, Any]]:
    """Parse a PDF bank statement file using pypdf.

    Extracts text and parses tabular data.
    Returns list of transaction dicts with source field.
    """
    transactions = []
    reader = PdfReader(filepath)
    full_text = ""
    for page in reader.pages:
        text = page.extract_text()
        if text:
            full_text += text + "\n"

    # Parse lines that look like transactions
    # Common patterns: date | description | amount
    lines = full_text.split("\n")
    for line in lines:
        line = line.strip()
        if not line:
            continue
        # Try to match date and amount patterns
        date_match = re.search(r"(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4})", line)
        amount_match = re.search(r"(?<![\d.])\d{1,3}(?:,\d{3})*(?:\.\d+)?", line)
        if date_match and amount_match:
            date = _parse_date(date_match.group(1))
            amount = _parse_amount(amount_match.group(0))
            description = line[:line.rfind(amount_match.group(0))].strip()
            tx_type = _infer_type(description, amount)
            transactions.append({
                "date": date,
                "description": description,
                "amount": amount,
                "type": tx_type,
                "source": "pdf",
            })

    return transactions


def parse_image(filepath: str) -> list[dict[str, Any]]:
    """Parse a bank statement image using pytesseract OCR.

    Returns list of transaction dicts with source field.
    """
    img = Image.open(filepath)
    text = pytesseract.image_to_string(img)

    transactions = []
    lines = text.split("\n")
    for line in lines:
        line = line.strip()
        if not line:
            continue
        date_match = re.search(r"(\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4})", line)
        amount_match = re.search(r"(?<![\d.])\d{1,3}(?:,\d{3})*(?:\.\d+)?", line)
        if date_match and amount_match:
            date = _parse_date(date_match.group(1))
            amount = _parse_amount(amount_match.group(0))
            description = line[:line.rfind(amount_match.group(0))].strip()
            tx_type = _infer_type(description, amount)
            transactions.append({
                "date": date,
                "description": description,
                "amount": amount,
                "type": tx_type,
                "source": "image",
            })

    return transactions
