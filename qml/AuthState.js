.pragma library

var typedConfirmationPrompt = "Face Verified. Type 'yes' to confirm.";
var verifiedInfo = "Face Verified. Press Enter to confirm.";

function passwordPrompt(prompt) {
    return prompt.trim() === "Password:";
}

// Only the supported Gaze prompt/echo combinations enable face confirmation.
function confirmation(prompt, info, responseRequired, isError, completed, responseVisible) {
    if (!responseRequired || isError || completed) return "";
    if (prompt.trim() === typedConfirmationPrompt && responseVisible === true) return "yes";
    if (passwordPrompt(prompt) && responseVisible === false && info.trim() === verifiedInfo) return "empty";
    return "";
}

function cameraActive(info) {
    return ["Please look at the camera", "Please look at the camera or enter password",
        "Password incorrect. Please look at the camera"].indexOf(info.trim()) >= 0;
}

function fallbackReason(info) {
    const reasons = {
        "Face not recognized. Enter your password.": "Face not recognized. Enter your password to continue.",
        "Face not detected. Enter your password.": "No face detected. Enter your password to continue.",
        "Too dark for face authentication. Enter your password.": "It’s too dark to recognize you. Use your password.",
        "Face authentication timed out. Enter your password.": "Face recognition timed out. Use your password.",
        "Face authentication unavailable. Enter your password.": "Face recognition is unavailable. Use your password."
    };
    const message = info.trim();
    return Object.prototype.hasOwnProperty.call(reasons, message) ? reasons[message] : "";
}
