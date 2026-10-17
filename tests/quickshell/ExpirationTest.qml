import QtQuick
import Quickshell
import "../../qml" as UI
import "../qml" as Mocks

// Real Quickshell clock integration, with no windows or Polkit registration.
ShellRoot {
    id: test
    property bool observedVerified: false
    function require(condition, message) {
        if (condition) return;
        console.error("FAIL: " + message);
        Qt.exit(1);
        throw new Error(message);
    }
    ElapsedTimer { id: clock }
    Item {
        Mocks.MockAuthFlow { id: mockFlow }
        QtObject {
            id: mockInput
            property string text: ""
            function clear() { text = ""; }
        }
        UI.AuthConversation {
            id: auth
            flow: mockFlow
            input: mockInput
            verificationClock: clock
        }
    }
    Component.onCompleted: mockFlow.supplementaryMessage = "Face Verified. Press Enter to confirm."
    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: {
            if (auth.verified) test.observedVerified = true;
            if (!auth.faceExpired) return;
            test.require(test.observedVerified, "fresh verification was not offered");
            test.require(clock.elapsedMs() >= 15000, "expired before the monotonic deadline");
            test.require(!auth.verified && !auth.canSelectFace, "expired face is still available");
            test.require(auth.forcePassword && auth.needsInput && !auth.ready, "password fallback is not empty");
            auth.keyPressed(Qt.Key_Return, false);
            auth.keyReleased(Qt.Key_Return, false);
            test.require(mockFlow.submittedResponses.length === 0, "empty confirmation submitted after expiry");
            mockInput.text = "SYNTHETIC-SECRET";
            auth.keyPressed(Qt.Key_Return, false);
            auth.keyReleased(Qt.Key_Return, false);
            test.require(mockFlow.submittedResponses[0] === "SYNTHETIC-SECRET", "password fallback did not submit");
            console.info("PASS: real Quickshell monotonic clock, 15-second expiry, and password handoff");
            Qt.quit();
        }
    }
    Timer {
        interval: 18000
        running: true
        onTriggered: test.require(false, "expiry integration watchdog elapsed")
    }
}
