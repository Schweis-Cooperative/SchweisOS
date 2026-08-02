// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: parent.width
    height: parent.height

    readonly property color accent: "#1589d6"
    readonly property color pageBackground: "#f7fafc"
    readonly property color cardBackground: "#ffffff"
    readonly property color borderColor: "#d6e0e8"
    readonly property color foreground: "#102235"
    readonly property color muted: "#53697d"
    readonly property var kernelOptions: [
        {
            id: "linux-zen",
            title: qsTr("Linux Zen"),
            subtitle: qsTr("Recommended"),
            description: qsTr("Package: linux-zen. Desktop-focused Arch kernel tuned for responsiveness and gaming workloads. This is the SchweisOS default.")
        },
        {
            id: "linux",
            title: qsTr("Linux"),
            subtitle: qsTr("Arch default"),
            description: qsTr("Package: linux. Standard Arch Linux kernel. Choose it for the closest possible alignment with Arch's default kernel path.")
        },
        {
            id: "linux-lts",
            title: qsTr("Linux LTS"),
            subtitle: qsTr("Conservative updates"),
            description: qsTr("Package: linux-lts. Long-term support Arch kernel. Choose it for slower kernel churn and conservative hardware support.")
        },
        {
            id: "linux-hardened",
            title: qsTr("Linux Hardened"),
            subtitle: qsTr("Security hardening"),
            description: qsTr("Package: linux-hardened. Arch kernel with additional security hardening. Some desktop, gaming, or virtualization workloads may require extra qualification.")
        }
    ]

    Component.onCompleted: {
        if (config.packageChoice === "")
            config.packageChoice = "linux-zen"
    }

    Rectangle {
        anchors.fill: parent
        color: root.pageBackground
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(28, parent.width * 0.045)
        spacing: 16

        Label {
            Layout.fillWidth: true
            text: qsTr("Choose your Linux kernel")
            color: root.foreground
            font.pixelSize: 30
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: 820
            text: qsTr("SchweisOS keeps Arch kernel packages intact. Pick one kernel for the installed system; unselected live kernels are removed during reconciliation.")
            color: root.muted
            font.pixelSize: 14
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width > 860 ? 2 : 1
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: root.kernelOptions

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 136
                    radius: 14
                    color: root.cardBackground
                    border.color: config.packageChoice === modelData.id ? root.accent : root.borderColor
                    border.width: config.packageChoice === modelData.id ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: config.packageChoice = modelData.id
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RadioButton {
                            checked: config.packageChoice === modelData.id
                            onClicked: config.packageChoice = modelData.id
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Label {
                                    text: modelData.title
                                    color: root.foreground
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }

                                Rectangle {
                                    visible: modelData.id === "linux-zen"
                                    Layout.preferredWidth: recommendedLabel.implicitWidth + 18
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: "#eaf7f0"
                                    border.color: "#77ba93"

                                    Label {
                                        id: recommendedLabel
                                        anchors.centerIn: parent
                                        text: qsTr("Recommended")
                                        color: "#1d7044"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.subtitle
                                color: root.accent
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.description
                                color: root.muted
                                font.pixelSize: 13
                                lineHeight: 1.18
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
