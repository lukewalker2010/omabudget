"""Tests for the database layer."""

import os
import sys
import tempfile
import shutil

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lib.database as db

# Override DB path to temp directory
_TMPDIR = tempfile.mkdtemp()
db.DB_PATH = os.path.join(_TMPDIR, "test.db")


def test_init_db():
    db.init_db()
    conn = db._get_connection()
    tables = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    ).fetchall()
    table_names = [t["name"] for t in tables]
    assert "financial_profile" in table_names
    assert "categories" in table_names
    assert "accounts" in table_names
    assert "transactions" in table_names
    assert "budget_months" in table_names
    conn.close()

    cats = db.get_categories()
    assert len(cats) == 11
    assert any(c["name"] == "Housing" for c in cats)
    print("PASS: test_init_db")


def test_add_and_get_transactions():
    db.init_db()
    tx_id = "test_tx_001"
    db.add_transaction(
        tx_id, "housing", "checking", 1200.0,
        "2025-01-15", "Rent payment", "expense", "manual"
    )
    txs = db.get_transactions({"type": "expense"})
    assert any(t["id"] == tx_id for t in txs)
    matching = [t for t in txs if t["id"] == tx_id]
    assert len(matching) == 1
    assert matching[0]["amount"] == 1200.0
    assert matching[0]["category_id"] == "housing"
    print("PASS: test_add_and_get_transactions")


def test_get_category_breakdown():
    db.init_db()
    db.add_transaction("tx_002", "food", "checking", 50.0,
                       "2025-06-01", "Groceries", "expense", "manual")
    db.add_transaction("tx_003", "food", "checking", 30.0,
                       "2025-06-15", "Dining out", "expense", "manual")
    breakdown = db.get_category_breakdown(2025, 6)
    food = [b for b in breakdown if b["category_id"] == "food"]
    assert len(food) == 1
    assert food[0]["amount"] == 80.0
    print("PASS: test_get_category_breakdown")


def test_profile_crud():
    db.init_db()
    db.update_profile("age", "35")
    assert db.get_profile("age") == "35"
    db.update_profile("age", "36")
    assert db.get_profile("age") == "36"
    assert db.get_profile("nonexistent") is None
    print("PASS: test_profile_crud")


def test_categories():
    db.init_db()
    cats = db.get_categories()
    assert len(cats) == 11
    db.add_category("custom_cat", "Custom", "star", "expense", 100.0, "#FF0000", False)
    cats = db.get_categories()
    assert len(cats) == 12
    custom = [c for c in cats if c["id"] == "custom_cat"]
    assert len(custom) == 1
    print("PASS: test_categories")


def test_accounts():
    db.init_db()
    db.add_account("acc1", "Checking", "checking", 5000.0, 0.01)
    accs = db.get_accounts()
    assert len(accs) == 1
    assert accs[0]["balance"] == 5000.0
    print("PASS: test_accounts")


def test_set_budget_limit():
    db.init_db()
    db.set_budget_limit("housing", 2000.0)
    cats = db.get_categories()
    housing = [c for c in cats if c["id"] == "housing"][0]
    assert housing["budget_limit"] == 2000.0
    print("PASS: test_set_budget_limit")


if __name__ == "__main__":
    test_init_db()
    test_add_and_get_transactions()
    test_get_category_breakdown()
    test_profile_crud()
    test_categories()
    test_accounts()
    test_set_budget_limit()
    shutil.rmtree(_TMPDIR)
    print("\nAll database tests passed!")
