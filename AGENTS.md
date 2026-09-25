# omabudget for Omarchy

## Project overview

This repository is an Omarchy 4 Quickshell plugin for personal budgeting
and financial tracking from the desktop bar. The UI is QML with small
pure JavaScript modules. A long-lived Python bridge owns the SQLite
database connection and communicates with QML over versioned NDJSON on
stdin/stdout.

All financial data is stored locally in `~/.local/state/omabudget/omabudget.db`.
There is no network communication, no telemetry, and no external
service dependency of any kind.

## Architecture map

- `Panel.qml`: Bar widget, popup panel, keyboard navigation, and IPC surface.
  Contains all tab views (Overview, Transactions, Projections, Settings).
- `BarWidget.qml`: Bar surface entry point. Displays budget summary and
  hosts the panel via Loader.
- `DataStore.js`: Bridge communication layer. Sends NDJSON commands to
  the Python bridge via `Process` stdin/stdout with `SplitParser`.
- `Model.js`: Pure JavaScript data logic. Formatting, sorting, categorization,
  and monthly summary calculations.
- `manifest.json`: Plugin metadata and entry points.
- `lib/database.py`: SQLite3 database layer with all CRUD operations.
- `lib/calculations.py`: Budget math, net worth, and cash flow calculations.
- `lib/monte_carlo.py`: Monte Carlo retirement simulation using numpy.
- `lib/honestmath.py`: Deterministic rate-of-return projection model.
- `lib/statements.py`: CSV, PDF, and image statement parsing.
- `bin/omabudget-bridge`: Python3 NDJSON bridge process. Handles all 17 commands.
- `migrations/`: SQL schema migration scripts.
- `tests/`: Standalone Python tests using `assert` (no pytest dependency).

Keep transport, data access, calculation logic, and UI policy separate.
Prefer extending the existing pure JavaScript modules over adding more
policy to `Panel.qml`.

## Security invariants

- All financial data is stored locally in SQLite on disk. There is
  zero network communication, zero telemetry, and zero external
  service dependency. No data leaves the machine under any circumstance.
- The database file is stored under `~/.local/state/omabudget/` with
  file permissions restricted to the owning user.
- No secrets, tokens, or credentials are ever stored, transmitted,
  or logged. There is no authentication layer because there is no
  network service to authenticate against.
- Statement parsing operates on local files only. Parsed data is
  inserted into the local database and never transmitted.
- Use argument arrays for `Process`; do not introduce shell interpolation
  for file paths, commands, or any user-supplied data.

## Coding conventions

- Keep JavaScript helpers side-effect free where practical and compatible
  with the QML JavaScript engine. Do not add Node-only APIs to
  production modules.
- Validate external JSON shapes before indexing or rendering them.
  Use safe map keys or prototype-free maps for user-controlled identifiers.
- Use `Style` and `Color` tokens in QML. Every `Text` must set
  `textFormat: Text.PlainText` and an explicit font family.
- Keep high-frequency transaction updates incremental. Avoid copying or
  rebuilding the entire collection for a known transaction change.
- Python code follows PEP 8 conventions. Type hints are required on all
  public functions. Module-level imports are grouped: standard library,
  third-party, local.
- Preserve public IPC commands and the NDJSON protocol unless a versioned
  migration is part of the task.
- SQL migrations must be idempotent and use `IF NOT EXISTS` for all
  table and column creation.

## Bridge protocol

The Python bridge (`bin/omabudget-bridge`) communicates with QML over NDJSON
(Newline-Delimited JSON) on stdin/stdout. Every message is a single
JSON object on one line.

### Command format (QML → Bridge)

```json
{"op": "<command>", "id": <request_id>, "params": {...}}
```

### Response format (Bridge → QML)

```json
{"id": <request_id>, "status": "ok|error", "result": {...}, "error_msg": null}
```

### Commands the bridge accepts

| `op` field | Description |
|---|---|
| `init_db` | Initialize the database and return schema version |
| `add_transaction` | Insert a new transaction into the database |
| `get_transactions` | Query transactions with optional filters |
| `get_monthly_summary` | Return budget, spending, category progress for a month |
| `get_net_worth` | Return total assets, liabilities, and net worth |
| `get_projections` | Run Monte Carlo retirement simulation |
| `parse_statement` | Parse a CSV, PDF, or image statement file |
| `get_categories` | Return all budget categories |
| `add_category` | Add a new custom category |
| `get_profile` | Get financial profile value(s) by key |
| `update_profile` | Set a financial profile key-value pair |
| `get_cash_flow` | Return income, expenses, and savings rate for a month |
| `update_transaction` | Update mutable fields (amount, date, description, category) of a transaction |
| `delete_transaction` | Delete a transaction by id |
| `set_budget_limit` | Set a category's budget limit |
| `get_accounts` | Return all accounts |
| `delete_category` | Delete a non-predefined category |

### NDJSON rules

- Each message is exactly one JSON object followed by `\n`.
- Commands and responses share the same `id` field for correlation.
- The bridge processes one command at a time and responds before
  reading the next command.
- Large result sets (e.g., full transaction history) are returned as
  arrays in the `result` field.
- Error responses include an `error_msg` field with a human-readable
  description.

## File structure explanation

```
omabudget/
├── manifest.json          Plugin metadata and entry points
├── AGENTS.md              This file: development documentation
├── README.md              User-facing documentation
├── LICENSE                MIT license
├── preview.png            Plugin preview image
├── .gitignore             Build artifacts and database exclusions
├── BarWidget.qml          Bar surface entry point
├── Panel.qml              Main panel with all tab views
├── Model.js               Pure JS data logic and formatting
├── DataStore.js           Bridge communication layer
├── bin/
│   └── omabudget-bridge   Python3 NDJSON bridge (executable)
├── lib/
│   ├── database.py        SQLite3 database layer
│   ├── calculations.py    Budget math, net worth, cash flow
│   ├── monte_carlo.py     Monte Carlo retirement simulation
│   ├── honestmath.py      Deterministic rate-of-return model
│   └── statements.py      CSV/PDF/image statement parsing
├── migrations/
│   └── 001_init_schema.sql Initial database schema
├── tests/                 Test suite (standalone, no pytest)
│   ├── test_database.py
│   ├── test_calculations.py
│   └── test_monte_carlo.py
└── .git/                  Git repository
```

## Testing instructions

```bash
python3 -m py_compile lib/*.py
python3 tests/test_database.py
python3 tests/test_calculations.py
python3 tests/test_monte_carlo.py
ls -la ~/.local/state/omabudget/omabudget.db
```

Verify the database schema:
```bash
sqlite3 ~/.local/state/omabudget/omabudget.db ".tables"
sqlite3 ~/.local/state/omabudget/omabudget.db ".schema"
sqlite3 ~/.local/state/omabudget/omabudget.db "SELECT COUNT(*) FROM categories;"
```

When available, also run `qmllint` and `omarchy plugin validate .`.
Tests must not depend on network access or external services.

## Adding new categories

Categories are defined in the `categories` table with these fields:
`id`, `name`, `icon`, `type`, `budget_limit`, `is_predefined`, `color`.

1. Choose a unique `id` (snake_case, e.g., `new_category`).
2. Pick an icon from the available icon set.
3. Set `type` to one of `expense`, `income`, or `savings`.
4. Optionally set a `budget_limit` (0 if not applicable).
5. Choose a `color` hex string (e.g., `#FF5733`).
6. Insert via the bridge command `add_category` or directly in SQL:
   ```sql
   INSERT INTO categories (id, name, icon, type, budget_limit, is_predefined, color)
   VALUES ('new_category', 'New Category', 'icon-name', 'expense', 300.0, 0, '#FF5733');
   ```
7. If adding a predefined category, set `is_predefined` to 1. Custom
   categories created by the user have `is_predefined` set to 0.

## Adding new accounts

Accounts are defined in the `accounts` table with these fields:
`id`, `name`, `type`, `balance`, `interest_rate`.

1. Choose a unique `id` (snake_case, e.g., `checking_primary`).
2. Set `type` to one of `checking`, `savings`, `investment`,
   `credit_card`, or `cash`.
3. Set the current `balance` and optional `interest_rate`.
4. Insert via the bridge command `add_account` or directly in SQL:
   ```sql
   INSERT INTO accounts (id, name, type, balance, interest_rate)
   VALUES ('checking_primary', 'Primary Checking', 'checking', 5000.0, 0.0);
   ```

## Running the bridge manually for debugging

The bridge process can be run standalone from the terminal:

```bash
# Run the bridge in interactive mode (reads NDJSON from stdin)
python3 bin/omabudget-bridge

# Test a single command
echo '{"op": "init_db", "id": 1, "params": {}}' | python3 bin/omabudget-bridge

# Check bridge responds
echo '{"op": "get_categories", "id": 2, "params": {}}' | python3 bin/omabudget-bridge
```

The bridge prints NDJSON responses to stdout. Errors are printed as
NDJSON error messages with the same `id` for correlation.

To debug the full pipeline, start the bridge and pipe commands interactively:

```bash
python3 bin/omabudget-bridge
# Then type commands one per line:
{"op": "get_transactions", "id": 2, "params": {"filters": {"type": "expense"}}}
```

Press Ctrl-D to end input and exit.

## QML development notes

- The bridge must be spawned as a `Process` with `stdinEnabled: true`.
- Use `SplitParser` on stdout to read NDJSON lines.
- Call `DataStore.setProcess(proc)` to inject the Process into the JS layer.
- All QML text must have `textFormat: Text.PlainText` and explicit `fontFamily`.
- Use `Style.space()`, `Style.font.*`, `Color.*` from `qs.Commons`.
- Follow the `lgw.clock` plugin pattern for BarWidget + Panel structure.
- The `IpcHandler` with `target: "omabudget"` enables inter-plugin communication.
- Use `root.settings` for per-widget preferences persisted to `shell.json`.
