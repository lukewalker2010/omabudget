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
    for fmt in ("%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d", "%m-%d-%Y", "%d-%m-%Y",
                "%m/%d/%y", "%d/%m/%y", "%m-%d-%y", "%d-%m-%y"):
        try:
            return datetime.strptime(date_str, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return date_str


def _resolve_partial_date(date_str: str) -> str:
    """Resolve a month/day date (no year) to ISO, assuming the nearest past occurrence.

    Uses the current year; if that lands in the future, assumes the previous
    year (e.g. a January statement listing December activity).
    """
    iso = _parse_date(date_str)
    if iso != date_str.strip():
        return iso
    now = datetime.now()
    try:
        candidate = datetime.strptime(f"{date_str}/{now.year}", "%m/%d/%Y")
    except ValueError:
        return date_str
    if candidate.date() > now.date():
        candidate = candidate.replace(year=now.year - 1)
    return candidate.strftime("%Y-%m-%d")


def _parse_amount(amount_str: str) -> float:
    """Parse amount string to float, handling parentheses and trailing minus for negatives."""
    amount_str = amount_str.strip().replace(",", "").replace("$", "").replace(" ", "")
    if "(" in amount_str and ")" in amount_str:
        amount_str = amount_str.replace("(", "-").replace(")", "")
    if amount_str.endswith("-"):
        amount_str = "-" + amount_str[:-1]
    try:
        return float(amount_str)
    except ValueError:
        return 0.0


# Description keywords -> category id hints (validated against DB ids by the bridge).
_CATEGORY_HINTS = [
    ("grocery", "food"), ("safeway", "food"), ("kroger", "food"), ("trader joe", "food"),
    ("restaurant", "food"), ("cafe", "food"), ("coffee", "food"), ("doordash", "food"),
    ("uber eats", "food"), ("grubhub", "food"), ("pizza", "food"),
    ("electric", "utilities"), ("water bill", "utilities"), ("utility", "utilities"),
    ("internet", "utilities"), ("comcast", "utilities"), ("xfinity", "utilities"),
    ("verizon", "utilities"), ("t-mobile", "utilities"), ("at&t", "utilities"),
    ("rent", "housing"), ("mortgage", "housing"), ("hoa ", "housing"),
    ("gas station", "transport"), ("chevron", "transport"), ("shell oil", "transport"),
    ("uber", "transport"), ("lyft", "transport"), ("parking", "transport"),
    ("transit", "transport"), ("toll", "transport"),
    ("netflix", "subscriptions"), ("spotify", "subscriptions"), ("hulu", "subscriptions"),
    ("subscription", "subscriptions"), ("prime video", "subscriptions"),
    ("pharmacy", "healthcare"), ("cvs", "healthcare"), ("walgreens", "healthcare"),
    ("clinic", "healthcare"), ("dental", "healthcare"), ("hospital", "healthcare"),
    ("amazon", "shopping"), ("target", "shopping"), ("walmart", "shopping"),
    ("costco", "shopping"), ("ebay", "shopping"), ("etsy", "shopping"),
    ("steam", "entertainment"), ("cinema", "entertainment"), ("theater", "entertainment"),
    ("hulu live", "entertainment"), ("gamestop", "entertainment"),
    ("credit card pmt", "debt"), ("loan payment", "debt"), ("student loan", "debt"),
    ("atm withdrawal", "transport"),
]

_EXPENSE_KEYWORDS = ("withdrawal", "debit", "purchase", "payment", "check", "pos ", "bill pay")
_INCOME_KEYWORDS = ("income", "salary", "deposit", "refund", "payroll", "transfer in",
                    "interest earned", "dividend", "cashback")


def guess_category(description: str) -> str:
    """Best-effort category id from description keywords. Returns '' when unsure."""
    d = " " + description.lower() + " "
    for keyword, category_id in _CATEGORY_HINTS:
        if keyword in d:
            return category_id
    return ""


def normalize_amount(description: str, amount: float) -> float:
    """Force sign consistency: expenses negative, income positive."""
    tx_type = _infer_type(description, amount)
    if tx_type == "expense" and amount > 0:
        return -amount
    if tx_type == "income" and amount < 0:
        return -amount
    return amount


def _infer_type(description: str, amount: float) -> str:
    """Infer transaction type from description and amount."""
    desc_lower = " " + description.lower() + " "
    if any(kw in desc_lower for kw in _INCOME_KEYWORDS):
        return "income"
    if any(kw in desc_lower for kw in _EXPENSE_KEYWORDS):
        return "expense"
    if amount < 0:
        return "expense"
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


def _is_junk_line(line: str) -> bool:
    """Filter obvious non-transaction statement lines (headers, footers, totals)."""
    lowered = line.lower()
    junk_keywords = (
        "page ", "statement", "interest rate", "beginning balance",
        "ending balance", "previous balance", "available balance",
        "total ", "subtotal", "summary", "daily balance", "rate as of",
        "member ", "account number", "routing", "customer service",
        "www.", "phone:", "date range", "posting date",
    )
    return any(kw in lowered for kw in junk_keywords)


# Amount: optional sign/parens, optional $, digits with thousands separators, decimals.
_AMOUNT_RE = re.compile(
    r"[-(]?\s*\$?\s*-?\(?\d[\d,]*(?:\.\d+)?\s*\)?-?"
)
# Date formats: M/D/Y, M-D-Y, M/D (year optional), Y-M-D
_DATE_RE = re.compile(
    r"(?<!\d)(?:\d{4}[-/.]\d{1,2}[-/.]\d{1,2}|\d{1,2}[-/.]\d{1,2}(?:[-/.]\d{2,4})?)(?!\d)"
)


def parse_pdf(filepath: str) -> list[dict[str, Any]]:
    """Parse a PDF bank statement file using pypdf.

    Iterates every page and parses lines containing a date followed by a
    trailing amount. The amount is taken from the END of the line (standard
    statement layout) so the date is never mistaken for the amount.
    Returns list of transaction dicts with source field.
    """
    transactions = []
    reader = PdfReader(filepath)

    def _extract(page) -> str:
        try:
            text = page.extract_text(extraction_mode="layout")
            if text and _DATE_RE.search(text):
                return text
        except Exception:
            pass
        return page.extract_text() or ""

    for page in reader.pages:
        text = _extract(page)
        if not text:
            continue
        for line in text.split("\n"):
            line = line.strip()
            if not line or _is_junk_line(line):
                continue
            date_match = _DATE_RE.search(line)
            if not date_match:
                # Continuation of a wrapped description: fold into previous row.
                if transactions and len(line) > 2 and not line.startswith("("):
                    prev = transactions[-1]
                    if len(prev["description"]) < 80:
                        prev["description"] = (prev["description"] + " " + line).strip()
                continue
            rest = line[date_match.end():]
            amounts = _AMOUNT_RE.findall(rest)
            if not amounts:
                if transactions and len(line) > 2 and not line.startswith("("):
                    prev = transactions[-1]
                    if len(prev["description"]) < 80:
                        prev["description"] = (prev["description"] + " " + line).strip()
                continue
            amount = _parse_amount(amounts[-1])
            description = rest[:rest.rfind(amounts[-1])].strip(" -$|")
            if not description:
                continue
            date = _resolve_partial_date(date_match.group(0))
            amount = normalize_amount(description, amount)
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
            date = _parse_date(date_match.group(0))
            amount = _parse_amount(amount_match.group(0))
            description = line[:line.rfind(amount_match.group(0))].strip()
            amount = normalize_amount(description, amount)
            tx_type = _infer_type(description, amount)
            transactions.append({
                "date": date,
                "description": description,
                "amount": amount,
                "type": tx_type,
                "source": "image",
            })

    return transactions
