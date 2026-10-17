import QtQuick
import QtTest
import "../../qml" as UI
import "../../qml/AuthState.js" as AuthState

TestCase {
    id: test
    name: "AuthenticationConversation"
    when: windowShown
    visible: true
    width: 420; height: 180
    property var currentFlow: null
    property bool revealedOldText: false
    Component { id: flowComponent; MockAuthFlow {} }
    property var mockTheme: ({fontFamily: "sans-serif", iconFont: "sans-serif",
        text: "#ffffff", muted: "#aaaaaa", primary: "#e6b450", onPrimary: "#000000",
        hover: "#39bae6", onHover: "#000000", raised: "#202020", outline: "#777777", radiusMd: 6})
    UI.AuthConversation {
        id: auth
        flow: test.currentFlow
        input: response
    }
    UI.AuthResponseField {
        id: response
        x: 10; y: 10; width: 300; height: 44
        conversation: auth
        theme: test.mockTheme
    }
    UI.AuthSubmitButton {
        id: allow
        x: 10; y: 80; width: 200; height: 44
        text: "Allow"
        conversation: auth
        theme: test.mockTheme
        enabled: auth.ready
    }
    Connections {
        target: response
        function onEchoModeChanged() {
            if (response.echoMode === TextInput.Normal && response.text.length > 0)
                test.revealedOldText = true;
        }
    }
    function init() {
        currentFlow = createTemporaryObject(flowComponent, test);
        verify(currentFlow !== null);
        wait(0);
        revealedOldText = false;
        response.forceActiveFocus();
    }
    function cleanup() { currentFlow = null; wait(0); }
    function faceMatch() {
        currentFlow.inputPrompt = "Password:";
        currentFlow.responseVisible = false;
        currentFlow.isResponseRequired = true;
        currentFlow.supplementaryMessage = AuthState.verifiedInfo;
        tryCompare(auth, "verified", true);
    }
    function test_heldEnterCannotConfirmLaterMatch() {
        currentFlow.supplementaryMessage = "Please look at the camera";
        keyPress(Qt.Key_Return);
        faceMatch();
        // Qt auto-repeat presses/releases are not a fresh physical keypress.
        auth.keyPressed(Qt.Key_Return, true);
        auth.keyReleased(Qt.Key_Return, true);
        keyRelease(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 1);
        compare(currentFlow.submittedResponses[0], "");
    }
    function test_returnOnlySubmitsOnRelease() {
        faceMatch();
        keyPress(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        keyRelease(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 1);
    }
    function test_keypadEnterAndSpaceUseSameGuard() {
        faceMatch();
        allow.forceActiveFocus();
        auth.keyPressed(Qt.Key_Space, true);
        auth.keyReleased(Qt.Key_Space, false);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Enter);
        compare(currentFlow.submittedResponses.length, 1);
    }
    function test_freshSpaceConfirmsFromAllow() {
        faceMatch();
        allow.forceActiveFocus();
        keyPress(Qt.Key_Space);
        compare(currentFlow.submittedResponses.length, 0);
        keyRelease(Qt.Key_Space);
        compare(currentFlow.submittedResponses[0], "");
    }
    function test_editingDraftDisarmsHeldKey() {
        response.text = "first synthetic response";
        keyPress(Qt.Key_Return);
        response.text = "second synthetic response";
        keyRelease(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "second synthetic response");
    }
    function test_newPromptInvalidatesProofAndHeldKey() {
        faceMatch();
        keyPress(Qt.Key_Return);
        currentFlow.inputPrompt = "One-time code:";
        wait(0);
        verify(!auth.verified);
        verify(auth.needsInput);
        response.text = "123456";
        keyRelease(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "123456");
    }
    function test_oldVerificationInfoCannotConfirmOtp() {
        currentFlow.inputPrompt = "One-time code:";
        currentFlow.supplementaryMessage = AuthState.verifiedInfo;
        wait(0);
        verify(!auth.verified);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_pendingProofCannotCrossChallengeChange() {
        currentFlow.supplementaryMessage = AuthState.verifiedInfo;
        currentFlow.inputPrompt = "One-time code:";
        wait(0);
        verify(!auth.verified);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_responseCycleCannotReuseProof() {
        faceMatch();
        currentFlow.isResponseRequired = false;
        currentFlow.isResponseRequired = true;
        wait(0);
        verify(!auth.verified);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_identityAndRequestChangesInvalidateProof() {
        faceMatch();
        currentFlow.selectedIdentity = {id: 2000, displayName: "Other account"};
        wait(0);
        verify(!auth.verified);
        // A replacement flow already containing the old message is not fresh evidence.
        currentFlow = createTemporaryObject(flowComponent, test,
            {supplementaryMessage: AuthState.verifiedInfo});
        wait(0);
        verify(!auth.verified);
    }
    function test_errorCancelAndCompletionDisarm() {
        faceMatch();
        currentFlow.supplementaryIsError = true;
        wait(0);
        verify(!auth.verified);
        currentFlow.isCancelled = true;
        response.text = "synthetic response";
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        currentFlow.isCancelled = false;
        currentFlow.isCompleted = true;
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_retryClearsProofAndDraft() {
        faceMatch();
        response.text = "synthetic response";
        currentFlow.authenticationFailed();
        wait(0);
        compare(response.text, "");
        verify(!auth.verified);
    }
    function test_echoChangeClearsBeforeUnmasking() {
        response.text = "SYNTHETIC-SECRET";
        currentFlow.responseVisible = true;
        compare(response.text, "");
        compare(response.echoMode, TextInput.Normal);
        verify(!revealedOldText);
        verify(!auth.canSelectPassword);
        verify(!auth.choosePassword());
    }
    function test_echoChangeInvalidatesVerification() {
        faceMatch();
        currentFlow.responseVisible = true;
        wait(0);
        verify(!auth.verified);
        verify(!auth.canSelectPassword);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_promptChangeClearsDraftWithoutEchoChange() {
        response.text = "SYNTHETIC-SECRET";
        currentFlow.inputPrompt = "Verification code:";
        compare(response.text, "");
        compare(response.echoMode, TextInput.Password);
    }
    function test_typedConfirmationCannotBecomePasswordEntry() {
        currentFlow.responseVisible = true;
        currentFlow.inputPrompt = AuthState.typedConfirmationPrompt;
        tryCompare(auth, "verified", true);
        verify(!auth.canSelectPassword);
        verify(!auth.choosePassword());
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "yes");
    }
    function test_passwordChoiceRemainsMaskedAndSubmitsDraft() {
        faceMatch();
        verify(auth.choosePassword());
        verify(!auth.verified);
        compare(response.echoMode, TextInput.Password);
        response.text = "SYNTHETIC-SECRET";
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "SYNTHETIC-SECRET");
        compare(response.text, "");
    }
    function test_passwordCanBeSelectedDuringScan() {
        currentFlow.supplementaryMessage = "Please look at the camera or enter password";
        verify(auth.cameraActive);
        verify(auth.canSelectPassword);
        verify(auth.choosePassword());
        verify(auth.needsInput);
        response.text = "SYNTHETIC-SECRET";
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "SYNTHETIC-SECRET");
        compare(response.text, "");
    }
    function test_faceMatchCannotEraseOrSubmitSelectedPassword() {
        currentFlow.supplementaryMessage = "Please look at the camera or enter password";
        verify(auth.choosePassword());
        response.text = "SYNTHETIC-SECRET";
        currentFlow.supplementaryMessage = AuthState.verifiedInfo;
        wait(0);
        verify(!auth.verified);
        verify(auth.needsInput);
        compare(response.text, "SYNTHETIC-SECRET");
        compare(response.echoMode, TextInput.Password);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "SYNTHETIC-SECRET");
    }
    function test_scanFailureDoesNotEraseSelectedPassword() {
        currentFlow.supplementaryMessage = "Please look at the camera or enter password";
        verify(auth.choosePassword());
        response.text = "SYNTHETIC-SECRET";
        currentFlow.supplementaryMessage = "Face not recognized. Enter your password.";
        wait(0);
        compare(response.text, "SYNTHETIC-SECRET");
        verify(auth.choosePassword());
        compare(response.text, "SYNTHETIC-SECRET");
    }
    function test_passwordModeStillClearsOnActualChallengeBoundary() {
        verify(auth.choosePassword());
        response.text = "SYNTHETIC-SECRET";
        currentFlow.inputPrompt = "Verification code:";
        compare(response.text, "");
        verify(!auth.forcePassword);
    }
    function test_genericEchoOnChallengeDoesNotReuseSecret() {
        response.text = "SYNTHETIC-SECRET";
        currentFlow.inputPrompt = "One-time code:";
        currentFlow.responseVisible = true;
        compare(response.text, "");
        verify(!revealedOldText);
        verify(!auth.passwordChallenge);
        response.text = "123456";
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses[0], "123456");
    }
    function test_freshMouseClickConfirms() {
        faceMatch();
        mouseClick(allow);
        compare(currentFlow.submittedResponses.length, 1);
        compare(currentFlow.submittedResponses[0], "");
    }
    function test_mousePressCannotCrossChallengeChange() {
        faceMatch();
        mousePress(allow);
        currentFlow.inputPrompt = "Verification code:";
        mouseRelease(allow);
        compare(currentFlow.submittedResponses.length, 0);
    }
    function test_focusLossDisarmsKey() {
        faceMatch();
        keyPress(Qt.Key_Return);
        allow.forceActiveFocus();
        keyRelease(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 0);
        keyClick(Qt.Key_Return);
        compare(currentFlow.submittedResponses.length, 1);
    }
}
