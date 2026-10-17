.pragma library

// Only exact Gaze confirmation messages enable the face confirmation action.
function confirmation(prompt, info, responseRequired, isError, completed) {
    if (!responseRequired || isError || completed) return "";
    if (prompt.trim() === "Face Verified. Type 'yes' to confirm.") return "yes";
    if (info.trim() === "Face Verified. Press Enter to confirm.") return "empty";
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
