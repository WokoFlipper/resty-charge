import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Battery charge-limit widget for Huawei/Honor MateBooks (huawei-wmi).
// Bar icon shows the limit as "(N)"; click opens a vertical preset menu
// with remaining runtime / time-to-limit estimation.
// Backend: matebook-set-limit.sh writes the start/end pair to sysfs.
BarWidget {
  id: root
  moduleName: "resty.charge"

  readonly property color panelBg: "#3d434c"
  readonly property color panelBorder: "#646c78"
  readonly property color textMain: "#ffffff"
  readonly property color textMuted: "#ccd2da"
  readonly property color textActive: "#ffffff"
  readonly property color rowHover: "#4d545f"
  readonly property color sepColor: "#5b636e"
  // Active preset = neon green frame + halo; inactive = gray fill, white text
  readonly property color frameActive: "#00e676"
  readonly property color frameIdle: "#8b95a1"
  readonly property color rowIdleFill: "#4f555e"
  readonly property color rowActiveFill: "#41474f"
  readonly property int panelRadius: 12
  readonly property int rowRadius: 8

  // Script-ish font for the time inscription (fallback automatic)
  readonly property string scriptFont: "Liberation Serif"

  // Helper script location (must be on PATH of the shell or absolute)
  readonly property string helper: "$HOME/.local/bin/matebook-set-limit.sh"

  property int threshold: 70
  property int batteryPct: 0
  property string batStatus: ""
  property int batCur: 0    // µA (abs value used)
  property int batNow: 0    // µAh
  property int batFull: 1   // µAh
  property bool popupOpen: false

  readonly property int rowH: 30
  readonly property int rowGap: 6
  readonly property int headerH: 28
  readonly property int timeH: 32
  readonly property int menuW: 240
  readonly property int pad: 6
  // header + sep + time field + sep + 3 framed rows + gaps
  readonly property int menuH: headerH + 1 + timeH + 1 + 3 * rowH + 2 * rowGap + 2 * pad + 4

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!readProc.running) readProc.running = true
    if (!batProc.running) batProc.running = true
  }

  function presetPair(preset) {
    if (preset === 70) return [40, 70]
    if (preset === 95) return [70, 95]
    return [70, 90]
  }

  function headerText() {
    var thr = root.threshold
    var cap = root.batteryPct
    if (thr >= 100)
      return "⚡ Uncapped • Battery: " + cap + "%"
    return "⚡ Limit " + thr + "% • Battery: " + cap + "%"
  }

  // Level color for the time inscription: 0-20 red, 21-69 yellow, 70-100 green
  function levelColor() {
    var cap = root.batteryPct
    if (cap <= 20) return "#ff5252"
    if (cap <= 69) return "#ffd600"
    return "#00e676"
  }

  function presetLabel(preset) {
    if (preset === root.threshold)
      return "✓ " + preset + "%"
    return "  " + preset + "%"
  }

  function fmtDur(mins) {
    mins = Math.max(0, Math.round(mins))
    var h = Math.floor(mins / 60)
    var m = mins % 60
    if (h <= 0) return m + " min"
    return h + " h " + (m < 10 ? "0" + m : m) + " min"
  }

  // Remaining runtime on battery, or time left to reach the limit while charging
  function calcTime() {
    var cur = Math.abs(root.batCur)
    if (cur <= 0 || root.batFull <= 0) return "—"
    if (root.batStatus === "Charging") {
      var target = root.threshold / 100 * root.batFull
      var diff = target - root.batNow
      if (diff <= 0) return "Limit " + root.threshold + "% reached"
      return "To " + root.threshold + "% ≈ " + fmtDur(diff / cur * 60)
    }
    if (root.batStatus === "Discharging") {
      return "≈ " + fmtDur(root.batNow / cur * 60) + " left"
    }
    if (root.batStatus === "Full") return "Charged"
    return root.batStatus !== "" ? root.batStatus : "—"
  }
  property string timeInfo: root.calcTime()

  Process {
    id: readProc
    command: ["sh", "-c", "cat /sys/devices/platform/huawei-wmi/charge_control_thresholds 2>/dev/null | awk '{print $2}'"]
    stdout: SplitParser {
      onRead: function(line) {
        line = String(line).trim()
        if (line === "") {
          root.threshold = 70
          return
        }
        var v = parseInt(line)
        root.threshold = (isNaN(v) || v <= 0) ? 70 : v
      }
    }
  }

  Process {
    id: batProc
    command: ["sh", "-c", "echo $(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null) $(cat /sys/class/power_supply/BAT1/status 2>/dev/null) $(cat /sys/class/power_supply/BAT1/current_now 2>/dev/null) $(cat /sys/class/power_supply/BAT1/charge_now 2>/dev/null) $(cat /sys/class/power_supply/BAT1/charge_full 2>/dev/null)"]
    stdout: SplitParser {
      onRead: function(line) {
        var parts = String(line).trim().split(/\s+/)
        if (parts.length < 5 || parts[0] === "") return
        root.batteryPct = parseInt(parts[0])
        root.batStatus = parts[1]
        root.batCur = parseInt(parts[2])
        root.batNow = parseInt(parts[3])
        root.batFull = parseInt(parts[4])
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Symbolic bar icon showing the limit
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "(" + root.threshold + ")"
    tooltipText: "Charge limit: " + root.threshold + "% — click to change"
    onPressed: function(buttonPressed) {
      if (buttonPressed === Qt.LeftButton || buttonPressed === Qt.RightButton) {
        root.popupOpen = !root.popupOpen
        if (root.popupOpen) {
          root.refresh()
          autoHideTimer.start()
        } else {
          autoHideTimer.stop()
        }
      }
    }
  }

  PopupWindow {
    id: popup
    visible: root.popupOpen
    color: "transparent"
    implicitWidth: root.menuW
    implicitHeight: root.menuH

    anchor {
      id: popupAnchor
      window: button.QsWindow ? button.QsWindow.window : null
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var win = popupAnchor.window
        if (!win) return
        var localX = button.width / 2 - popup.implicitWidth / 2
        var localY = button.height + Style.gapsOut
        var pt = win.contentItem.mapFromItem(button, localX, localY)
        popupAnchor.rect.x = Math.max(Style.gapsOut, Math.min(Math.round(pt.x), win.width - popup.implicitWidth - Style.gapsOut))
        popupAnchor.rect.y = Math.round(pt.y)
      }
    }

    Rectangle {
      anchors.fill: parent
      color: root.panelBg
      radius: root.panelRadius
      border.color: Color.accent
      border.width: 2

      Column {
        id: menuCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 0

        // Header (disabled look)
        Item {
          width: parent.width
          height: root.headerH
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 8
            text: root.headerText()
            color: root.textMuted
            font.pixelSize: 12
            elide: Text.ElideRight
            width: parent.width - 16
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.sepColor }

        // Remaining runtime / time-to-limit field
        Rectangle {
          width: parent.width
          height: root.timeH
          color: "transparent"
          border.color: root.panelBorder
          border.width: 1
          radius: root.rowRadius

          Text {
            anchors.centerIn: parent
            text: root.timeInfo
            color: root.levelColor()
            font.pixelSize: 16
            font.family: root.scriptFont
            font.italic: true
          }
        }

        Rectangle { width: parent.width; height: 1; color: root.sepColor }

        Column {
          width: parent.width
          spacing: root.rowGap

          Repeater {
            model: [70, 90, 95]
            delegate: menuRow
          }
        }
      }
    }

    Timer {
      id: autoHideTimer
      interval: 15000
      repeat: false
      onTriggered: root.popupOpen = false
    }
  }

  Component {
    id: menuRow
    Rectangle {
      required property int modelData
      width: root.menuW - 2 * root.pad
      height: root.rowH
      color: "transparent"
      radius: root.rowRadius

      // Neon halo behind the active button
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: root.rowRadius + 3
        color: "transparent"
        border.color: root.frameActive
        border.width: 2
        opacity: 0.45
        visible: modelData === root.threshold
      }

      Rectangle {
        anchors.fill: parent
        radius: root.rowRadius
        color: rowMa.containsMouse ? root.rowHover : (modelData === root.threshold ? root.rowActiveFill : root.rowIdleFill)
        border.width: 1
        border.color: modelData === root.threshold ? root.frameActive : root.frameIdle
      }

      Text {
        anchors.centerIn: parent
        text: root.presetLabel(modelData)
        color: "#ffffff"
        font.pixelSize: 13
        font.bold: modelData === root.threshold
      }

      MouseArea {
        id: rowMa
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.setPreset(modelData)
      }
    }
  }

  function setPreset(preset) {
    root.threshold = preset
    root.popupOpen = false
    autoHideTimer.stop()
    var pair = root.presetPair(preset)
    writeProc.command = ["sh", "-c", root.helper + " " + pair[0] + " " + pair[1]]
    writeProc.running = true
  }

  Process {
    id: writeProc
    command: ["sh", "-c", "$HOME/.local/bin/matebook-set-limit.sh 70 90"]
    onExited: function(exitCode) {
      root.refresh()
    }
  }

  Component.onCompleted: root.refresh()
}
