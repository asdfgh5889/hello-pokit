pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import "HelloMotion.js" as Motion

// Themeable vector reconstruction traced from the Windows 11 reference recording.
// This contains no extracted Windows runtime or original portable animation asset.
Item {
    id: face
    property bool scanning: false
    property bool verified: false
    property color ink: "#0078d4"
    property real playbackRate: 1.25
    property real playhead: Motion.loopStart
    // Optional fixed time for visual review; the authentication UI leaves this at -1.
    property real sampleTime: -1
    readonly property real effectiveTime: sampleTime >= 0 ? sampleTime : playhead
    readonly property real tuxProgress: Math.max(0, Math.min(1, (effectiveTime - 5500) / 500))
    readonly property real tuxBlend: tuxProgress * tuxProgress * (3 - 2 * tuxProgress)
    readonly property int frameIndex: Math.max(0, Math.min(Math.round(Motion.successEnd / Motion.frameDuration),
        Math.round(effectiveTime / Motion.frameDuration)))
    readonly property var parts: Motion.sample(effectiveTime)
    implicitWidth: 100
    implicitHeight: 100

    function syncPlayback() {
        if (verified && visible) {
            scanAnimation.stop();
            if (!successAnimation.running) successAnimation.restart();
        } else if (scanning && visible) {
            successAnimation.stop();
            if (!scanAnimation.running) scanAnimation.restart();
        } else {
            scanAnimation.stop();
            successAnimation.stop();
            playhead = Motion.loopStart;
        }
    }
    onScanningChanged: syncPlayback()
    onVerifiedChanged: syncPlayback()
    onVisibleChanged: syncPlayback()
    Component.onCompleted: syncPlayback()

    SequentialAnimation {
        id: scanAnimation
        NumberAnimation { target: face; property: "playhead"; from: 0; to: Motion.loopStart; duration: Motion.loopStart / face.playbackRate }
        SequentialAnimation {
            loops: Animation.Infinite
            NumberAnimation {
                target: face; property: "playhead"
                from: Motion.loopStart; to: Motion.loopEnd
                duration: (Motion.loopEnd - Motion.loopStart) / face.playbackRate
            }
        }
    }
    NumberAnimation {
        id: successAnimation
        target: face; property: "playhead"
        from: Motion.successStart; to: Motion.successEnd
        duration: (Motion.successEnd - Motion.successStart) / face.playbackRate
    }
    Item {
        opacity: 1 - face.tuxBlend
        visible: face.tuxBlend < 1
        width: 100; height: 100
        scale: Math.min(face.width, face.height) / 100 * (1 - 0.3 * face.tuxBlend)
        x: (face.width - width * scale) / 2
        y: (face.height - height * scale) / 2
        transformOrigin: Item.TopLeft
        Repeater {
            model: 7
            Shape {
                id: silhouette
                required property int index
                readonly property var part: index < face.parts.length ? face.parts[index] : null
                width: 100; height: 100
                visible: part !== null
                opacity: part ? part[0] : 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillColor: face.ink
                    fillRule: ShapePath.WindingFill
                    PathSvg { path: silhouette.part ? silhouette.part[1] : "" }
                }
            }
        }
    }
    LinuxMark {
        anchors.fill: parent
        ink: face.ink
        opacity: face.tuxBlend
        visible: face.tuxBlend > 0
        scale: 0.9 + 0.1 * face.tuxBlend
    }
}
