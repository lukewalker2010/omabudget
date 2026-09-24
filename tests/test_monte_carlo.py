"""Tests for Monte Carlo simulation."""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from lib.monte_carlo import run_simulation, calculate_projection
from lib.honestmath import get_rate_of_return


def test_run_simulation_structure():
    profile = {
        "age": 30,
        "retirement_age": 60,
        "income": 80000,
        "house_value": 350000,
    }
    portfolio = {"cash": 0.1, "bonds": 0.2, "stocks": 0.7}
    result = run_simulation(profile, portfolio, num_simulations=100)

    assert "probability_of_success" in result
    assert "median_portfolio_at_retirement" in result
    assert "worst_case" in result
    assert "best_case" in result
    assert "success_by_age" in result
    assert isinstance(result["probability_of_success"], float)
    assert 0 <= result["probability_of_success"] <= 1
    assert result["median_portfolio_at_retirement"] > 0
    assert result["worst_case"] <= result["best_case"]
    assert isinstance(result["success_by_age"], list)
    assert len(result["success_by_age"]) > 0
    assert "num_simulations" in result
    print("PASS: test_run_simulation_structure")


def test_calculate_projection():
    profile = {"age": 30, "retirement_age": 60, "income": 80000}
    portfolio = {"stocks": 0.7, "bonds": 0.2, "cash": 0.1}
    projection = calculate_projection(profile, portfolio, years=10)

    assert isinstance(projection, list)
    assert len(projection) == 10
    assert projection[0]["year"] == 1
    assert projection[0]["age"] == 30
    assert "projected_value" in projection[0]
    assert "cumulative_contributions" in projection[0]
    assert projection[-1]["projected_value"] > 0
    print("PASS: test_calculate_projection")


def test_get_rate_of_return():
    cash_ret, cash_vol = get_rate_of_return("cash")
    assert cash_ret == 0.005
    assert cash_vol == 0.01

    bond_ret, bond_vol = get_rate_of_return("bonds")
    assert bond_ret == 0.035
    assert bond_vol == 0.05

    stock_ret, stock_vol = get_rate_of_return("stocks")
    assert stock_ret == 0.08
    assert stock_vol == 0.15

    re_ret, re_vol = get_rate_of_return("real_estate")
    assert re_ret == 0.04
    assert re_vol == 0.08

    unknown_ret, unknown_vol = get_rate_of_return("unknown")
    assert unknown_ret == 0.0
    assert unknown_vol == 0.0
    print("PASS: test_get_rate_of_return")


if __name__ == "__main__":
    test_run_simulation_structure()
    test_calculate_projection()
    test_get_rate_of_return()
    print("\nAll Monte Carlo tests passed!")
