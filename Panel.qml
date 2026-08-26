import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Open tasks from an Obsidian vault, read straight off the markdown.
//
// The vault is the only state this widget has. Nothing is cached, so a task
// added on a phone appears as soon as the next scan lands, and a task ticked
// here is a rewritten line on disk that sync carries back out. Every read and
// write goes through bin/omarchy-tasks; this file only decides what to show.
Panel {
  id: root
  moduleName: "avoby.tasks"
  ipcTarget: "avoby.tasks"

  readonly property string glyphBar: String.fromCodePoint(0xF0139)
  readonly property string glyphBox: String.fromCodePoint(0xF0135)

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string vaultPath: expand(String(setting("vaultPath", "~/Notes")))
  readonly property string inboxPath: vaultPath + "/" + String(setting("inboxFile", "Tasks/Inbox.md"))
  readonly property string countMode: String(setting("countMode", "all"))
  readonly property int refreshIntervalSec: Math.max(10, Number(setting("refreshIntervalSec", 60)))
  // Shipped beside the QML so the plugin stays one directory to install or remove.
  readonly property string helper: Qt.resolvedUrl("bin/omarchy-tasks").toString().replace("file://", "")

  property var tasks: []
  property bool everScanned: false
  property int cursor: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string today: isoDate(new Date())

  readonly property var openTasks: (tasks || []).filter(function (t) { return t.open })
  readonly property var dueTasks: openTasks.filter(function (t) { return t.due !== "" && t.due <= root.today })
  readonly property int badgeCount: countMode === "due" ? dueTasks.length : openTasks.length

  // Dated tasks first and in date order, because those are the ones with a
  // deadline attached; undated ones keep their priority order behind them.
  readonly property var rows: openTasks.slice().sort(function (a, b) {
    var ad = a.due === "" ? "9999-99-99" : a.due
    var bd = b.due === "" ? "9999-99-99" : b.due
    if (ad !== bd) return ad < bd ? -1 : 1
    if (a.priority !== b.priority) return a.priority - b.priority
    return a.label.localeCompare(b.label)
  })

  readonly property string summary: {
    if (!everScanned) return "Reading vault…"
    if (openTasks.length === 0) return "Nothing open"
    var line = openTasks.length + (openTasks.length === 1 ? " open task" : " open tasks")
    return dueTasks.length > 0 ? line + " · " + dueTasks.length + " due" : line
  }

  function expand(path) {
    return path.indexOf("~") === 0 ? root.home + path.substring(1) : path
  }

  function isoDate(d) {
    return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2)
  }

  // Relative wording only within a day either side; past that a bare date says
  // more than counting days out loud does.
  function dueLabel(due) {
    if (due === "") return ""
    if (due < root.today) return "overdue"
    if (due === root.today) return "today"
    var t = new Date()
    t.setDate(t.getDate() + 1)
    return due === isoDate(t) ? "tomorrow" : due
  }

  function refresh() {
    if (!scanProc.running) scanProc.running = true
  }

  function completeTask(task) {
    if (!task || editProc.running) return
    // The exact line, not its number: sync can rewrite the file between the
    // scan that drew this row and the click that ticks it, and the helper
    // would rather do nothing than tick whatever moved into that position.
    editProc.command = [root.helper, "complete", task.file, task.raw]
    editProc.running = true
  }

  function addTask(text) {
    if (editProc.running || String(text).trim() === "") return
    editProc.command = [root.helper, "add", root.inboxPath, String(text)]
    editProc.running = true
  }

  function moveCursor(delta) {
    if (rows.length === 0) return
    cursorActive = true
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + delta))
  }

  onOpenedChanged: {
    if (opened) {
      cursor = 0
      cursorActive = false
      refresh()
    }
  }

  onRowsChanged: if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)

  Process {
    id: scanProc
    command: [root.helper, "scan", root.vaultPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.tasks = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          console.warn("avoby.tasks: could not parse scan output", e)
          root.tasks = []
        }
        root.everScanned = true
      }
    }
  }

  // Every edit is followed by a rescan rather than a local mutation, so what
  // the popup shows is always what is actually on disk.
  Process {
    id: editProc
    onExited: root.refresh()
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyphBar
    dimmed: root.badgeCount === 0
    active: root.dueTasks.length > 0
    tooltipText: root.summary
    onPressed: function (code) {
      if (code === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: addField.activeFocus
      onMoveRequested: function (dx, dy) {
        if (dy !== 0) root.moveCursor(dy > 0 ? 1 : -1)
      }
      onActivateRequested: if (root.cursorActive) root.completeTask(root.rows[root.cursor])
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      // hjkl drive the cursor, so capture lives behind "a" rather than
      // swallowing every letter the moment the panel opens.
      onTextKey: function (t) {
        if (t === "a" || t === "A") addField.forceActiveFocus()
        else if (t === "r" || t === "R") root.refresh()
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: flick.width
          spacing: Style.space(8)

          // Hero: icon · title over status, laid out like the audio panel so
          // the two read as the same kind of popup.
          Item {
            id: hero
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.glyphBar
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              opacity: root.openTasks.length === 0 ? 0.5 : 1.0
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: "Tasks"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.summary.toUpperCase()
                color: Qt.darker(root.foreground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
              }
            }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          Repeater {
            model: root.rows

            Item {
              id: row
              required property var modelData
              required property int index

              width: column.width
              implicitHeight: Math.max(rowLabel.implicitHeight, Style.space(24))

              readonly property bool overdue: modelData.due !== "" && modelData.due < root.today
              readonly property bool hot: rowMouse.containsMouse || (root.cursorActive && root.cursor === index)

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -Style.space(6)
                anchors.rightMargin: -Style.space(6)
                radius: Style.cornerRadius
                color: row.hot ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08) : "transparent"
              }

              Text {
                id: box
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.glyphBox
                color: row.hot ? root.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }

              Text {
                id: rowLabel
                anchors.left: box.right
                anchors.leftMargin: Style.space(8)
                anchors.right: dueBadge.visible ? dueBadge.left : parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.label
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
              }

              Text {
                id: dueBadge
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.modelData.due !== ""
                text: root.dueLabel(row.modelData.due)
                color: row.overdue ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: { root.cursorActive = true; root.cursor = row.index }
                onClicked: root.completeTask(row.modelData)
              }
            }
          }

          Text {
            width: parent.width
            visible: root.everScanned && root.rows.length === 0
            text: "No open tasks in " + root.vaultPath.replace(root.home, "~")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          PanelSeparator { width: parent.width }

          TextField {
            id: addField
            width: parent.width
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            placeholderText: "Add a task…"
            onAccepted: {
              root.addTask(text)
              text = ""
            }
            Keys.onEscapePressed: {
              text = ""
              keyCatcher.forceActiveFocus()
            }
          }
        }
      }
    }
  }
}
