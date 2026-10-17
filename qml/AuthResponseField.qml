import QtQuick
import QtQuick.Controls

TextField {
    id: field
    required property var conversation
    required property var theme
    font.family: theme.fontFamily
    color: theme.text
    placeholderTextColor: theme.muted
    selectionColor: theme.primary
    selectedTextColor: theme.onPrimary
    font.pixelSize: 15
    leftPadding: 14
    rightPadding: 14
    echoMode: conversation.exposeResponse ? TextInput.Normal : TextInput.Password
    passwordMaskDelay: 0
    selectByMouse: true
    Keys.onPressed: function(event) { conversation.handleKey(event, true, false); }
    Keys.onReleased: function(event) { conversation.handleKey(event, false, false); }
    onActiveFocusChanged: if (!activeFocus) conversation.disarm()
    background: Rectangle {
        radius: field.theme.radiusMd
        color: field.theme.raised
        border.width: field.activeFocus ? 2 : 1
        border.color: field.activeFocus ? field.theme.primary : field.theme.outline
    }
    Accessible.name: "Authentication response"
}
