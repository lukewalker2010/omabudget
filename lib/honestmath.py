"""Rate-of-return model for financial projections."""

from typing import Any

ASSET_RATES = {
    "cash": (0.005, 0.01),
    "bonds": (0.035, 0.05),
    "stocks": (0.08, 0.15),
    "real_estate": (0.04, 0.08),
}

INFLATION = 0.03


def get_rate_of_return(account_type: str) -> tuple[float, float]:
    """Get expected return and volatility for an asset class.

    Returns (expected_return, volatility) tuple.
    """
    return ASSET_RATES.get(account_type, (0.0, 0.0))


def calculate_projection(profile: dict, portfolio: dict, years: int = 30) -> list[dict[str, Any]]:
    """Calculate projected portfolio value over time using deterministic returns.

    Args:
        profile: dict with age, retirement_age, income, house_value
        portfolio: dict with allocations like {'cash': 0.1, 'bonds': 0.2, 'stocks': 0.7}
        years: projection horizon

    Returns:
        list of dicts with year, age, projected_value, cumulative_contributions
    """
    age = profile["age"]
    retirement_age = profile["retirement_age"]
    income = profile.get("income", 75000)

    # Calculate blended return
    total_alloc = sum(portfolio.values())
    if total_alloc == 0:
        portfolio = {"stocks": 1.0}
        total_alloc = 1.0

    blended_return = sum(
        get_rate_of_return(k)[0] * (v / total_alloc) for k, v in portfolio.items()
    )

    projection = []
    value = 0.0
    cumulative = 0.0

    for yr in range(years):
        current_age = age + yr
        if current_age < retirement_age:
            annual_contribution = income
        else:
            annual_contribution = 0

        cumulative += annual_contribution
        value = value * (1 + blended_return) + annual_contribution

        projection.append({
            "year": yr + 1,
            "age": current_age,
            "projected_value": round(value, 2),
            "cumulative_contributions": round(cumulative, 2),
        })

    return projection
