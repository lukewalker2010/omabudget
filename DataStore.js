.pragma library

// Bridge communication layer for omabudget.
// Communicates with the Python bridge at ~/.config/omarchy/plugins/omabudget/bin/omabudget-bridge
// using NDJSON over stdin/stdout via a Process.
//
// Usage:
//   DataStore.setProcess(proc)
//   DataStore.init(function(result) { ... })
//   DataStore.getTransactions({}, function(result) { ... })

var _process = null
var _callbacks = {}
var _nextId = 1

function setProcess(proc) {
  _process = proc
}

function getProcess() {
  return _process
}

function _send(command, cb) {
  var proc = _process
  if (!proc) return null
  var id = _nextId++
  if (cb) _callbacks[id] = cb
  var payload = {}
  for (var key in command) payload[key] = command[key]
  payload.id = id
  proc.write(JSON.stringify(payload) + "\n")
  return id
}

function handleResponse(obj) {
  var id = obj.id
  if (id && _callbacks[id]) {
    _callbacks[id](obj)
    delete _callbacks[id]
  }
}

function init(cb) {
  return _send({op: "init_db"}, cb)
}

function addTransaction(tx, cb) {
  return _send({op: "add_transaction", params: tx}, cb)
}

function getTransactions(filters, cb) {
  return _send({op: "get_transactions", params: {filters: filters}}, cb)
}

function getMonthlySummary(year, month, cb) {
  return _send({op: "get_monthly_summary", params: {year: year, month: month}}, cb)
}

function getNetWorth(cb) {
  return _send({op: "get_net_worth"}, cb)
}

function getProjections(profile, portfolio, numSims, cb) {
  return _send({op: "get_projections", params: {profile: profile, portfolio: portfolio, num_simulations: numSims}}, cb)
}

function parseStatement(filepath, fileType, cb) {
  return _send({op: "parse_statement", params: {filepath: filepath, file_type: fileType}}, cb)
}

function getCategories(cb) {
  return _send({op: "get_categories"}, cb)
}

function addCategory(cat, cb) {
  return _send({op: "add_category", params: cat}, cb)
}

function getProfile(key, cb) {
  return _send({op: "get_profile", params: {key: key}}, cb)
}

function updateProfile(key, value, cb) {
  return _send({op: "update_profile", params: {key: key, value: value}}, cb)
}

function getCashFlow(year, month, cb) {
  return _send({op: "get_cash_flow", params: {year: year, month: month}}, cb)
}

function ensureStarted(proc) {
  if (_process) return true
  if (proc) {
    setProcess(proc)
    return true
  }
  return false
}
