import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "DataStore.js" as DataStore

BarWidget {
  id: root
  moduleName: "omabudget"

  Component.onCompleted: console.log("BarWidget completed:", moduleName, "bar:", bar)
  onBarChanged: {
    console.log("BarWidget onBarChanged:", bar)
    injectPanel()
  }

  property var currentSummary: ({totalBudget: 0, totalSpent: 0, remaining: 0})
  property var cashFlow: ({totalIncome: 0, totalExpenses: 0})

  function refresh() {
    DataStore.getMonthlySummary(new Date().getFullYear(), new Date().getMonth() + 1, function(result) {
      if (result && result.status === "ok" && result.result) {
        currentSummary = result.result.budget
        cashFlow = result.result.cash_flow
        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
          root.bar.shell.updateEntryInline(root.moduleName, {})
      }
    })
    if (panelLoader.item && panelLoader.item.refresh) panelLoader.item.refresh()
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function togglePanel() {
    root.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("PanelLoader error:", errorString)
    }
  }

  Process {
    id: bridgeProcess
    command: ["/home/lgw/.config/omarchy/plugins/omabudget/bin/omabudget-bridge"]
    running: true
    stdinEnabled: true

    stdout: SplitParser {
      onRead: function(line) {
        try {
          var obj = JSON.parse(line)
          DataStore.handleResponse(obj)
        } catch(e) {}
      }
    }

    onStarted: {
      DataStore.setProcess(bridgeProcess)
    }
  }

  IpcHandler {
    target: "omabudget"

    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Budget"
    labelVisible: !root.vertical
    hasVisualContent: text !== ""
    interactive: true
    pressable: true
    horizontalMargin: 8.75
    verticalPadding: 8.75
    Component.onCompleted: console.log("WidgetButton bar:", bar, "pressable:", pressable, "interactive:", interactive)
    onBarChanged: console.log("WidgetButton onBarChanged:", bar)
  }

  Connections {
    target: button
    function onPressed(b) {
      console.log("Connections onPressed:", b)
      if (b === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }
}
