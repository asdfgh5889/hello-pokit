import QtQuick

QtObject {
    property string message: "Synthetic authentication request"
    property string actionId: "org.example.security-test"
    property var identities: [selectedIdentity]
    property string inputPrompt: "Password:"
    property string supplementaryMessage: ""
    property bool isResponseRequired: true
    property bool supplementaryIsError: false
    property bool isCompleted: false
    property bool isCancelled: false
    property bool responseVisible: false
    property var selectedIdentity: ({id: 1000, displayName: "Test account"})
    property var submittedResponses: []
    signal authenticationFailed()
    function submit(value) {
        submittedResponses = submittedResponses.concat([value]);
        isResponseRequired = false;
        inputPrompt = "";
        responseVisible = false;
    }
    function cancelAuthenticationRequest() { isCancelled = true; }
}
