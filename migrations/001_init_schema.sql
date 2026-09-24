-- omabudget initial schema migration
-- All tables are created with IF NOT EXISTS for idempotency.

CREATE TABLE IF NOT EXISTS financial_profile (
    key TEXT PRIMARY KEY,
    value TEXT
);

CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    type TEXT CHECK(type IN ('expense', 'income', 'savings')) NOT NULL,
    budget_limit REAL DEFAULT 0,
    is_predefined BOOLEAN DEFAULT 0,
    color TEXT DEFAULT '#888888'
);

CREATE TABLE IF NOT EXISTS accounts (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT CHECK(type IN ('checking', 'savings', 'investment', 'credit_card', 'cash')) NOT NULL,
    balance REAL DEFAULT 0,
    interest_rate REAL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS transactions (
    id TEXT PRIMARY KEY,
    category_id TEXT,
    account_id TEXT,
    amount REAL NOT NULL,
    date TEXT NOT NULL,
    description TEXT,
    type TEXT CHECK(type IN ('income', 'expense', 'transfer')) NOT NULL,
    source TEXT DEFAULT 'manual',
    raw_data TEXT,
    created_at TEXT
);

CREATE TABLE IF NOT EXISTS budget_months (
    id TEXT PRIMARY KEY,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    category_id TEXT,
    spent REAL DEFAULT 0
);

-- Insert 11 predefined categories
INSERT OR IGNORE INTO categories (id, name, icon, type, budget_limit, is_predefined, color) VALUES
    ('housing', 'Housing', 'home', 'expense', 1500.0, 1, '#E8632A'),
    ('food', 'Food', 'fork-knife', 'expense', 600.0, 1, '#F5A623'),
    ('transport', 'Transport', 'car', 'expense', 300.0, 1, '#3B82F6'),
    ('utilities', 'Utilities', 'bolt', 'expense', 200.0, 1, '#8B5CF6'),
    ('healthcare', 'Healthcare', 'heart-pulse', 'expense', 150.0, 1, '#EF4444'),
    ('shopping', 'Shopping', 'bag-shopping', 'expense', 250.0, 1, '#EC4899'),
    ('entertainment', 'Entertainment', 'gamepad', 'expense', 200.0, 1, '#10B981'),
    ('income', 'Income', 'arrow-down', 'income', 0.0, 1, '#10B981'),
    ('savings', 'Savings', 'piggy-bank', 'savings', 0.0, 1, '#F59E0B'),
    ('debt', 'Debt', 'credit-card', 'expense', 0.0, 1, '#6B7280'),
    ('subscriptions', 'Subscriptions', 'playlist', 'expense', 100.0, 1, '#06B6D4');

-- Create indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_budget_months_lookup ON budget_months(year, month, category_id);
