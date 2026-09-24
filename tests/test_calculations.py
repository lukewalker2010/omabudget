"""Tests for calculations module."""

import os
import sys
import tempfile
import shutil

_TMPDIR = tempfile.mkdtemp()

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lib.database as db

db.DB_PATH = os.path.join(_TMPDIR, "test.db")

import lib.calculations as calc


def setup_test_data():
    if os.path.exists(db.DB_PATH):
        os.remove(db.DB_PATH)
    db.init_db()
    db.add_account("checking1", "Main Checking", "checking", 10000.0, 0.0)
    db.add_account("savings1", "Savings", "savings", 50000.0, 0.02)
    db.add_account("cc1", "Credit Card", "credit_card", -2000.0, 0.18)
    db.update_profile("house_value", "350000")
    db.update_profile("income", "80000")
    db.add_transaction("tx_income_01", "income", "checking1", 5000.0,
                       "2025-06-01", "Salary", "income", "manual")
    db.add_transaction("tx_expense_01", "housing", "checking1", 1500.0,
                       "2025-06-15", "Rent", "expense", "manual")
    db.add_transaction("tx_expense_02", "food", "checking1", 400.0,
                       "2025-06-20", "Groceries", "expense", "manual")


def test_calculate_monthly_budget():
    setup_test_data()
    result = calc.calculate_monthly_budget(2025, 6)
    assert "total_budget" in result
    assert "total_spent" in result
    assert "remaining" in result
    assert "per_category" in result
    assert result["total_spent"] >= 1900.0
    assert result["year"] == 2025
    assert result["month"] == 6
    print("PASS: test_calculate_monthly_budget")


def test_calculate_net_worth():
    setup_test_data()
    result = calc.calculate_net_worth()
    assert "total_assets" in result
    assert "total_liabilities" in result
    assert "net_worth" in result
    assert result["total_assets"] >= 365000
    assert result["total_liabilities"] >= 2000
    assert result["net_worth"] > 0
    print("PASS: test_calculate_net_worth")


def test_calculate_monthly_cash_flow():
    setup_test_data()
    result = calc.calculate_monthly_cash_flow(2025, 6)
    assert "total_income" in result
    assert "total_expenses" in result
    assert "savings_rate" in result
    assert result["total_income"] == 5000.0
    assert result["total_expenses"] == 1900.0
    assert result["savings_rate"] > 0
    print("PASS: test_calculate_monthly_cash_flow")


def test_calculate_category_progress():
    setup_test_data()
    progress = calc.calculate_category_progress(2025, 6)
    assert isinstance(progress, list)
    housing = [p for p in progress if p["category"] == "Housing"]
    assert len(housing) == 1
    assert housing[0]["spent"] == 1500.0
    assert housing[0]["percent"] > 0
    print("PASS: test_calculate_category_progress")


if __name__ == "__main__":
    test_calculate_monthly_budget()
    test_calculate_net_worth()
    test_calculate_monthly_cash_flow()
    test_calculate_category_progress()
    shutil.rmtree(_TMPDIR)
    print("\nAll calculation tests passed!")
