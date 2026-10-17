import QtQuick
import QtTest
import "../../qml/AuthState.js" as AuthState

TestCase {
    name: "FaceConfirmationSafety"
    function test_responseMustBeRequested() {
        compare(AuthState.confirmation("Password:", "Face Verified. Press Enter to confirm.", false, false, false), "");
    }
    function test_completedOrErrorCannotConfirm() {
        compare(AuthState.confirmation("Password:", "Face Verified. Press Enter to confirm.", true, false, true), "");
        compare(AuthState.confirmation("Password:", "Face Verified. Press Enter to confirm.", true, true, false), "");
    }
    function test_exactMessagesOnly() {
        compare(AuthState.confirmation("Password:", "Face Verified. Press Enter to confirm.", true, false, false), "empty");
        compare(AuthState.confirmation("Face Verified. Type 'yes' to confirm.", "", true, false, false), "yes");
        compare(AuthState.confirmation("Password:", "Face Verified.", true, false, false), "");
        compare(AuthState.confirmation("Password:", "Not Face Verified. Press Enter to confirm.", true, false, false), "");
        compare(AuthState.confirmation("Password:", "Please look at the camera", true, false, false), "");
        compare(AuthState.confirmation("One-time code:", "", true, false, false), "");
    }
    function test_cameraFailureFallsBackToPassword() {
        const failures = ["Face not recognized. Enter your password.",
            "Face not detected. Enter your password.",
            "Too dark for face authentication. Enter your password.",
            "Face authentication timed out. Enter your password.",
            "Face authentication unavailable. Enter your password."];
        for (let info of failures) {
            verify(AuthState.fallbackReason(info).length > 0);
            verify(!AuthState.cameraActive(info));
            compare(AuthState.confirmation("Password:", info, true, false, false), "");
        }
    }
    function test_scanningAndSuccessDoNotTriggerFallback() {
        verify(AuthState.cameraActive("Please look at the camera or enter password"));
        compare(AuthState.fallbackReason("Please look at the camera or enter password"), "");
        compare(AuthState.fallbackReason("Face Verified. Press Enter to confirm."), "");
        compare(AuthState.fallbackReason("toString"), "");
        compare(AuthState.fallbackReason("constructor"), "");
    }
}
