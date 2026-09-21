import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Battery charge-limit widget for Huawei/Honor laptops (huawei-wmi).
// Bar icon shows the limit as "(N)"; click opens a vertical preset menu
// with remaining runtime / time-to-limit estimation plus a sleep timer.
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
  // Sleep timer palette: warm amber text/controls, system-color frames
  readonly property color shutAmber: "#ffcf7d"
  readonly property color shutAmberDeep: "#e8a33d"
  readonly property int panelRadius: 12
  readonly property int rowRadius: 8

  // Script-ish font for the time inscription (fallback automatic)
  // Helper script location (must be on PATH of the shell or absolute)
  readonly property string helper: "$HOME/.local/bin/matebook-set-limit.sh"
  readonly property string scriptFont: "Liberation Serif"

  property int threshold: 70
  property int batteryPct: 0
  property string batStatus: ""
  property int batCur: 0    // µA (abs value used)
  property int batNow: 0    // µAh
  property int batFull: 1   // µAh
  property bool popupOpen: false

  // Sleep timer state (-1 = none)
  property int shutPickMins: 30
  property int shutLeftSecs: -1
  property int shutPendingMins: 0
  // Internal: set while parsing shutQueryProc output (timer alive + epoch line)
  property bool _shutTimerAlive: false

  readonly property int rowH: 30
  readonly property int rowGap: 6
  readonly property int headerH: 28
  readonly property int timeH: 32
  readonly property int menuW: 240
  readonly property int pad: 6
  // Shutdown block below the preset buttons
  readonly property int shutTitleH: 18
  readonly property int shutValH: 20
  readonly property int shutSliderH: 26
  readonly property int shutMarksH: 14
  readonly property int shutBtnH: 28
  readonly property int shutGap: 6
  readonly property int shutFramePad: 8
  readonly property int shutFrameTopPad: 4
  readonly property int shutBlockH: shutTitleH + 1 + shutValH + shutSliderH + shutMarksH + shutBtnH + 5 * shutGap
  readonly property int topBlockH: headerH + 1 + timeH
  // framed top block + sep + 3 framed rows + gaps + divider + framed shutdown block
  readonly property int menuH: topBlockH + shutFrameTopPad + shutFramePad + 1 + 3 * rowH + 2 * rowGap + 20 + shutBlockH + shutFrameTopPad + shutFramePad + 2 * pad + 4

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

  function fmtHMS(s) {
    s = Math.max(0, Math.round(s))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    var mm = (m < 10 ? "0" + m : m)
    var ss = (sec < 10 ? "0" + sec : sec)
    return h > 0 ? h + ":" + mm + ":" + ss : m + ":" + ss
  }

  function shutValText() {
    if (root.shutLeftSecs < 0) return "In " + root.shutPickMins + " min"
    return fmtHMS(root.shutLeftSecs) + " left"
  }

  // Countdown color: amber idle/running, red in the last 5 minutes
  function shutValColor() {
    if (root.shutLeftSecs < 0) return root.shutAmber
    if (root.shutLeftSecs <= 300) return "#ff5252"
    return root.shutAmber
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

        // Top info block (header + battery time), framed in system color
        Rectangle {
          width: parent.width
          height: root.topBlockH + root.shutFrameTopPad + root.shutFramePad
          color: "transparent"
          border.color: Color.accent
          border.width: 1
          radius: root.rowRadius

          Column {
            anchors.fill: parent
            anchors.leftMargin: root.shutFramePad
            anchors.rightMargin: root.shutFramePad
            anchors.topMargin: root.shutFrameTopPad
            anchors.bottomMargin: root.shutFramePad
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

        // 5mm gap between the charge-limit block and the sleep block
        Item { width: parent.width; height: 20 }

        // Shutdown timer block (below the limit buttons), framed in system color
        Rectangle {
          width: parent.width
          height: root.shutBlockH + root.shutFrameTopPad + root.shutFramePad
          color: "transparent"
          border.color: Color.accent
          border.width: 1
          radius: root.rowRadius

          Column {
            anchors.fill: parent
            anchors.leftMargin: root.shutFramePad
            anchors.rightMargin: root.shutFramePad
            anchors.topMargin: root.shutFrameTopPad
            anchors.bottomMargin: root.shutFramePad
            spacing: root.shutGap

          // Section title
          Item {
            width: parent.width
            height: root.shutTitleH
            Text {
              anchors.centerIn: parent
              text: "Sleep timer"
              color: root.textMain
              font.pixelSize: 14
              font.bold: true
              font.italic: true
            }
          }

          Rectangle { width: parent.width; height: 1; color: root.sepColor }

          // Picked value + live countdown in one line
          Item {
            width: parent.width
            height: root.shutValH
            Text {
              anchors.centerIn: parent
              text: root.shutValText()
              color: root.shutValColor()
              font.pixelSize: 13
              font.bold: root.shutLeftSecs >= 0
              font.italic: true
            }
          }

          // Slider 0..90 step 15 (max 90 min)
          Slider {
            id: shutSlider
            width: parent.width
            height: root.shutSliderH
            from: 0
            to: 90
            stepSize: 15
            value: root.shutPickMins
            snapMode: Slider.SnapAlways
            onPressedChanged: if (pressed) autoHideTimer.restart()
            onValueChanged: root.shutPickMins = Math.round(value)

            background: Rectangle {
              x: shutSlider.leftPadding
              y: shutSlider.topPadding + shutSlider.availableHeight / 2 - height / 2
              width: shutSlider.availableWidth
              height: 4
              radius: 2
              color: root.panelBorder
            }

            handle: Rectangle {
              x: shutSlider.leftPadding + shutSlider.visualPosition * (shutSlider.availableWidth - width)
              y: shutSlider.topPadding + shutSlider.availableHeight / 2 - height / 2
              implicitWidth: 18
              implicitHeight: 18
              radius: 9
              color: root.shutAmberDeep
              border.color: "#ffffff"
              border.width: 1
            }
          }

          // Scale: digits at 0/30/60/90, plain ticks at 15/45/75,
          // each centered on its true slider position
          Item {
            width: parent.width
            height: root.shutMarksH
            Repeater {
              model: [0, 15, 30, 45, 60, 75, 90]
              delegate: Item {
                required property int modelData
                x: 9 + (modelData / 90) * (parent.width - 18)
                width: 0
                height: root.shutMarksH
                Text {
                  visible: modelData % 30 === 0
                  anchors.centerIn: parent
                  text: modelData
                  color: root.textMuted
                  font.pixelSize: 10
                  font.italic: true
                }
                Rectangle {
                  visible: modelData % 30 !== 0
                  anchors.centerIn: parent
                  width: 2
                  height: 6
                  color: root.textMuted
                }
              }
            }
          }

          // Set / Cancel buttons
          Row {
            width: parent.width
            spacing: root.shutGap

            Rectangle {
              width: (parent.width - root.shutGap) / 2
              height: root.shutBtnH
              radius: root.rowRadius
              color: setMa.containsMouse ? root.rowHover : root.rowActiveFill
              border.color: root.shutAmberDeep
              border.width: 1

              Text {
                anchors.centerIn: parent
                text: "Set"
                color: "#ffffff"
                font.pixelSize: 13
                font.bold: true
                font.italic: true
              }

              MouseArea {
                id: setMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  autoHideTimer.restart()
                  var mins = root.shutPickMins
                  if (mins < 15) return
                  root.shutPendingMins = mins
                  shutSetProc.command = ["sh", "-c", "T=$(( $(date +%s%3N) + " + mins + "*60000 )); echo $T > ~/.cache/resty-charge-sleep-target; systemctl --user stop resty-sleep-timer.timer 2>/dev/null; systemd-run --user --unit=resty-sleep-timer --on-active=" + mins + "min --timer-property=AccuracySec=1s systemctl suspend"]
                  shutSetProc.running = true
                }
              }
            }

            Rectangle {
              width: (parent.width - root.shutGap) / 2
              height: root.shutBtnH
              radius: root.rowRadius
              color: "transparent"
              border.color: root.shutLeftSecs >= 0 ? "#ff5252" : root.panelBorder
              border.width: 1
              opacity: root.shutLeftSecs >= 0 ? 1.0 : 0.4

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: "#ffffff"
                font.pixelSize: 13
                font.italic: true
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.shutLeftSecs < 0) return
                  autoHideTimer.restart()
                  shutCancelProc.running = true
                }
              }
            }
          }
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

  // Sleep timer machinery — SUSPEND, not poweroff.
  //
  // Logic history (why it looks like this): v1.x scheduled `shutdown -h +N`
  // (full power off) while the menu labels already said "sleep timer". Labels
  // did not match actions, so the mechanism was replaced: "Set" now creates
  // a transient systemd user timer (resty-sleep-timer.timer) that runs
  // `systemctl suspend`, and the target epoch (ms) is saved to
  // ~/.cache/resty-charge-sleep-target. The widget countdown (shutTick) is
  // DISPLAY ONLY — the transient timer is the robust actor and survives
  // shell restarts. On load, shutQueryProc restores the display only if the
  // transient timer is still active AND the saved target is in the future (a
  // reboot wipes transient timers, so a stale state file alone never triggers
  // anything). At zero the widget also fires `systemctl suspend` directly as
  // a fallback.
  Timer {
    id: shutTick
    interval: 1000
    repeat: true
    running: root.shutLeftSecs >= 0
    onTriggered: {
      if (root.shutLeftSecs > 0) {
        root.shutLeftSecs = root.shutLeftSecs - 1
        // 2-minute warning: visual + click sound
        if (root.shutLeftSecs === 120) shutWarn2Proc.running = true
        // Visual warning one minute before sleep
        if (root.shutLeftSecs === 60) shutWarnProc.running = true
      } else {
        // NOTE: do not assign shutTick.running here — the
        // running: shutLeftSecs >= 0 binding stops it by itself,
        // and an imperative assignment would break that binding.
        root.shutLeftSecs = -1
        shutSuspendProc.running = true
      }
    }
  }

  Process {
    id: shutSetProc
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.shutLeftSecs = root.shutPendingMins * 60
      }
    }
  }

  Process {
    id: shutCancelProc
    command: ["sh", "-c", "systemctl --user stop resty-sleep-timer.timer 2>/dev/null; rm -f ~/.cache/resty-charge-sleep-target; true"]
    onExited: function(exitCode) {
      root.shutLeftSecs = -1
    }
  }

  Process {
    id: shutSuspendProc
    command: ["sh", "-c", "systemctl suspend"]
  }

  Process {
    id: shutWarnProc
    command: ["sh", "-c", "notify-send -u critical -a resty.charge 'Sleep in a minute' 'The computer will sleep in 60 seconds. Cancel in the widget menu.'"]
  }

  Process {
    id: shutWarn2Proc
    command: ["sh", "-c", "notify-send -u normal -a resty.charge 'Sleep in 2 minutes' 'The computer will sleep in 2 minutes. Cancel in the widget menu.'; paplay /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null || mpv --no-video --no-terminal --really-quiet /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga 2>/dev/null || true"]
  }

  Process {
    id: shutQueryProc
    command: ["sh", "-c", "systemctl --user is-active resty-sleep-timer.timer 2>/dev/null; cat ~/.cache/resty-charge-sleep-target 2>/dev/null"]
    stdout: SplitParser {
      onRead: function(line) {
        line = String(line).trim()
        if (line === "active") {
          root._shutTimerAlive = true
          return
        }
        var t = parseInt(line)
        if (!isNaN(t) && root._shutTimerAlive) {
          var diff = Math.round((t - Date.now()) / 1000)
          if (diff > 0) root.shutLeftSecs = diff
        }
      }
    }
  }

  Component.onCompleted: {
    root.refresh()
    shutQueryProc.running = true
  }
}
