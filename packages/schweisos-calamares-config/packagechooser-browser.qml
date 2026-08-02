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
    readonly property var browserOptions: [
        {
            id: "firefox",
            title: qsTr("Firefox"),
            subtitle: qsTr("Default and available in this ISO"),
            description: qsTr("A mature, open-source browser from the official Arch repositories. It is the default SchweisOS browser until additional browser packages complete repository admission."),
            available: true
        },
        {
            id: "librewolf",
            title: qsTr("LibreWolf"),
            subtitle: qsTr("Approved, pending repository admission"),
            description: qsTr("Firefox-derived browser focused on privacy hardening. It remains disabled until SchweisOS can ship a reviewed, signed package source."),
            available: false
        },
        {
            id: "zen-browser",
            title: qsTr("Zen Browser"),
            subtitle: qsTr("Approved, pending repository admission"),
            description: qsTr("Firefox-derived browser with a modern power-user interface. It remains disabled until its package source and signing path are qualified."),
            available: false
        },
        {
            id: "brave",
            title: qsTr("Brave"),
            subtitle: qsTr("Approved, pending repository admission"),
            description: qsTr("The only approved Chromium-family browser candidate. It remains disabled until its packaging and repository trust model are reviewed."),
            available: false
        }
    ]

    Component.onCompleted: {
        if (config.packageChoice === "")
            config.packageChoice = "firefox"
    }

    Rectangle {
        anchors.fill: parent
        color: root.pageBackground
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Math.max(28, parent.width * 0.045)
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Label {
                Layout.fillWidth: true
                text: qsTr("Choose your web browser")
                color: root.foreground
                font.pixelSize: 30
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 820
                text: qsTr("Only browsers that are available from a reviewed, signed SchweisOS installation payload can be selected. Disabled entries show the approved future architecture without silently installing untrusted packages.")
                color: root.muted
                font.pixelSize: 14
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width > 860 ? 2 : 1
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: root.browserOptions

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142
                    radius: 14
                    color: modelData.available ? root.cardBackground : "#f1f5f8"
                    border.color: config.packageChoice === modelData.id ? root.accent : root.borderColor
                    border.width: config.packageChoice === modelData.id ? 2 : 1
                    opacity: modelData.available ? 1.0 : 0.72

                    MouseArea {
                        anchors.fill: parent
                        enabled: modelData.available
                        onClicked: config.packageChoice = modelData.id
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RadioButton {
                            enabled: modelData.available
                            checked: config.packageChoice === modelData.id
                            onClicked: config.packageChoice = modelData.id
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

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
                                    Layout.preferredWidth: availabilityLabel.implicitWidth + 18
                                    Layout.preferredHeight: 26
                                    radius: 13
                                    color: modelData.available ? "#eaf7f0" : "#fff6df"
                                    border.color: modelData.available ? "#77ba93" : "#d6a94c"

                                    Label {
                                        id: availabilityLabel
                                        anchors.centerIn: parent
                                        text: modelData.available ? qsTr("Available") : qsTr("Not in this ISO")
                                        color: modelData.available ? "#1d7044" : "#8a5a00"
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
