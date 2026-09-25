"""SQLite3 database layer for omabudget."""

import os
import sqlite3
from datetime import datetime
from typing import Any, Optional

DB_PATH = os.path.expanduser("~/.local/state/omabudget/omabudget.db")


def _get_connection() -> sqlite3.Connection:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """Initialize the database schema and seed predefined categories."""
    conn = _get_connection()
    if os.path.exists(DB_PATH):
        os.chmod(DB_PATH, 0o600)
    try:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS financial_profile (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY,
                name TEXT,
                icon TEXT,
                type TEXT CHECK(type IN ('expense','income','savings')),
                budget_limit REAL DEFAULT 0,
                is_predefined BOOLEAN DEFAULT 0,
                color TEXT DEFAULT '#888888'
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                name TEXT,
                type TEXT CHECK(type IN ('checking','savings','investment','credit_card','cash')),
                balance REAL DEFAULT 0,
                interest_rate REAL DEFAULT 0
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                category_id TEXT,
                account_id TEXT,
                amount REAL,
                date TEXT,
                description TEXT,
                type TEXT CHECK(type IN ('income','expense','transfer')),
                source TEXT DEFAULT 'manual',
                raw_data TEXT,
                created_at TEXT
            )
        """)
        conn.execute("""
            CREATE TABLE IF NOT EXISTS budget_months (
                id TEXT PRIMARY KEY,
                year INTEGER,
                month INTEGER,
                category_id TEXT,
                spent REAL DEFAULT 0
            )
        """)

        count = conn.execute("SELECT COUNT(*) FROM categories").fetchone()[0]
        if count == 0:
            predefined = [
                ("housing", "Housing", "home", "expense", 1500.0, 1, "#E8632A"),
                ("food", "Food", "fork-knife", "expense", 600.0, 1, "#F5A623"),
                ("transport", "Transport", "car", "expense", 300.0, 1, "#3B82F6"),
                ("utilities", "Utilities", "bolt", "expense", 200.0, 1, "#8B5CF6"),
                ("healthcare", "Healthcare", "heart-pulse", "expense", 150.0, 1, "#EF4444"),
                ("shopping", "Shopping", "bag-shopping", "expense", 250.0, 1, "#EC4899"),
                ("entertainment", "Entertainment", "gamepad", "expense", 200.0, 1, "#10B981"),
                ("income", "Income", "arrow-down", "income", 0.0, 1, "#10B981"),
                ("savings", "Savings", "piggy-bank", "savings", 0.0, 1, "#F59E0B"),
                ("debt", "Debt", "credit-card", "expense", 0.0, 1, "#6B7280"),
                ("subscriptions", "Subscriptions", "playlist", "expense", 100.0, 1, "#06B6D4"),
            ]
            for cat in predefined:
                conn.execute(
                    "INSERT INTO categories (id, name, icon, type, budget_limit, is_predefined, color) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    cat
                )
        conn.commit()
    finally:
        conn.close()


def add_transaction(
    tx_id: str, category_id: str, account_id: str, amount: float,
    date: str, description: str, type: str = "expense",
    source: str = "manual", raw_data: str = "", created_at: Optional[str] = None
) -> None:
    """Add a transaction to the database."""
    if created_at is None:
        created_at = datetime.now().isoformat()
    conn = _get_connection()
    try:
        conn.execute(
            "INSERT INTO transactions (id, category_id, account_id, amount, date, description, type, source, raw_data, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (tx_id, category_id, account_id, amount, date, description, type, source, raw_data, created_at)
        )
        conn.commit()
    finally:
        conn.close()


def get_transactions(filters: Optional[dict] = None) -> list[dict[str, Any]]:
    """Query transactions with optional filters."""
    conn = _get_connection()
    try:
        query = "SELECT * FROM transactions WHERE 1=1"
        params = []
        if filters:
            if "type" in filters:
                query += " AND type = ?"
                params.append(filters["type"])
            if "category_id" in filters:
                query += " AND category_id = ?"
                params.append(filters["category_id"])
            if "account_id" in filters:
                query += " AND account_id = ?"
                params.append(filters["account_id"])
            if "start_date" in filters:
                query += " AND date >= ?"
                params.append(filters["start_date"])
            if "end_date" in filters:
                query += " AND date <= ?"
                params.append(filters["end_date"])
        query += " ORDER BY date DESC"
        rows = conn.execute(query, params).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def get_monthly_spending(year: int, month: int) -> dict[str, Any]:
    """Get total spending for a given month."""
    conn = _get_connection()
    try:
        row = conn.execute(
            "SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = 'expense' AND strftime('%Y', date) = ? AND strftime('%m', date) = ?",
            (str(year), f"{month:02d}")
        ).fetchone()
        return {"total_spent": row["total"] if row else 0.0, "year": year, "month": month}
    finally:
        conn.close()


def get_category_breakdown(year: int, month: int) -> list[dict[str, Any]]:
    """Get spending by category for a given month."""
    conn = _get_connection()
    try:
        rows = conn.execute(
            """SELECT c.name, c.id, c.color, COALESCE(SUM(t.amount), 0) as total
               FROM categories c LEFT JOIN transactions t ON c.id = t.category_id
               WHERE t.type = 'expense' AND strftime('%Y', t.date) = ? AND strftime('%m', t.date) = ?
               GROUP BY c.id, c.name, c.color
               ORDER BY total DESC""",
            (str(year), f"{month:02d}")
        ).fetchall()
        return [{"category": r["name"], "category_id": r["id"], "color": r["color"], "amount": r["total"]} for r in rows]
    finally:
        conn.close()


def add_category(category_id: str, name: str, icon: str, type: str,
                 budget_limit: float = 0, color: str = "#888888",
                 is_predefined: bool = False) -> None:
    """Add a new category."""
    conn = _get_connection()
    try:
        conn.execute(
            "INSERT OR REPLACE INTO categories (id, name, icon, type, budget_limit, is_predefined, color) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (category_id, name, icon, type, budget_limit, is_predefined, color)
        )
        conn.commit()
    finally:
        conn.close()


def get_categories() -> list[dict[str, Any]]:
    """Get all categories."""
    conn = _get_connection()
    try:
        rows = conn.execute("SELECT * FROM categories ORDER BY name").fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def add_account(account_id: str, name: str, type: str, balance: float = 0,
                interest_rate: float = 0) -> None:
    """Add a new account."""
    conn = _get_connection()
    try:
        conn.execute(
            "INSERT OR REPLACE INTO accounts (id, name, type, balance, interest_rate) VALUES (?, ?, ?, ?, ?)",
            (account_id, name, type, balance, interest_rate)
        )
        conn.commit()
    finally:
        conn.close()


def get_accounts() -> list[dict[str, Any]]:
    """Get all accounts."""
    conn = _get_connection()
    try:
        rows = conn.execute("SELECT * FROM accounts ORDER BY name").fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


def update_profile(key: str, value: str) -> None:
    """Update or insert a financial profile key-value pair."""
    conn = _get_connection()
    try:
        conn.execute(
            "INSERT INTO financial_profile (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = ?",
            (key, value, value)
        )
        conn.commit()
    finally:
        conn.close()


def get_profile(key: str) -> Optional[str]:
    """Get a financial profile value by key."""
    conn = _get_connection()
    try:
        row = conn.execute("SELECT value FROM financial_profile WHERE key = ?", (key,)).fetchone()
        return row["value"] if row else None
    finally:
        conn.close()


def set_budget_limit(category_id: str, limit: float) -> None:
    """Set the budget limit for a category."""
    conn = _get_connection()
    try:
        conn.execute(
            "UPDATE categories SET budget_limit = ? WHERE id = ?",
            (limit, category_id)
        )
        conn.commit()
    finally:
        conn.close()
