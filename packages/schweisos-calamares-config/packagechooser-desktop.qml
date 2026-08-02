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

    Component.onCompleted: {
        if (config.packageChoice === "")
            config.packageChoice = "kde-plasma"
    }

    Rectangle {
        anchors.fill: parent
        color: root.pageBackground
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(28, parent.width * 0.045)
        spacing: 18

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                Layout.fillWidth: true
                text: qsTr("Choose your desktop environment")
                color: root.foreground
                font.pixelSize: 30
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 820
                text: qsTr("SchweisOS currently qualifies KDE Plasma as the official supported desktop. This page is part of the installer architecture so additional desktops can be added later only after package, session, screenshot, and QA contracts are complete.")
                color: root.muted
                font.pixelSize: 14
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            Rectangle {
                Layout.preferredWidth: Math.min(310, root.width * 0.34)
                Layout.fillHeight: true
                radius: 14
                color: root.cardBackground
                border.color: root.accent
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 10

                    RadioButton {
                        checked: true
                        text: qsTr("KDE Plasma")
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        onClicked: config.packageChoice = "kde-plasma"
                    }

                    Rectangle {
                        Layout.preferredWidth: 148
                        Layout.preferredHeight: 28
                        radius: 14
                        color: "#eaf7f0"
                        border.color: "#77ba93"

                        Label {
                            anchors.centerIn: parent
                            text: qsTr("Officially supported")
                            color: "#1d7044"
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Modern Plasma desktop with Wayland-first defaults, KDE applications, SDDM, NetworkManager, and SchweisOS package-owned integration.")
                        color: root.muted
                        font.pixelSize: 13
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 18
                color: "#081527"
                border.color: "#183454"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 280
                        radius: 16
                        color: "#0b1d35"
                        border.color: "#1e4f7c"
                        border.width: 1

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 14
                            radius: 12
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#133b67" }
                                GradientStop { position: 0.55; color: "#102a4a" }
                                GradientStop { position: 1.0; color: "#081527" }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 14
                            height: 34
                            radius: 10
                            color: "#101923"
                            opacity: 0.92
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 28
                            anchors.bottomMargin: 22
                            spacing: 8

                            Repeater {
                                model: 5
                                Rectangle {
                                    width: 18
                                    height: 18
                                    radius: 5
                                    color: index === 0 ? root.accent : "#d6e0e8"
                                    opacity: index === 0 ? 1.0 : 0.8
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width * 0.54, 420)
                            height: Math.min(parent.height * 0.42, 230)
                            radius: 14
                            color: "#111a25"
                            border.color: "#2d506c"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: 34
                                radius: 14
                                color: "#192637"
                            }

                            GridLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.margins: 50
                                columns: 4
                                rowSpacing: 16
                                columnSpacing: 16

                                Repeater {
                                    model: 8
                                    Rectangle {
                                        Layout.preferredWidth: 34
                                        Layout.preferredHeight: 34
                                        radius: 9
                                        color: index % 3 === 0 ? root.accent : "#d6e0e8"
                                        opacity: index % 3 === 0 ? 0.95 : 0.65
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("KDE Plasma is the only desktop environment installed by this ISO. Future desktop choices must add package manifests, cleanup rules, licensed preview assets, and hardware validation before they become selectable.")
                        color: "#cbd7e3"
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
