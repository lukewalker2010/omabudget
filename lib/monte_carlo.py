"""Monte Carlo retirement simulation."""

import numpy as np
from typing import Any

RATES = {"cash": 0.005, "bonds": 0.035, "stocks": 0.08, "real_estate": 0.04}
VOLATILITIES = {"cash": 0.01, "bonds": 0.05, "stocks": 0.15, "real_estate": 0.08}
INFLATION = 0.03
HORIZON = 30


def run_simulation(profile: dict, portfolio: dict, num_simulations: int = 10000) -> dict[str, Any]:
    """Run a Monte Carlo retirement simulation.

    Args:
        profile: dict with age, retirement_age, income, house_value
        portfolio: dict with allocations like {'cash': 0.1, 'bonds': 0.2, 'stocks': 0.7}
        num_simulations: number of simulation runs

    Returns:
        dict with probability_of_success, median_portfolio_at_retirement,
        worst_case, best_case, success_by_age
    """
    age = profile["age"]
    retirement_age = profile["retirement_age"]
    years_to_retirement = max(retirement_age - age, 1)

    # Build portfolio expected return and volatility
    portfolio = {k: v for k, v in portfolio.items() if k in RATES}
    total_alloc = sum(portfolio.values())
    if total_alloc == 0:
        portfolio = {"stocks": 1.0}
        total_alloc = 1.0

    expected_return = sum(RATES[k] * (portfolio[k] / total_alloc) for k in portfolio)
    volatility = sum(VOLATILITIES[k] * (portfolio[k] / total_alloc) for k in portfolio)

    rng = np.random.default_rng()

    # Vectorized simulation: (num_simulations, HORIZON)
    annual_returns = rng.normal(
        expected_return, volatility, size=(num_simulations, HORIZON)
    )

    # Generate contributions until retirement
    contributions = np.zeros((num_simulations, HORIZON))
    for yr in range(HORIZON):
        current_age = age + yr
        if current_age < retirement_age:
            contributions[:, yr] = profile.get("income", 75000) / 12 * 12

    # Apply inflation to contributions
    inflation_factors = np.array([(1 + INFLATION) ** yr for yr in range(HORIZON)])
    contributions = contributions * inflation_factors

    # Simulate portfolio growth
    portfolio_values = np.zeros((num_simulations, HORIZON + 1))
    portfolio_values[:, 0] = 0  # Starting from zero

    for yr in range(HORIZON):
        portfolio_values[:, yr + 1] = portfolio_values[:, yr] * (1 + annual_returns[:, yr]) + contributions[:, yr]

    final_values = portfolio_values[:, -1]
    median_val = float(np.median(final_values))
    success_by_age = []

    for check_age in range(age, retirement_age + 5):
        yr_idx = check_age - age
        if yr_idx < 0:
            continue
        if yr_idx >= HORIZON:
            success_by_age.append({"age": check_age, "probability": 1.0})
            continue
        # Probability that portfolio hasn't gone below zero by this age
        prob = float(np.mean(portfolio_values[:, yr_idx] > 0))
        success_by_age.append({"age": check_age, "probability": round(prob, 4)})

    # Probability of success: portfolio > some threshold at retirement
    # Use a simple threshold: portfolio must exceed 1 year of expenses
    threshold = profile.get("income", 75000) * 0.5
    probability_of_success = float(np.mean(final_values > threshold))

    # Sort final values for worst/best case
    sorted_vals = np.sort(final_values)
    worst_case = float(sorted_vals[int(num_simulations * 0.05)])  # 5th percentile
    best_case = float(sorted_vals[int(num_simulations * 0.95)])  # 95th percentile

    return {
        "probability_of_success": round(probability_of_success, 4),
        "median_portfolio_at_retirement": round(median_val, 2),
        "worst_case": round(worst_case, 2),
        "best_case": round(best_case, 2),
        "success_by_age": success_by_age,
        "num_simulations": num_simulations,
    }


def calculate_projection(profile: dict, portfolio: dict, years: int = 30) -> list[dict[str, Any]]:
    """Calculate projected portfolio value over time.

    Args:
        profile: dict with age, retirement_age, income, house_value
        portfolio: dict with allocations
        years: projection horizon

    Returns:
        list of dicts with year, age, projected_value, cumulative_contributions
    """
    age = profile["age"]
    retirement_age = profile["retirement_age"]

    portfolio = {k: v for k, v in portfolio.items() if k in RATES}
    total_alloc = sum(portfolio.values())
    if total_alloc == 0:
        portfolio = {"stocks": 1.0}
        total_alloc = 1.0

    expected_return = sum(RATES[k] * (portfolio[k] / total_alloc) for k in portfolio)

    projection = []
    cumulative = 0.0
    value = 0.0

    for yr in range(years):
        current_age = age + yr
        if current_age < retirement_age:
            annual_contribution = profile.get("income", 75000)
        else:
            annual_contribution = 0

        cumulative += annual_contribution
        # Apply return with some randomness for the median path
        value = value * (1 + expected_return) + annual_contribution

        projection.append({
            "year": yr + 1,
            "age": current_age,
            "projected_value": round(value, 2),
            "cumulative_contributions": round(cumulative, 2),
        })

    return projection
