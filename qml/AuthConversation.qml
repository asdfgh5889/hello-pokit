import QtQuick
import "AuthState.js" as AuthState

// Authentication state only. No Polkit registration, IPC, or simulated success.
Item {
    id: conversation
    required property var flow
    required property var input
    property bool submitting: false
    property bool forcePassword: false
    property string lastError: ""
    property int generation: 0
    property var proof: null
    property var pendingProof: null
    property var heldKey: null
    property var pointerPress: null
    // Updated only after clearing input, rather than binding the field to PAM echo.
    property bool responseEcho: false

    readonly property bool pending: !!flow && flow.isResponseRequired && !flow.isCompleted && !flow.isCancelled
    readonly property bool passwordChallenge: pending && !flow.responseVisible && AuthState.passwordPrompt(flow.inputPrompt)
    readonly property bool canSelectPassword: passwordChallenge && !submitting
    readonly property bool exposeResponse: responseEcho && !forcePassword
    readonly property string confirmKind: proof && proof.generation === generation && sameContext(proof.context, context()) ?
        AuthState.confirmation(flow.inputPrompt, flow.supplementaryMessage, pending,
            flow.supplementaryIsError, flow.isCompleted, flow.responseVisible) : ""
    readonly property bool verified: confirmKind !== "" && !forcePassword
    readonly property bool cameraActive: !!flow && AuthState.cameraActive(flow.supplementaryMessage)
    readonly property string fallbackReason: flow ? AuthState.fallbackReason(flow.supplementaryMessage) : ""
    readonly property bool needsInput: pending && !verified && (forcePassword || fallbackReason !== "" || !cameraActive)
    readonly property bool ready: pending && !submitting &&
        (verified || (needsInput && !!input && input.text.length > 0))

    function context() {
        return flow ? {flow: flow, identity: flow.selectedIdentity, prompt: flow.inputPrompt,
            echo: flow.responseVisible, required: flow.isResponseRequired,
            completed: flow.isCompleted, cancelled: !!flow.isCancelled} : null;
    }
    function sameContext(a, b) {
        return !!a && !!b && a.flow === b.flow && a.identity === b.identity &&
            a.prompt === b.prompt && a.echo === b.echo && a.required === b.required &&
            a.completed === b.completed && a.cancelled === b.cancelled;
    }
    function disarm() { heldKey = null; pointerPress = null; }
    function clearInput() { if (input) input.clear(); disarm(); }
    function invalidate() { generation += 1; proof = null; disarm(); }
    function boundary() {
        invalidate();
        clearInput();
        if (pendingProof && !sameContext(pendingProof.context, context())) pendingProof = null;
        responseEcho = !!flow && flow.responseVisible;
        if (!passwordChallenge) forcePassword = false;
        Qt.callLater(commitProof);
    }
    function resetRequest() {
        pendingProof = null;
        boundary();
        forcePassword = false;
        submitting = false;
        lastError = "";
    }
    function observeProof() {
        const kind = flow ? AuthState.confirmation(flow.inputPrompt, flow.supplementaryMessage,
            pending, flow.supplementaryIsError, flow.isCompleted, flow.responseVisible) : "";
        pendingProof = kind !== "" ? {context: context(), kind: kind} : null;
        Qt.callLater(commitProof);
    }
    function commitProof() {
        // Quickshell groups prompt/echo/response-required notifications. Coalesce only
        // a newly observed token in that same coherent context; never re-read stale info.
        const candidate = pendingProof;
        pendingProof = null;
        if (!candidate || !sameContext(candidate.context, context()) || !pending) return;
        const kind = AuthState.confirmation(flow.inputPrompt, flow.supplementaryMessage,
            pending, flow.supplementaryIsError, flow.isCompleted, flow.responseVisible);
        if (kind !== candidate.kind) return;
        clearInput();
        proof = {context: candidate.context, generation: generation};
    }
    function choosePassword() {
        if (!canSelectPassword) return false;
        clearInput();
        forcePassword = true;
        return true;
    }
    function chooseFace() {
        clearInput();
        forcePassword = false;
    }
    function snapshot() {
        return {context: context(), generation: generation, kind: verified ? confirmKind : "response",
            password: forcePassword};
    }
    function matches(snapshot) {
        return !!snapshot && ready && snapshot.generation === generation &&
            sameContext(snapshot.context, context()) && snapshot.password === forcePassword &&
            snapshot.kind === (verified ? confirmKind : "response");
    }
    function keyPressed(key, repeat) {
        if (repeat) return;
        heldKey = ready ? {key: key, snapshot: snapshot()} : null;
    }
    function keyReleased(key, repeat) {
        if (repeat) return;
        const press = heldKey;
        heldKey = null;
        if (press && press.key === key) submitFor(press.snapshot);
    }
    function handleKey(event, pressed, spaceConfirms) {
        if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter &&
                !(spaceConfirms && event.key === Qt.Key_Space)) return;
        event.accepted = true;
        if (pressed) keyPressed(event.key, event.isAutoRepeat);
        else keyReleased(event.key, event.isAutoRepeat);
    }
    function beginPointer() { pointerPress = ready ? snapshot() : null; }
    function confirmPointer() {
        const press = pointerPress;
        pointerPress = null;
        submitFor(press);
    }
    function submitFor(press) {
        if (!matches(press)) return;
        const request = flow;
        const answer = verified ? (confirmKind === "yes" ? "yes" : "") : input.text;
        pendingProof = null;
        invalidate();
        submitting = true;
        clearInput();
        request.submit(answer);
    }
    function cancel() {
        pendingProof = null;
        invalidate();
        clearInput();
        if (flow) flow.cancelAuthenticationRequest();
    }

    onFlowChanged: resetRequest()
    onInputChanged: if (input) input.clear()
    onForcePasswordChanged: clearInput()
    onFallbackReasonChanged: if (fallbackReason !== "" && passwordChallenge) choosePassword()
    Connections {
        target: conversation.input
        function onTextChanged() { conversation.disarm(); }
    }
    Connections {
        target: conversation.flow
        function onInputPromptChanged() {
            conversation.boundary();
            // A typed confirmation is itself a new prompt, unlike an old info message.
            if (conversation.flow.inputPrompt.trim() === AuthState.typedConfirmationPrompt)
                conversation.observeProof();
        }
        function onResponseVisibleChanged() { conversation.boundary(); }
        function onIsResponseRequiredChanged() {
            conversation.boundary();
            if (conversation.pending) conversation.submitting = false;
        }
        function onSelectedIdentityChanged() { conversation.resetRequest(); }
        function onIsCompletedChanged() { conversation.boundary(); }
        function onIsCancelledChanged() { conversation.boundary(); }
        function onSupplementaryIsErrorChanged() {
            if (conversation.flow.supplementaryIsError) {
                conversation.pendingProof = null;
                conversation.boundary();
            }
        }
        function onSupplementaryMessageChanged() {
            conversation.invalidate();
            conversation.pendingProof = null;
            if (conversation.flow.supplementaryMessage.trim() === AuthState.verifiedInfo)
                conversation.observeProof();
        }
        function onAuthenticationFailed() {
            conversation.resetRequest();
            conversation.lastError = "Authentication failed. Please try again.";
            conversation.forcePassword = conversation.passwordChallenge;
        }
    }
}
