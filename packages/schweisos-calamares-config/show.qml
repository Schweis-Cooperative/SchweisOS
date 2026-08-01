// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15

Item {
    id: root

    anchors.fill: parent

    readonly property color backgroundTop: "#030914"
    readonly property color backgroundBottom: "#071a32"
    readonly property color accent: "#0b8fe8"
    readonly property color foreground: "#f4f8fc"
    readonly property url logoSource: "file:///usr/share/schweisos/branding/schweisos.png"
    readonly property var contributors: ["Marijua"]

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: root.backgroundTop }
            GradientStop { position: 1.0; color: root.backgroundBottom }
        }
    }

    Rectangle {
        id: glow

        width: Math.min(parent.width, parent.height) * 0.72
        height: width
        radius: width / 2
        anchors.centerIn: parent
        color: root.accent
        opacity: 0.08
        scale: 0.92

        SequentialAnimation on scale {
            loops: Animation.Infinite
            NumberAnimation { to: 1.02; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.92; duration: 1800; easing.type: Easing.InOutSine }
        }

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.13; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.08; duration: 1800; easing.type: Easing.InOutSine }
        }
    }

    Column {
        id: content

        anchors.centerIn: parent
        spacing: Math.max(22, parent.height * 0.035)
        width: Math.min(parent.width * 0.68, 620)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.foreground
            text: "Welcome to SchweisOS"
            font.pixelSize: 26
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#a9bed2"
            text: "A clean, package-owned Arch-based desktop focused on user control, transparency, and maintainable defaults."
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }

        Rectangle {
            width: Math.min(parent.width, 520)
            height: contributorColumn.height + 28
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 14
            color: "#0b1d36"
            border.color: "#173d63"
            border.width: 1
            opacity: 0.94

            Column {
                id: contributorColumn

                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 8

                Text {
                    width: parent.width
                    color: root.foreground
                    text: "Contributors"
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    color: "#a9bed2"
                    text: root.contributors.join(" · ")
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }
            }
        }

        Item {
            width: parent.width
            height: 28

            Repeater {
                model: 5

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: root.accent
                    x: (parent.width / 2) - 38 + (index * 19)
                    y: 10
                    opacity: 0.24

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 130 }
                        NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.OutCubic }
                        NumberAnimation { to: 0.24; duration: 760; easing.type: Easing.InCubic }
                        PauseAnimation { duration: 420 }
                    }
                }
            }
        }
    }
}
