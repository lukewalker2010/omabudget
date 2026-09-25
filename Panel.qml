import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "DataStore.js" as DataStore

Panel {
  id: root
  moduleName: "omabudget"
  ipcTarget: "omabudget"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground

  property int selectedTab: 0
  readonly property var tabs: ["Overview", "Transactions", "Projections", "Settings"]

  property var categories: []
  property var transactions: []
  property var profile: ({age: 30, retirementAge: 65, householdSize: 1, income: 75000, houseValue: 300000})
  property var portfolio: ({cash: 0.1, bonds: 0.2, stocks: 0.7})
  property var projectionResult: ({probabilityOfSuccess: 0, medianPortfolioAtRetirement: 0, worstCase: 0, bestCase: 0})
  property bool simulationRunning: false
  property string projectionError: ""
  property string importStatus: ""
  property bool addFormVisible: false

  property date currentDate: new Date()
  property int currentYear: currentDate.getFullYear()
  property int currentMonth: currentDate.getMonth() + 1

  property var currentSummary: ({totalBudget: 0, totalSpent: 0, remaining: 0})
  property var cashFlowData: ({totalIncome: 0, totalExpenses: 0, savingsRate: 0})
  property var netWorthData: ({totalAssets: 0, totalLiabilities: 0, net_worth: 0})

  function open() {
    root.controller.show()
    loadData()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && typeof root.bar.setCenterHoverRevealSuppressed === "function")
      root.bar.setCenterHoverRevealSuppressed(value)
    else if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function refresh() {
    loadData()
    open()
  }

  function loadData() {
    DataStore.getCategories(function(result) {
      if (result && result.status === "ok" && result.result && result.result.categories)
        categories = result.result.categories
    })
    DataStore.getTransactions({}, function(result) {
      if (result && result.status === "ok" && result.result && result.result.transactions)
        transactions = result.result.transactions
    })
    DataStore.getNetWorth(function(result) {
      if (result && result.status === "ok" && result.result)
        netWorthData = result.result
    })
    DataStore.getCashFlow(new Date().getFullYear(), new Date().getMonth() + 1, function(result) {
      if (result && result.status === "ok" && result.result)
        cashFlowData = result.result
    })
  }

  function setCurrentTab(index) {
    selectedTab = index
  }

  function addTransaction(tx) {
    DataStore.addTransaction(tx, function(result) {
      if (result && result.status === "ok") refresh()
    })
  }

  function runSimulation() {
    simulationRunning = true
    projectionError = ""
    var p = {
      age: Number(profileAge.value) || 30,
      retirement_age: Number(profileRetirementAge.value) || 65,
      household_size: 1,
      income: Number(profileIncome.value) || 0,
      house_value: Number(profileHouseValue.value) || 0
    }
    var alloc = {
      cash: Number(portfolio.cash) || 0,
      bonds: Number(portfolio.bonds) || 0,
      stocks: Number(portfolio.stocks) || 0
    }
    DataStore.getProjections(p, alloc, 10000, function(result) {
      if (result && result.status === "ok" && result.result) {
        var r = result.result
        projectionResult = {
          probabilityOfSuccess: r.probability_of_success || 0,
          medianPortfolioAtRetirement: r.median_portfolio_at_retirement || 0,
          worstCase: r.worst_case || 0,
          bestCase: r.best_case || 0,
          successByAge: r.success_by_age || []
        }
      } else {
        projectionError = (result && result.error_msg) ? String(result.error_msg) : "Simulation failed"
      }
      simulationRunning = false
    })
  }

  function importStatement(path) {
    var p = String(path || "").trim()
    if (!p) {
      importStatus = "Enter a file path first"
      return
    }
    var lower = p.toLowerCase()
    var ftype = lower.indexOf(".csv") === lower.length - 4 ? "csv"
      : lower.indexOf(".pdf") === lower.length - 4 ? "pdf" : "image"
    importStatus = "Parsing " + p + "..."
    DataStore.parseStatement(p, ftype, function(result) {
      if (!result || result.status !== "ok" || !result.result) {
        importStatus = "Import failed: " + ((result && result.error_msg) ? result.error_msg : "unknown error")
        return
      }
      var parsed = result.result
      if (!parsed || !parsed.length) {
        importStatus = "No transactions found in file"
        return
      }
      var imported = 0
      parsed.forEach(function(t, i) {
        DataStore.addTransaction({
          id: "tx_" + Date.now() + "_" + i,
          category_id: "",
          account_id: "",
          amount: t.amount,
          date: t.date || "",
          description: t.description || "",
          type: t.type || "expense",
          source: t.source || "statement"
        }, function(addResult) {
          if (addResult && addResult.status === "ok") imported++
          if (i === parsed.length - 1) {
            importStatus = "Imported " + imported + " of " + parsed.length + " transactions"
            loadData()
          }
        })
      })
    })
  }

  function setAllocation(key, value) {
    portfolio[key] = value
    var total = portfolio.cash + portfolio.bonds + portfolio.stocks
    if (Math.abs(total - 1.0) > 0.001) {
      var diff = 1.0 - total
      portfolio.stocks = Math.max(0, portfolio.stocks + diff)
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      currentDate = clock.date
      currentYear = clock.date.getFullYear()
      currentMonth = clock.date.getMonth() + 1
    }
  }

  readonly property int barIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: false

  function closeForPopoutSwitch() {
    close()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "1") root.selectedTab = 0
        else if (t === "2") root.selectedTab = 1
        else if (t === "3") root.selectedTab = 2
        else if (t === "4") root.selectedTab = 3
      }

      Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: contentColumn.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width

        Column {
          id: contentColumn
          width: Math.max(flickable.width, Style.space(520))
          spacing: Style.space(8)

          // ---- Tab selector ----
          Row {
            spacing: Style.space(4)
            width: parent.width

Repeater {
              model: root.tabs

              Item {
                width: Style.space(80)
                height: Style.space(30)
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedTab = index
                    Text {
                      anchors.centerIn: parent
                      text: modelData
                      color: root.selectedTab === index ? Color.accent : root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: root.selectedTab === index
                    }
                  }
                }
              }
          }

          PanelSeparator { foreground: root.contentForeground }

          // ---- Tab content ----
          Loader {
            id: tabLoader
            width: parent.width
            sourceComponent: {
              if (root.selectedTab === 0) overviewComponent
              else if (root.selectedTab === 1) transactionsComponent
              else if (root.selectedTab === 2) projectionsComponent
              else settingsComponent
            }
            active: true
          }
        }
      }
    }
  }

  Component {
    id: overviewComponent

    Item {
      width: parent.width
      height: tabContent.implicitHeight
      Column {
        id: tabContent
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader { text: "Monthly Budget"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(50)
            BorderSurface {
              anchors.fill: parent
              color: Color.popups.background
              borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
              radius: Style.cornerRadius
              padding: Style.space(8)

              Column {
                anchors.centerIn: parent
                spacing: Style.space(2)

                Text { textFormat: Text.PlainText; text: "Spent"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency(currentSummary.totalSpent); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.displayLarge; font.bold: true }
              }
            }
          }

          Item {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(50)
            BorderSurface {
              anchors.fill: parent
              color: Color.popups.background
              borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
              radius: Style.cornerRadius
              padding: Style.space(8)

              Column {
                anchors.centerIn: parent
                spacing: Style.space(2)

                Text { textFormat: Text.PlainText; text: "Budget"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency(currentSummary.totalBudget); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.displayLarge; font.bold: true }
              }
            }
          }

          Item {
            width: (parent.width - Style.space(16)) / 3
            height: Style.space(50)
            BorderSurface {
              anchors.fill: parent
              color: Color.popups.background
              borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
              radius: Style.cornerRadius
              padding: Style.space(8)

              Column {
                anchors.centerIn: parent
                spacing: Style.space(2)

                Text { textFormat: Text.PlainText; text: "Remaining"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency(currentSummary.remaining); color: currentSummary.remaining < 0 ? Color.urgent : root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.displayLarge; font.bold: true }
              }
            }
          }
        }

        Item {
          width: parent.width
          height: Style.space(20)
          PanelSlider {
            anchors.fill: parent
            value: currentSummary.totalBudget > 0 ? Math.min(1, Math.max(0, Model.calculatePercent(currentSummary.totalSpent, currentSummary.totalBudget) / 100)) : 0
            minimum: 0
            maximum: 1
            trackColor: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
            fillColor: currentSummary.remaining < 0 ? Color.urgent : (Model.calculatePercent(currentSummary.totalSpent, currentSummary.totalBudget) > 90 ? "#F59E0B" : "#10B981")
            knobColor: root.contentForeground
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        PanelSectionHeader { text: "Cash Flow"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Item {
            width: (parent.width - Style.space(16)) / 2
            height: Style.space(40)
            BorderSurface {
              anchors.fill: parent
              color: Color.popups.background
              borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
              radius: Style.cornerRadius
              padding: Style.space(8)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text { textFormat: Text.PlainText; text: "Income: "; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency(cashFlowData.totalIncome); color: "#10B981"; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
              }
            }
          }

          Item {
            width: (parent.width - Style.space(16)) / 2
            height: Style.space(40)
            BorderSurface {
              anchors.fill: parent
              color: Color.popups.background
              borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
              radius: Style.cornerRadius
              padding: Style.space(8)

              Row {
                anchors.centerIn: parent
                spacing: Style.space(6)

                Text { textFormat: Text.PlainText; text: "Expenses: "; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency(cashFlowData.totalExpenses); color: "#EF4444"; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
              }
            }
          }
        }

        PanelSectionHeader { text: "Net Worth"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Item {
          width: parent.width
          height: Style.space(40)
          BorderSurface {
            anchors.fill: parent
            color: Color.popups.background
            borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
            radius: Style.cornerRadius
            padding: Style.space(8)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text { textFormat: Text.PlainText; text: "Net Worth: "; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Text { textFormat: Text.PlainText; text: Model.formatCurrency(netWorthData.net_worth !== undefined ? netWorthData.net_worth : 0); color: netWorthData.net_worth >= 0 ? "#10B981" : "#EF4444"; font.family: root.contentFontFamily; font.pixelSize: Style.font.display; font.bold: true }
            }
          }
        }

        PanelSectionHeader { text: "Category Breakdown"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Repeater {
          model: categories


          Item {
            width: parent.width
            height: Style.space(28)
            Column {
              width: parent.width
              spacing: Style.space(2)

              Row {
                width: parent.width
                spacing: Style.space(4)

                Text { textFormat: Text.PlainText; text: modelData.name; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; width: Style.space(100) }
                Text { textFormat: Text.PlainText; text: Model.formatCurrency((currentSummary.byCategory && currentSummary.byCategory[modelData.id] ? currentSummary.byCategory[modelData.id].spent : 0) || 0); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { textFormat: Text.PlainText; text: Math.round(((currentSummary.byCategory && currentSummary.byCategory[modelData.id] ? currentSummary.byCategory[modelData.id].spent : 0) / (modelData.budget_limit || 1)) * 100) + "%"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              }

              Rectangle {
                width: parent.width
                height: Style.space(6)
                radius: Style.cornerRadius > 0 ? height / 2 : 0
                color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                Rectangle {
                  width: Math.min(parent.width, parent.width * Math.min(1, ((currentSummary.byCategory && currentSummary.byCategory[modelData.id] ? currentSummary.byCategory[modelData.id].spent : 0) / modelData.budget_limit) || 0))
                  height: parent.height
                  radius: parent.radius
                  color: Style.selectedStateColor(root.contentForeground, Color.accent)
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: transactionsComponent

    Item {
      width: parent.width
      height: tabContent.implicitHeight
      Column {
        id: tabContent
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader { text: "Transactions"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(4)

          SearchableDropdown {
            id: categoryFilter
            width: Style.spacing.dropdownWidth
            value: ""
            options: categories.map(function(c) { return {value: c.id, label: c.name} })
            placeholderText: "All categories"
            showLabel: false
            foreground: root.contentForeground
            background: Color.popups.background
            accent: Color.accent
            fontFamily: root.contentFontFamily
          }

          SearchableDropdown {
            width: Style.spacing.dropdownWidth
            value: "all"
            options: [{value: "all", label: "All Time"}, {value: "month", label: "This Month"}]
            placeholderText: "Period"
            showLabel: false
            foreground: root.contentForeground
            background: Color.popups.background
            accent: Color.accent
            fontFamily: root.contentFontFamily
          }

          PanelActionButton {
            iconText: "+"
            tooltipText: "Add transaction"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: addFormVisible = !addFormVisible
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        Item {
          width: parent.width
          visible: addFormVisible
          height: addFormVisible ? addFormColumn.implicitHeight : 0

          Column {
            id: addFormColumn
            width: parent.width
            spacing: Style.space(6)

            TextField {
              id: txDescription
              width: parent.width
              placeholderText: "Description"
              foreground: root.contentForeground
              accent: Color.accent
            }

            NumberField {
              id: txAmount
              width: parent.width
              label: "Amount"
              value: 0
              from: -999999
              to: 999999
              stepSize: 1
              foreground: root.contentForeground
              accent: Color.accent
              fontFamily: root.contentFontFamily
              fontSize: Style.font.body
            }

            Row {
              width: parent.width
              spacing: Style.space(4)

              SearchableDropdown {
                id: txCategory
                width: parent.width * 0.6
                value: ""
                options: categories.map(function(c) { return {value: c.id, label: c.name} })
                placeholderText: "Category"
                showLabel: false
                foreground: root.contentForeground
                background: Color.popups.background
                accent: Color.accent
                fontFamily: root.contentFontFamily
              }

              TextField {
                id: txDate
                width: parent.width * 0.4
                placeholderText: "Date"
                foreground: root.contentForeground
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(4)

              Button {
                text: "Add"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: true
                onClicked: {
                  var type = txAmount.value >= 0 ? "income" : "expense"
                  DataStore.addTransaction({
                    id: "tx_" + Date.now(),
                    category_id: txCategory.value,
                    account_id: "",
                    amount: txAmount.value,
                    date: txDate.text || new Date().toISOString().split("T")[0],
                    description: txDescription.text,
                    type: type
                  }, function(result) {
                    if (result && result.status === "ok") {
                      addFormVisible = false
                      refresh()
                    }
                  })
                }
              }

              Button {
                text: "Cancel"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: addFormVisible = false
              }
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        Row {
          width: parent.width
          spacing: Style.space(4)

          TextField {
            id: importPathField
            width: parent.width - Style.space(90)
            placeholderText: "Path to statement file (.csv, .pdf, or image)"
            foreground: root.contentForeground
            accent: Color.accent
          }

          Button {
            text: "Import"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.importStatement(importPathField.text)
          }
        }

        Text {
          width: parent.width
          visible: importStatus !== ""
          textFormat: Text.PlainText
          text: importStatus
          color: importStatus.indexOf("failed") !== -1 ? "#EF4444" : Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WrapAnywhere
        }

        Item {
          width: parent.width
          height: Math.min(Style.space(300), transactionFlickable.implicitHeight)
          clip: true

          Flickable {
            id: transactionFlickable
            anchors.fill: parent
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
              id: transactionList
              width: parent.width
              spacing: Style.space(2)

              Repeater {
                model: transactions


                Item {
                  width: parent.width
                  height: Style.space(32)

                  Row {
                    width: parent.width
                    spacing: Style.space(4)

                    Text { textFormat: Text.PlainText; text: Model.formatDate(modelData.date); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; width: Style.space(90) }
                    Text { textFormat: Text.PlainText; text: modelData.category || modelData.category_id || "?"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                    Text { textFormat: Text.PlainText; text: modelData.description || ""; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
                    Text { textFormat: Text.PlainText; text: Model.formatCurrency(modelData.amount); color: modelData.type === "income" ? "#10B981" : "#EF4444"; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: projectionsComponent

    Item {
      width: parent.width
      height: tabContent.implicitHeight
      Column {
        id: tabContent
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader { text: "Financial Profile"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(4)

          NumberField {
            id: profileAge
            width: parent.width * 0.33
            label: "Age"
            value: profile.age
            from: 18
            to: 100
            stepSize: 1
            foreground: root.contentForeground
            accent: Color.accent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
          }

          NumberField {
            id: profileRetirementAge
            width: parent.width * 0.33
            label: "Retire"
            value: profile.retirementAge
            from: 40
            to: 90
            stepSize: 1
            foreground: root.contentForeground
            accent: Color.accent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
          }

          NumberField {
            id: profileIncome
            width: parent.width * 0.34
            label: "Income"
            value: profile.income
            from: 0
            to: 1000000
            stepSize: 1000
            foreground: root.contentForeground
            accent: Color.accent
            fontFamily: root.contentFontFamily
            fontSize: Style.font.body
          }
        }

        NumberField {
          id: profileHouseValue
          width: parent.width
          label: "House Value"
          value: profile.houseValue
          from: 0
          to: 10000000
          stepSize: 10000
          foreground: root.contentForeground
          accent: Color.accent
          fontFamily: root.contentFontFamily
          fontSize: Style.font.body
        }

        PanelSeparator { foreground: root.contentForeground }

        PanelSectionHeader { text: "Portfolio Allocation"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width / 3
            height: Style.space(60)

            Column {
              width: parent.width
              spacing: Style.space(2)

              Text { textFormat: Text.PlainText; text: "Cash: " + Math.round(portfolio.cash * 100) + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              PanelSlider {
                width: parent.width
                value: portfolio.cash
                minimum: 0
                maximum: 1
                step: 0.01
                integer: false
                trackColor: "#3B82F6"
                fillColor: "#3B82F6"
                knobColor: root.contentForeground
                onReleased: {
                  portfolio.cash = value
                  var total = portfolio.cash + portfolio.bonds + portfolio.stocks
                  if (Math.abs(total - 1.0) > 0.001)
                    portfolio.stocks = Math.max(0, portfolio.stocks + (1.0 - total))
                }
              }
            }
          }

          Item {
            width: parent.width / 3
            height: Style.space(60)

            Column {
              width: parent.width
              spacing: Style.space(2)

              Text { textFormat: Text.PlainText; text: "Bonds: " + Math.round(portfolio.bonds * 100) + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              PanelSlider {
                width: parent.width
                value: portfolio.bonds
                minimum: 0
                maximum: 1
                step: 0.01
                integer: false
                trackColor: "#8B5CF6"
                fillColor: "#8B5CF6"
                knobColor: root.contentForeground
                onReleased: {
                  portfolio.bonds = value
                  var total = portfolio.cash + portfolio.bonds + portfolio.stocks
                  if (Math.abs(total - 1.0) > 0.001)
                    portfolio.stocks = Math.max(0, portfolio.stocks + (1.0 - total))
                }
              }
            }
          }

          Item {
            width: parent.width / 3
            height: Style.space(60)

            Column {
              width: parent.width
              spacing: Style.space(2)

              Text { textFormat: Text.PlainText; text: "Stocks: " + Math.round(portfolio.stocks * 100) + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              PanelSlider {
                width: parent.width
                value: portfolio.stocks
                minimum: 0
                maximum: 1
                step: 0.01
                integer: false
                trackColor: "#10B981"
                fillColor: "#10B981"
                knobColor: root.contentForeground
                onReleased: {
                  portfolio.stocks = value
                  var total = portfolio.cash + portfolio.bonds + portfolio.stocks
                  if (Math.abs(total - 1.0) > 0.001)
                    portfolio.stocks = Math.max(0, portfolio.stocks + (1.0 - total))
                }
              }
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        Button {
          text: "Run Simulation"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          enabled: !simulationRunning
          onClicked: root.runSimulation()
        }

        Text {
          width: parent.width
          visible: projectionError !== ""
          textFormat: Text.PlainText
          text: projectionError
          color: "#EF4444"
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WrapAnywhere
        }

        Item {
          width: parent.width
          height: projectionResult.probabilityOfSuccess > 0 ? Style.space(80) : 0
          visible: projectionResult.probabilityOfSuccess > 0

          Column {
            width: parent.width
            spacing: Style.space(4)

            Text { textFormat: Text.PlainText; text: "Simulation Results"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: parent.width / 3
                height: Style.space(40)
                BorderSurface {
                  anchors.fill: parent
                  color: Color.popups.background
                  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
                  radius: Style.cornerRadius
                  padding: Style.space(8)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text { textFormat: Text.PlainText; text: "Success Rate"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: Math.round(projectionResult.probabilityOfSuccess * 100) + "%"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.displayLarge; font.bold: true }
                  }
                }
              }

              Item {
                width: parent.width / 3
                height: Style.space(40)
                BorderSurface {
                  anchors.fill: parent
                  color: Color.popups.background
                  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
                  radius: Style.cornerRadius
                  padding: Style.space(8)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text { textFormat: Text.PlainText; text: "Median at Retirement"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: Model.formatCurrency(projectionResult.medianPortfolioAtRetirement || 0); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  }
                }
              }

              Item {
                width: parent.width / 3
                height: Style.space(40)
                BorderSurface {
                  anchors.fill: parent
                  color: Color.popups.background
                  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
                  radius: Style.cornerRadius
                  padding: Style.space(8)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text { textFormat: Text.PlainText; text: "Worst Case"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: Model.formatCurrency(projectionResult.worstCase || 0); color: "#EF4444"; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: parent.width / 2
                height: Style.space(40)
                BorderSurface {
                  anchors.fill: parent
                  color: Color.popups.background
                  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
                  radius: Style.cornerRadius
                  padding: Style.space(8)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text { textFormat: Text.PlainText; text: "Best Case"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: Model.formatCurrency(projectionResult.bestCase || 0); color: "#10B981"; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  }
                }
              }

              Item {
                width: parent.width / 2
                height: Style.space(40)
                BorderSurface {
                  anchors.fill: parent
                  color: Color.popups.background
                  borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Style.normalBorderWidth)
                  radius: Style.cornerRadius
                  padding: Style.space(8)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(2)

                    Text { textFormat: Text.PlainText; text: "Returns: Cash 0.5% / Bonds 3.5% / Stocks 8%"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "Vol: Cash 1% / Bonds 5% / Stocks 15%"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: settingsComponent

    Item {
      width: parent.width
      height: tabContent.implicitHeight
      Column {
        id: tabContent
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader { text: "Categories"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Repeater {
          model: categories


          Item {
            width: parent.width
            height: Style.space(32)

            Row {
              width: parent.width
              spacing: Style.space(4)

              Text { textFormat: Text.PlainText; text: modelData.name; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Text { textFormat: Text.PlainText; text: Model.formatCurrency(modelData.budget_limit || 0); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }

              PanelActionButton {
                iconText: "+"
                tooltipText: "Increase budget"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                fontSize: Style.font.icon
                onClicked: DataStore.updateProfile("cat_budget_" + modelData.id, String((modelData.budget_limit || 0) + 100), function() {})
              }

              PanelActionButton {
                iconText: "-"
                tooltipText: "Decrease budget"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                fontSize: Style.font.icon
                onClicked: DataStore.updateProfile("cat_budget_" + modelData.id, String(Math.max(0, (modelData.budget_limit || 0) - 100)), function() {})
              }

              PanelActionButton {
                iconText: "x"
                tooltipText: "Remove category"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                fontSize: Style.font.icon
                visible: !modelData.is_predefined
              }
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(4)

          TextField {
            id: newCatName
            width: parent.width * 0.5
            placeholderText: "Category name"
            foreground: root.contentForeground
          }

          TextField {
            id: newCatBudget
            width: parent.width * 0.3
            placeholderText: "Budget"
            foreground: root.contentForeground
            inputMethodHints: Qt.ImhDigitsOnly
          }

          PanelActionButton {
            iconText: "+"
            tooltipText: "Add category"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: {
              var id = "custom_" + newCatName.text.toLowerCase().replace(/\s+/g, "_")
              DataStore.addCategory({
                id: id,
                name: newCatName.text,
                icon: "circle",
                type: "expense",
                budget_limit: parseFloat(newCatBudget.text) || 0,
                color: "#888888",
                is_predefined: false
              }, function() {
                newCatName.text = ""
                newCatBudget.text = ""
                refresh()
              })
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        PanelSectionHeader { text: "Accounts"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Repeater {
          id: accountList
          model: []


          Item {
            width: parent.width
            height: Style.space(32)

            Row {
              width: parent.width
              spacing: Style.space(4)

              Text { textFormat: Text.PlainText; text: modelData.name || ""; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Text { textFormat: Text.PlainText; text: Model.formatCurrency(modelData.balance || 0); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
            }
          }
        }

        PanelSeparator { foreground: root.contentForeground }

        PanelSectionHeader { text: "Display Preferences"; foreground: root.contentForeground; fontFamily: root.contentFontFamily }

        Row {
          width: parent.width
          spacing: Style.space(4)

          Text { textFormat: Text.PlainText; text: "Currency:"; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
          TextField {
            id: currencySymbol
            width: Style.space(60)
            text: "$"
            foreground: root.contentForeground
          }
        }
      }
    }
  }
}
