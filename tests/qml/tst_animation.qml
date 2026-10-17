import QtQuick
import QtTest
import "../../qml" as UI

TestCase {
    id: test
    name: "FaithfulHelloMotion"
    when: windowShown
    visible: true
    width: 300; height: 300
    Rectangle {
        id: sample
        width: 300; height: 300
        color: "#0b0e14"
        UI.HelloFace {
            id: face
            width: 300; height: 300
            ink: "#e6b450"
            sampleTime: 800
        }
    }
    function test_referencePoses() {
        const poses = {intro: 400, neutral: 800, down: 1400, left: 2400, right: 3600,
            wink: 4920, transform: 5520, success: 6160};
        for (const name in poses) {
            face.sampleTime = poses[name];
            wait(60);
            grabImage(sample).save(decodeURIComponent(Qt.resolvedUrl("../../.cache/test-artifacts/vector-").toString().replace("file://", "")) + name + ".png");
        }
    }
    function test_motionBetweenRecordedFrames() {
        face.sampleTime = 1968;
        wait(40);
        const first = grabImage(sample);
        const keyframe = face.frameIndex;
        face.sampleTime = 1976;
        wait(40);
        compare(face.frameIndex, keyframe);
        verify(!grabImage(sample).equals(first), "Motion changes between recorded 25-fps frames");
    }
    function test_scanLoopAndSuccessStops() {
        face.sampleTime = -1;
        face.scanning = true;
        wait(4900);
        verify(face.frameIndex >= 20 && face.frameIndex < 115, "Scanning loops without replaying the entrance");
        face.scanning = false;
        face.verified = true;
        wait(1750);
        compare(face.frameIndex, 154);
        wait(120);
        compare(face.frameIndex, 154, "Verified icon holds the final pose");
        face.verified = false;
        compare(face.frameIndex, 20, "Inactive animation returns to neutral");
    }
}
