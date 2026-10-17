import QtQuick
import Quickshell.Io
Item {
    id: theme
    property var colors: ({"primary": "#E6B450", "on_primary": "#0B0E14", "secondary": "#AAD94C", "on_secondary": "#0B0E14", "tertiary": "#39BAE6", "surface": "#0B0E14", "on_surface": "#D1D1C7", "surface_variant": "#1E222A", "on_surface_variant": "#8E959E", "outline": "#565B66", "hover": "#39BAE6", "on_hover": "#0B0E14", "error": "#D95757"})
    readonly property color primary: colors.primary
    readonly property color onPrimary: colors.on_primary
    readonly property color success: colors.secondary
    readonly property color surface: colors.surface
    readonly property color text: colors.on_surface
    readonly property color raised: colors.surface_variant
    readonly property color muted: colors.on_surface_variant
    readonly property color outline: colors.outline
    readonly property color hover: colors.hover
    readonly property color onHover: colors.on_hover
    readonly property color error: colors.error
    readonly property string iconFont: icons.name
    property string fontFamily: "sans-serif"
    property real cornerRadiusScale: 1
    readonly property real radiusMd: 6 * cornerRadiusScale
    readonly property real radiusLg: 9 * cornerRadiusScale
    readonly property real radiusXl: 12 * cornerRadiusScale
    Process {
        id: styleSettings
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("style-settings.py").toString().replace("file://", ""))]
        running: true
        stdout: SplitParser {
            onRead: function(data) {
                try {
                    const next = JSON.parse(data);
                    if (typeof next.fontFamily === "string" && next.fontFamily.trim() !== "" &&
                        typeof next.cornerRadiusScale === "number" && isFinite(next.cornerRadiusScale)) {
                        theme.fontFamily = next.fontFamily;
                        theme.cornerRadiusScale = Math.max(0, Math.min(2, next.cornerRadiusScale));
                    }
                } catch (e) { console.warn("Keeping the last valid Noctalia font and radius settings"); }
            }
        }
        onExited: styleRetry.restart()
    }
    Timer { id: styleRetry; interval: 3000; onTriggered: styleSettings.running = true }
    FontLoader { id: icons; source: Qt.resolvedUrl("../assets/fonts/noctalia-tabler.ttf") }
    FileView {
        id: palette
        path: decodeURIComponent(Qt.resolvedUrl("palette.json").toString().replace("file://", ""))
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const next = JSON.parse(text());
                const keys = Object.keys(theme.colors);
                if (keys.every(function(k) { return /^#[0-9a-fA-F]{6}$/.test(next[k]); })) theme.colors = next;
            } catch (e) { console.warn("Keeping last valid Noctalia palette"); }
        }
    }
}
