pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit

ShellRoot {
    id: root
    readonly property bool preview: Quickshell.env("HELLO_POLKIT_PREVIEW") === "1"
    readonly property bool previewSuccess: Quickshell.env("HELLO_POLKIT_PREVIEW_SUCCESS") === "1"
    readonly property string captureDirectory: Quickshell.env("HELLO_POLKIT_CAPTURE_DIR") || ""
    property string previewState: Quickshell.env("HELLO_POLKIT_PREVIEW_STATE") || "scanning"
    property alias lastError: authConversation.lastError
    property alias submitting: authConversation.submitting
    property bool showDetails: false
    property alias forcePassword: authConversation.forcePassword
    property bool wasRegistered: false
    readonly property var agent: backend.item ? backend.item.agent : null
    readonly property var flow: agent ? agent.flow : null
    readonly property string confirmKind: preview ? (previewState === "verified" ? "empty" : "") :
        authConversation.confirmKind
    readonly property bool verified: confirmKind !== "" && !forcePassword
    readonly property bool cameraActive: authConversation.cameraActive
    readonly property string fallbackReason: preview ? (previewState === "fallback" ? "Face not recognized. Enter your password to continue." : "") :
        authConversation.fallbackReason
    onNeedsInputChanged: if (needsInput) Qt.callLater(function() {
        if (root.needsInput) response.forceActiveFocus();
    })
    onVerifiedChanged: if (verified) Qt.callLater(function() {
        if (root.verified) allow.forceActiveFocus();
    })
    readonly property bool needsInput: preview ? ["password", "fallback"].indexOf(previewState) >= 0 :
        authConversation.needsInput
    readonly property bool passwordResponse: preview || authConversation.passwordChallenge
    readonly property bool scanning: preview ? previewState === "scanning" :
        !!flow && !flow.isCompleted && !flow.isCancelled && !verified && !needsInput && !submitting
    readonly property string requestMessage: preview ? "Authentication is required to install software." : flow ? flow.message : ""
    readonly property string actionId: preview ? "org.freedesktop.policykit.exec" : flow ? flow.actionId : ""
    // Preserve the supplied message; it may already contain an abbreviated command.
    readonly property string detailsText: "Request\n" + requestMessage + "\n\nAction\n" + actionId
    onShowDetailsChanged: if (preview) snapshotTimer.restart()

    // Demonstration only: never instantiated as a live authentication response.
    Timer {
        interval: root.previewSuccess ? 4600 / faceVisual.playbackRate : 4500
        running: root.preview && root.previewState === "scanning" && !methodMenu.visible
        onTriggered: root.previewState = root.previewSuccess ? "verified" : "fallback"
    }
    Timer {
        id: snapshotTimer
        interval: root.previewState === "verified" ? 1750 : 700
        running: root.preview && root.captureDirectory !== ""
        onTriggered: if (root.preview && root.captureDirectory !== "") (methodMenu.visible ? methodMenu.contentItem : card).grabToImage(function(result) {
            result.saveToFile(root.captureDirectory + "/preview-" + (methodMenu.visible ? "options" : root.showDetails ? "details" : root.previewState) + ".png");
        });
    }
    onPreviewStateChanged: if (preview) snapshotTimer.restart()
    IpcHandler {
        target: "helloPolkitPreview"
        function setState(value: string): void {
            if (root.preview && ["scanning", "verified", "password", "fallback"].indexOf(value) >= 0) {
                root.forcePassword = false;
                root.previewState = value;
                root.showDetails = false;
                methodMenu.close();
            } else if (root.preview && value === "details") {
                methodMenu.close();
                root.showDetails = true;
                snapshotTimer.restart();
            } else if (root.preview && value === "options") {
                methodMenu.open();
                snapshotTimer.restart();
            }
        }
    }
    IpcHandler {
        target: "helloPolkit"
        function status(): string {
            return JSON.stringify({preview: root.preview, registered: !!root.agent && root.agent.isRegistered,
                active: !!root.flow, action: root.actionId, verified: root.verified,
                password: root.needsInput, scanning: root.scanning, submitting: root.submitting,
                responseRequired: !!root.flow && root.flow.isResponseRequired,
                fontFamily: paletteTheme.fontFamily, cornerRadiusScale: paletteTheme.cornerRadiusScale,
                cardRadius: card.radius, animationFrame: faceVisual.frameIndex});
        }
    }
    Timer {
        interval: 5000
        running: !root.preview
        onTriggered: if (!root.agent || !root.agent.isRegistered) {
            console.error("Polkit registration failed; exiting to start MATE fallback");
            Qt.exit(1);
        }
    }
    Loader {
        id: backend
        active: !root.preview
        sourceComponent: Item {
            property alias agent: polkit
            PolkitAgent {
                id: polkit
                path: "/org/local/HelloPolkit"
                onAuthenticationRequestStarted: {
                    root.showDetails = false;
                    methodMenu.close();
                }
            }
        }
    }
    Connections {
        target: root.agent
        function onIsRegisteredChanged() {
            if (root.agent && root.agent.isRegistered) root.wasRegistered = true;
            else if (root.wasRegistered) {
                console.error("Polkit registration was lost; exiting to start MATE fallback");
                Qt.exit(1);
            }
        }
    }
    AuthConversation {
        id: authConversation
        flow: root.flow
        input: response
    }
    onFlowChanged: {
        showDetails = false;
        methodMenu.close();
    }
    function cancel() {
        if (preview) Qt.quit();
        else authConversation.cancel();
    }

    Theme { id: paletteTheme }

    PanelWindow {
        id: window
        visible: root.preview || !!root.flow
        implicitWidth: 492
        implicitHeight: Math.max(590, contents.implicitHeight + 2)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "hello-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible && !root.preview ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            id: card
            anchors.fill: parent
            radius: paletteTheme.radiusXl
            color: paletteTheme.surface
            border.color: paletteTheme.outline
            border.width: 1
            clip: true
            focus: true
            Keys.onEscapePressed: root.cancel()
            Keys.onPressed: function(event) { authConversation.handleKey(event, true, false); }
            Keys.onReleased: function(event) { authConversation.handleKey(event, false, false); }

            Popup {
                id: methodMenu
                parent: card
                x: (card.width - width) / 2
                y: Math.min(optionsButton.mapToItem(card, 0, optionsButton.height).y + 6, card.height - height - 20)
                width: 338
                padding: 8
                modal: true
                focus: !root.preview
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle { color: paletteTheme.raised; radius: paletteTheme.radiusLg; border.color: paletteTheme.outline; border.width: 1 }
                contentItem: ColumnLayout {
                    spacing: 6
                    Text { font.family: paletteTheme.fontFamily; text: "Sign-in options"; color: paletteTheme.muted; font.pixelSize: 12; Layout.margins: 8 }
                    AuthButton {
                        text: "Face recognition"
                        glyph: "\uea9b"
                        theme: paletteTheme
                        selected: !root.needsInput
                        Layout.fillWidth: true
                        enabled: !root.submitting && (root.preview || root.cameraActive || root.confirmKind !== "")
                        onClicked: {
                            if (root.preview) root.previewState = "scanning";
                            authConversation.chooseFace();
                            methodMenu.close();
                            if (root.verified) allow.forceActiveFocus();
                        }
                    }
                    AuthButton {
                        text: "Password"
                        glyph: "\ueac7"
                        theme: paletteTheme
                        selected: root.needsInput
                        Layout.fillWidth: true
                        enabled: !root.submitting && (root.preview || authConversation.canSelectPassword)
                        onClicked: {
                            if (root.preview) root.previewState = "password";
                            if (!root.preview && !authConversation.choosePassword()) return;
                            methodMenu.close();
                            response.forceActiveFocus();
                        }
                    }
                }
            }

            ColumnLayout {
                id: contents
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: 18
                    spacing: 10
                    Text { text: "\ued58"; color: paletteTheme.primary; font.family: paletteTheme.iconFont; font.pixelSize: 23 }
                    Text { font.family: paletteTheme.fontFamily; text: root.preview ? "System authorization · Preview" : "System authorization"; color: paletteTheme.muted; font.pixelSize: 13; Layout.fillWidth: true }
                    AuthButton { theme: paletteTheme; glyph: "\ueb55"; quiet: true; implicitWidth: 32; implicitHeight: 32; padding: 4; onClicked: root.cancel(); Accessible.name: "Cancel authorization" }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    spacing: 12
                    Text { font.family: paletteTheme.fontFamily;
                        Layout.fillWidth: true
                        text: "Allow this request?"
                        color: paletteTheme.text
                        font.pixelSize: 23
                        font.weight: Font.DemiBold
                    }
                    Text { font.family: paletteTheme.fontFamily;
                        Layout.fillWidth: true
                        text: root.requestMessage
                        textFormat: Text.PlainText
                        color: paletteTheme.text
                        font.pixelSize: 14
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        Text { text: "\ueb4d"; font.family: paletteTheme.iconFont; font.pixelSize: 16; color: paletteTheme.muted }
                        Text { font.family: paletteTheme.fontFamily;
                            Layout.fillWidth: true
                            text: root.preview ? (Quickshell.env("USER") || "Your account") : root.flow && root.flow.selectedIdentity ? root.flow.selectedIdentity.displayName : ""
                            textFormat: Text.PlainText
                            color: paletteTheme.muted
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                        AuthButton {
                            text: root.showDetails ? "Less" : "Details"
                            theme: paletteTheme
                            glyph: "\ueac5"
                            quiet: true
                            implicitHeight: 30
                            padding: 4
                            onClicked: root.showDetails = !root.showDetails
                        }
                    }
                    ComboBox { font.family: paletteTheme.fontFamily;
                        visible: !!root.flow && root.flow.identities.length > 1
                        Layout.fillWidth: true
                        model: root.flow ? root.flow.identities : []
                        textRole: "displayName"
                        palette.button: paletteTheme.raised
                        palette.buttonText: paletteTheme.text
                        palette.highlight: paletteTheme.primary
                        palette.highlightedText: paletteTheme.onPrimary
                        background: Rectangle {
                            color: paletteTheme.raised
                            radius: paletteTheme.radiusMd
                            border.color: paletteTheme.outline
                            border.width: 1
                        }
                        onActivated: function(index) { authConversation.resetRequest(); root.flow.selectedIdentity = root.flow.identities[index]; }
                    }
                    ScrollView {
                        id: requestDetailView
                        visible: root.showDetails
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(200, requestDetailText.implicitHeight)
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        TextArea {
                            id: requestDetailText
                            width: requestDetailView.availableWidth
                            text: root.detailsText
                            textFormat: TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            color: paletteTheme.text
                            selectionColor: paletteTheme.primary
                            selectedTextColor: paletteTheme.onPrimary
                            font.family: paletteTheme.fontFamily
                            font.pixelSize: 12
                            padding: 12
                            background: Rectangle { color: paletteTheme.raised; radius: paletteTheme.radiusMd }
                            Keys.onReturnPressed: function(event) { event.accepted = true; }
                            Keys.onEnterPressed: function(event) { event.accepted = true; }
                            Accessible.name: "Full authorization request details"
                        }
                    }
                }
                Item { Layout.minimumHeight: 20; Layout.fillHeight: true }
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 100
                    HelloFace {
                        id: faceVisual
                        anchors.centerIn: parent
                        scanning: root.scanning
                        verified: root.verified
                        ink: root.verified ? paletteTheme.success : paletteTheme.primary
                        visible: !root.needsInput
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.needsInput
                        text: "\ueae2"
                        font.family: paletteTheme.iconFont
                        font.pixelSize: 58
                        color: paletteTheme.primary
                    }
                    Rectangle {
                        visible: root.verified
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        width: 28; height: 28; radius: 14
                        color: paletteTheme.surface
                        Text { anchors.centerIn: parent; text: "\uea67"; font.family: paletteTheme.iconFont; font.pixelSize: 25; color: paletteTheme.success }
                    }
                }
                Text { font.family: paletteTheme.fontFamily;
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.topMargin: 8
                    text: root.verified ? "Face verified" : root.needsInput ? (root.passwordResponse ? "Use your password" : "Authentication response") : root.submitting ? "Authenticating…" : "Looking for you…"
                    textFormat: Text.PlainText
                    color: root.verified ? paletteTheme.success : paletteTheme.text
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.pixelSize: 23
                    font.weight: Font.DemiBold
                }
                Text { font.family: paletteTheme.fontFamily;
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.topMargin: 8
                    text: root.verified ? "Confirm below or press Enter to continue." : root.needsInput ? (root.passwordResponse ? (root.fallbackReason || "Enter your account password to authorize.") : "Enter the requested response to continue.") : root.submitting ? "Checking your response…" : "Look at the camera. You’ll confirm before continuing."
                    color: paletteTheme.muted
                    textFormat: Text.PlainText
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                AuthResponseField {
                    id: response
                    conversation: authConversation
                    theme: paletteTheme
                    visible: root.needsInput
                    enabled: !root.submitting
                    Layout.fillWidth: true
                    Layout.leftMargin: 36
                    Layout.rightMargin: 36
                    Layout.topMargin: 18
                    Layout.preferredHeight: 44
                    placeholderText: root.preview ? "Password" : root.flow ? root.flow.inputPrompt.trim() : "Password"
                }
                Text { font.family: paletteTheme.fontFamily;
                    visible: root.lastError !== "" || (!!root.flow && root.flow.supplementaryIsError)
                    Layout.fillWidth: true
                    Layout.leftMargin: 28
                    Layout.rightMargin: 28
                    Layout.topMargin: 14
                    text: root.flow && root.flow.supplementaryIsError ? root.flow.supplementaryMessage : root.lastError
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    color: paletteTheme.error
                    font.pixelSize: 14
                }
                AuthButton {
                    id: optionsButton
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                    text: "Sign-in options"
                    glyph: "\uea5f"
                    theme: paletteTheme
                    quiet: true
                    enabled: !root.submitting
                    onClicked: methodMenu.visible ? methodMenu.close() : methodMenu.open()
                    Accessible.name: "Choose a sign-in method"
                    Accessible.role: Accessible.ButtonMenu
                }
                Item { Layout.minimumHeight: 28; Layout.fillHeight: true }
                Rectangle {
                    id: footer
                    Layout.fillWidth: true
                    implicitHeight: 90
                    color: paletteTheme.raised
                    bottomLeftRadius: Math.max(0, card.radius - contents.anchors.margins)
                    bottomRightRadius: Math.max(0, card.radius - contents.anchors.margins)
                    Rectangle { width: parent.width; height: 1; color: paletteTheme.outline; opacity: 0.35 }
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 12
                        AuthSubmitButton {
                            id: allow
                            conversation: authConversation
                            text: root.verified ? "Allow" : "Authenticate"
                            glyph: root.verified ? "\uea5e" : "\ueae2"
                            theme: paletteTheme
                            primary: true
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 40
                            enabled: !root.submitting && (root.verified || (root.needsInput && response.text.length > 0))
                        }
                        AuthButton {
                            text: "Cancel"
                            theme: paletteTheme
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 40
                            onClicked: root.cancel()
                        }
                    }
                }
            }
        }
    }
}
