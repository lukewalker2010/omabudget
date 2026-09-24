.pragma library

// Pure budget data logic for the omabudget plugin.
// Everything here is locale- and Qt-free so it can be unit tested
// independently; the QML owns date formatting and display through
// Qt.formatDateTime and Qt.locale().

var MS_PER_DAY = 86400000

var PREDEFINED_CATEGORIES = [
  {id: "housing", name: "Housing", icon: "home", type: "expense", color: "#E8632A", budget_limit: 1500.0},
  {id: "food", name: "Food", icon: "fork-knife", type: "expense", color: "#F5A623", budget_limit: 600.0},
  {id: "transport", name: "Transport", icon: "car", type: "expense", color: "#3B82F6", budget_limit: 300.0},
  {id: "utilities", name: "Utilities", icon: "bolt", type: "expense", color: "#8B5CF6", budget_limit: 200.0},
  {id: "healthcare", name: "Healthcare", icon: "heart-pulse", type: "expense", color: "#EF4444", budget_limit: 150.0},
  {id: "shopping", name: "Shopping", icon: "bag-shopping", type: "expense", color: "#EC4899", budget_limit: 250.0},
  {id: "entertainment", name: "Entertainment", icon: "gamepad", type: "expense", color: "#10B981", budget_limit: 200.0},
  {id: "income", name: "Income", icon: "arrow-down", type: "income", color: "#10B981", budget_limit: 0.0},
  {id: "savings", name: "Savings", icon: "piggy-bank", type: "savings", color: "#F59E0B", budget_limit: 0.0},
  {id: "debt", name: "Debt", icon: "credit-card", type: "expense", color: "#6B7280", budget_limit: 0.0},
  {id: "subscriptions", name: "Subscriptions", icon: "playlist", type: "expense", color: "#06B6D4", budget_limit: 100.0}
]

var MONTH_NAMES = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
var MONTH_FULL_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

function formatCurrency(amount) {
  var sign = amount < 0 ? "-" : ""
  var abs = Math.abs(Number(amount))
  var dollars = Math.floor(abs)
  var cents = Math.round((abs - dollars) * 100)
  return sign + "$" + dollars.toLocaleString() + "." + (cents < 10 ? "0" : "") + cents
}

function formatDate(dateStr) {
  var d = new Date(dateStr)
  if (isNaN(d.getTime())) return dateStr
  return MONTH_NAMES[d.getMonth()] + " " + d.getDate() + ", " + d.getFullYear()
}

function getMonthsAgo(n) {
  var d = new Date()
  d.setMonth(d.getMonth() - n)
  return d.toISOString().split("T")[0]
}

function getMonthYear(dateStr) {
  var d = new Date(dateStr)
  if (isNaN(d.getTime())) return dateStr
  return MONTH_NAMES[d.getMonth()] + " " + d.getFullYear()
}

function calculatePercent(spent, budget) {
  if (budget <= 0) return 0
  return Math.min(100, Math.max(0, (spent / budget) * 100))
}

function getCategoryIcon(categoryName) {
  var cat = PREDEFINED_CATEGORIES.find(function(c) { return c.name === categoryName })
  return cat ? cat.icon : "circle"
}

function categorizeTransaction(amount) {
  return amount >= 0 ? "income" : "expense"
}

function getPredefinedCategories() {
  return PREDEFINED_CATEGORIES.slice()
}

function sortTransactions(transactions, sortBy, sortOrder) {
  var arr = transactions.slice()
  var dir = sortOrder === "asc" ? 1 : -1
  arr.sort(function(a, b) {
    var va, vb
    if (sortBy === "date") { va = a.date; vb = b.date }
    else if (sortBy === "amount") { va = a.amount; vb = b.amount }
    else if (sortBy === "category") { va = (a.category || {}).name || a.category_id || ""; vb = (b.category || {}).name || b.category_id || "" }
    else { va = a.date; vb = b.date }
    if (va < vb) return -1 * dir
    if (va > vb) return 1 * dir
    return 0
  })
  return arr
}

function groupTransactionsByCategory(transactions) {
  var groups = {}
  for (var i = 0; i < transactions.length; i++) {
    var key = transactions[i].category_id || transactions[i].category || "uncategorized"
    if (!groups[key]) groups[key] = []
    groups[key].push(transactions[i])
  }
  return groups
}

function calculateMonthlySummary(transactions, year, month) {
  var totalIncome = 0
  var totalExpenses = 0
  var byCategory = {}
  var y = Number(year)
  var m = Number(month)
  var mStr = String(m).padStart(2, "0")

  for (var i = 0; i < transactions.length; i++) {
    var tx = transactions[i]
    var txDate = new Date(tx.date)
    if (isNaN(txDate.getTime())) continue
    if (txDate.getFullYear() !== y || (txDate.getMonth() + 1) !== m) continue

    if (tx.type === "income") {
      totalIncome += tx.amount
    } else if (tx.type === "expense") {
      totalExpenses += tx.amount
      var catKey = tx.category_id || "uncategorized"
      if (!byCategory[catKey]) byCategory[catKey] = {category_id: catKey, spent: 0, budget: 0}
      byCategory[catKey].spent += tx.amount
    }
  }

  return {
    totalIncome: Math.round(totalIncome * 100) / 100,
    totalExpenses: Math.round(totalExpenses * 100) / 100,
    savingsRate: totalIncome > 0 ? Math.round((totalIncome - totalExpenses) / totalIncome * 10000) / 100 : 0,
    byCategory: byCategory
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    formatCurrency: formatCurrency,
    formatDate: formatDate,
    getMonthsAgo: getMonthsAgo,
    getMonthYear: getMonthYear,
    calculatePercent: calculatePercent,
    getCategoryIcon: getCategoryIcon,
    categorizeTransaction: categorizeTransaction,
    getPredefinedCategories: getPredefinedCategories,
    sortTransactions: sortTransactions,
    groupTransactionsByCategory: groupTransactionsByCategory,
    calculateMonthlySummary: calculateMonthlySummary
  }
}
