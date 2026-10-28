// Personal (fork GriffithFGC): translation bubble next to the cursor.
// Started by ~/.config/hypr/scripts/perso-translate.sh with the selected text
// and cursor position in TR_* env vars; perso-translate.py picks the direction
// (Japanese -> English, anything else -> Japanese) and adds the romaji reading.
// Exits on its own. Left click copies the translation, right click closes.
// Theme.qml is a symlink to ../Theme.qml (made by the script) so the bubble
// follows the 43PR palette like the notification popups.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string sourceText: Quickshell.env("TR_TEXT") || ""
    readonly property real cursorX: Number(Quickshell.env("TR_X") || 0)
    readonly property real cursorY: Number(Quickshell.env("TR_Y") || 0)
    readonly property string monitorName: Quickshell.env("TR_MON") || ""

    property string result: ""
    property string reading: ""        // romaji of the Japanese side
    property string src: ""
    property string dst: ""
    property string phase: sourceText ? "loading" : "empty"   // loading | done | error | empty
    property bool showing: false
    property bool copied: false

    function quit() { showing = false; quitTimer.start() }

    Component.onCompleted: showing = true

    Process {
        running: root.sourceText !== ""
        command: ["python3", "-I", Quickshell.env("HOME") + "/.config/hypr/scripts/perso-translate.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var r = JSON.parse(text)
                    if (r.error) throw r.error
                    root.src = r.src; root.dst = r.dst
                    root.result = r.text; root.reading = r.reading
                    root.phase = "done"
                } catch (e) {
                    root.phase = "error"
                }
            }
        }
    }

    // Reading time grows with the text; hovering the bubble keeps it open
    Timer {
        id: hideTimer
        running: root.phase !== "loading" && !area.containsMouse
        interval: root.phase === "done" ? Math.min(15000, 4000 + root.result.length * 60) : 2500
        onTriggered: root.quit()
    }
    Timer {
        running: root.phase === "loading"
        interval: 12000
        onTriggered: root.phase = "error"
    }
    Timer {
        id: quitTimer
        interval: 200
        onTriggered: Qt.quit()
    }

    component Reading: Text {
        width: Math.min(implicitWidth, 392)
        text: root.reading
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.italic: true
        color: Theme.textFaint
    }

    PanelWindow {
        id: win

        screen: {
            for (var i = 0; i < Quickshell.screens.length; i++)
                if (Quickshell.screens[i].name === root.monitorName) return Quickshell.screens[i]
            return Quickshell.screens[0]
        }

        // Below-right of the cursor, flipped above / to the left near the edges
        readonly property real px: Math.max(8, Math.min(root.cursorX + 14, (screen ? screen.width : 1920) - card.width - 8))
        readonly property real py: root.cursorY + 22 + card.height > (screen ? screen.height : 1080) - 8
                                   ? Math.max(8, root.cursorY - card.height - 14)
                                   : root.cursorY + 22

        anchors { top: true; left: true }
        margins { left: px; top: py }
        implicitWidth: card.width
        implicitHeight: card.height
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "perso-translate"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Rectangle {
            id: card
            width: Math.min(420, Math.max(160, col.implicitWidth + 28))
            height: col.implicitHeight + 24
            radius: 16
            color: Theme.bg
            opacity: root.showing ? 1 : 0
            scale: root.showing ? 1 : 0.92
            transformOrigin: Item.TopLeft
            Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

            Column {
                id: col
                x: 14; y: 12
                width: card.width - 28
                spacing: 6

                Text {
                    width: parent.width
                    text: (root.phase === "done" ? root.src + " → " + root.dst : "translate")
                          + (root.copied ? "  ·  copied" : "")
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    color: Theme.textFaint
                }
                Text {
                    visible: root.sourceText !== ""
                    width: Math.min(implicitWidth, 392)
                    text: root.sourceText
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.textDim
                }
                Reading { visible: root.dst === "en" && root.reading !== "" }
                Text {
                    width: Math.min(implicitWidth, 392)
                    text: root.phase === "done" ? root.result
                        : root.phase === "loading" ? "…"
                        : root.phase === "empty" ? "No text selected"
                        : "Translation failed"
                    wrapMode: Text.Wrap
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    font.bold: root.phase === "done"
                    color: root.phase === "error" ? Theme.danger : Theme.text
                }
                Reading { visible: root.dst === "ja" && root.reading !== "" }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton && root.phase === "done") {
                        Quickshell.execDetached(["wl-copy", root.result])
                        root.copied = true
                    } else {
                        root.quit()
                    }
                }
            }
        }
    }
}
