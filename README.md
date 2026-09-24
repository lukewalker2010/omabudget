# omabudget

Track your finances, manage budgets, and project your retirement from
the Omarchy desktop bar.

Quickshell plugin for **Omarchy 4**. Add transactions, monitor spending
by category, and run Monte Carlo simulations on your financial future.
All data is stored locally on your machine.

## Features

- **Transaction tracking**: Add, filter, and browse income and expense
  transactions with categories, accounts, and dates.
- **Budget categories**: 11 predefined categories with icons and colors.
  Create custom categories with your own budget limits and track spending
  progress per category.
- **Monte Carlo projections**: Run 10,000-iteration retirement simulations
  to estimate your probability of financial success by retirement age.
- **Deterministic projections**: See projected portfolio growth over time
  using rate-of-return models for cash, bonds, stocks, and real estate.
- **Statement parsing**: Import transaction history from CSV, PDF bank
  statements, or scanned images using OCR. Parsed transactions are inserted
  into the local database.
- **Net worth tracking**: View total assets, liabilities, and net worth
  computed from account balances and profile values.
- **Monthly cash flow**: See income, expenses, and savings rate for any
  month at a glance.

## Install

```bash
omarchy plugin add https://github.com/yourname/omabudget.git --enable
```

For local development, symlink the checkout instead:

```bash
ln -sfn "$PWD" ~/.config/omarchy/plugins/omabudget
omarchy restart shell
omarchy plugin enable omabudget
```

## Usage

Click the omabudget bar widget to open the panel. Use the tab selector
at the top to navigate between Overview, Transactions, Projections, and
Settings. Press Escape to close the panel.

### Adding a transaction

Open the Transactions tab and use the add form. Select the type (income
or expense), pick a category and account, enter the amount and date, and
add an optional description. Transactions are stored locally in SQLite.

### Managing categories and accounts

Open Settings to create new categories or accounts. Categories have
predefined icons and colors; custom ones can be added with any icon and
color. Accounts track balances across checking, savings, investment,
credit card, and cash types.

### Running projections

Open the Projections tab to configure your financial profile (age,
retirement age, income, house value) and portfolio allocation (cash,
bonds, stocks, real estate). Run a Monte Carlo simulation to see your
probability of success, or view a deterministic projection path.

### Parsing statements

Use the Statements tab to import bank statements. Supports CSV files
with Date/Description/Amount columns, PDF statements, and scanned
images via OCR. Parsed transactions are inserted into the local
database.

## Configuration

All configuration is stored locally:

- **Database**: `~/.local/state/omabudget/omabudget.db`
- **Profile settings**: Stored in the `financial_profile` table
  (house value, retirement age, income targets, etc.)
- **Category budgets**: Set per-category limits in the categories table

No data is sent to any server. No telemetry is collected. Everything
is on your machine.

## Remove

```bash
omarchy plugin disable omabudget
omarchy plugin remove omabudget
```

To remove all local data:

```bash
rm -rf ~/.local/state/omabudget
```

## Requirements

- Omarchy 4 (`schemaVersion: 1` plugin API)
- Python 3.11 or newer
- SQLite3 (bundled with Python)
- `numpy` (for Monte Carlo simulations)
- `pypdf` and `pytesseract` (for PDF/image statement parsing)

## License

MIT — see [`LICENSE`](LICENSE).
