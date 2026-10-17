pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Button {
    id: control
    required property var theme
    property string glyph: ""
    property bool primary: false
    property bool selected: false
    property bool quiet: false
    readonly property bool filled: primary || selected || down
    readonly property color foreground: hovered && enabled ? theme.onHover : filled ? theme.onPrimary : theme.text
    implicitHeight: 40
    implicitWidth: label.implicitWidth + (glyph !== "" ? 28 : 0) + 32
    padding: 12
    hoverEnabled: true
    opacity: enabled ? 1 : 0.45
    contentItem: Item {
      RowLayout {
        anchors.centerIn: parent
        spacing: 8
        Text { visible: control.glyph !== ""; text: control.glyph; font.family: control.theme.iconFont; font.pixelSize: 20; color: control.foreground }
        Text { id: label; text: control.text; font.family: control.theme.fontFamily; font.pixelSize: 14; font.weight: control.primary || control.selected ? Font.DemiBold : Font.Normal; color: control.foreground }
      }
    }
    background: Rectangle {
        radius: control.theme.radiusMd
        color: control.hovered && control.enabled ? control.theme.hover : control.filled ? control.theme.primary : control.quiet ? "transparent" : control.theme.raised
        border.width: control.activeFocus ? 2 : control.filled || control.quiet ? 0 : 1
        border.color: control.activeFocus ? control.theme.primary : control.theme.outline
        Behavior on color { ColorAnimation { duration: 100 } }
    }
}
