"""Budget math and net worth calculations."""

from typing import Any
from lib.database import get_transactions, get_categories, get_accounts, get_profile


def calculate_monthly_budget(year: int, month: int) -> dict[str, Any]:
    """Calculate total budget, spent, remaining, and per-category breakdown."""
    categories = get_categories()
    budget_total = sum(c.get("budget_limit", 0) for c in categories if c.get("type") == "expense")

    per_category = []
    total_spent = 0.0
    for cat in categories:
        if cat.get("type") != "expense":
            continue
        spent = 0.0
        for tx in get_transactions({
            "type": "expense",
            "category_id": cat["id"],
            "start_date": f"{year}-{month:02d}-01",
            "end_date": f"{year}-{month:02d}-31"
        }):
            spent += tx["amount"]
        total_spent += spent
        per_category.append({
            "category_id": cat["id"],
            "category": cat["name"],
            "spent": round(spent, 2),
            "budget": cat.get("budget_limit", 0),
            "remaining": round(cat.get("budget_limit", 0) - spent, 2),
        })

    return {
        "total_budget": round(budget_total, 2),
        "total_spent": round(total_spent, 2),
        "remaining": round(budget_total - total_spent, 2),
        "per_category": per_category,
        "year": year,
        "month": month,
    }


def calculate_net_worth() -> dict[str, Any]:
    """Calculate total assets, liabilities, and net worth."""
    accounts = get_accounts()
    total_assets = sum(a.get("balance", 0) for a in accounts if a.get("type") in ("checking", "savings", "investment", "cash"))
    total_liabilities = sum(abs(a.get("balance", 0)) for a in accounts if a.get("type") == "credit_card")

    house_value_str = get_profile("house_value")
    house_value = float(house_value_str) if house_value_str else 0.0
    total_assets += house_value

    return {
        "total_assets": round(total_assets, 2),
        "total_liabilities": round(total_liabilities, 2),
        "net_worth": round(total_assets - total_liabilities, 2),
    }


def calculate_monthly_cash_flow(year: int, month: int) -> dict[str, Any]:
    """Calculate total income, expenses, and savings rate."""
    income = 0.0
    expenses = 0.0
    for tx in get_transactions({
        "type": "income",
        "start_date": f"{year}-{month:02d}-01",
        "end_date": f"{year}-{month:02d}-31"
    }):
        income += tx["amount"]
    for tx in get_transactions({
        "type": "expense",
        "start_date": f"{year}-{month:02d}-01",
        "end_date": f"{year}-{month:02d}-31"
    }):
        expenses += tx["amount"]

    savings_rate = (income - expenses) / income if income > 0 else 0.0
    return {
        "total_income": round(income, 2),
        "total_expenses": round(expenses, 2),
        "savings_rate": round(savings_rate, 4),
        "year": year,
        "month": month,
    }


def calculate_category_progress(year: int, month: int) -> list[dict[str, Any]]:
    """Get category spending progress as list of {category, spent, budget, percent}."""
    categories = get_categories()
    result = []
    for cat in categories:
        if cat.get("type") != "expense":
            continue
        budget = cat.get("budget_limit", 0)
        spent = sum(
            tx["amount"] for tx in get_transactions({
                "type": "expense",
                "category_id": cat["id"],
                "start_date": f"{year}-{month:02d}-01",
                "end_date": f"{year}-{month:02d}-31"
            })
        )
        percent = (spent / budget * 100) if budget > 0 else 0.0
        result.append({
            "category": cat["name"],
            "category_id": cat["id"],
            "spent": round(spent, 2),
            "budget": round(budget, 2),
            "percent": round(percent, 1),
        })
    return result
