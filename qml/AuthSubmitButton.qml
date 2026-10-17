import QtQuick

AuthButton {
    required property var conversation
    onPressed: conversation.beginPointer()
    onClicked: conversation.confirmPointer()
    onCanceled: conversation.disarm()
    onActiveFocusChanged: if (!activeFocus) conversation.disarm()
    Keys.onPressed: function(event) { conversation.handleKey(event, true, true); }
    Keys.onReleased: function(event) { conversation.handleKey(event, false, true); }
}
