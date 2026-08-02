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
    readonly property var profileOptions: [
        {
            id: "privacy",
            title: qsTr("Privacy"),
            subtitle: qsTr("Recommended"),
            description: qsTr("Balanced desktop profile with firewall integration, X11 compatibility, and maintenance tools. It avoids unreviewed third-party package sources.")
        },
        {
            id: "gaming",
            title: qsTr("Gaming"),
            subtitle: qsTr("Games and performance diagnostics"),
            description: qsTr("Adds GameMode, MangoHud, Lutris, X11 compatibility, and power-profile support while keeping tuning visible and reversible.")
        },
        {
            id: "developer",
            title: qsTr("Developer"),
            subtitle: qsTr("Build and container tools"),
            description: qsTr("Adds source-control, native build, container, network, and diagnostic tools without installing language-specific stacks by default.")
        },
        {
            id: "creator",
            title: qsTr("Creator"),
            subtitle: qsTr("Media and multilingual content"),
            description: qsTr("Adds multimedia playback and international font coverage for media review, documents, and multilingual content.")
        },
        {
            id: "office",
            title: qsTr("Office"),
            subtitle: qsTr("Workstation utilities"),
            description: qsTr("Adds LibreOffice, printing support, international fonts, and Bluetooth utilities for a practical workstation setup.")
        },
        {
            id: "minimal",
            title: qsTr("Minimal"),
            subtitle: qsTr("Smallest supported KDE install"),
            description: qsTr("Installs the required SchweisOS KDE desktop, Firefox, the selected kernel, and base utilities. Optional features can still be added next.")
        }
    ]

    Component.onCompleted: {
        if (config.packageChoice === "")
            config.packageChoice = "privacy"
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
            text: qsTr("Choose an installation profile")
            color: root.foreground
            font.pixelSize: 30
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: 820
            text: qsTr("Profiles select sensible package groups for common workflows. You can still customize optional features on the next page.")
            color: root.muted
            font.pixelSize: 14
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.width > 980 ? 3 : (root.width > 660 ? 2 : 1)
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: root.profileOptions

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 164
                    radius: 14
                    color: root.cardBackground
                    border.color: config.packageChoice === modelData.id ? root.accent : root.borderColor
                    border.width: config.packageChoice === modelData.id ? 2 : 1

                    MouseArea {
                        anchors.fill: parent
                        onClicked: config.packageChoice = modelData.id
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RadioButton {
                                checked: config.packageChoice === modelData.id
                                onClicked: config.packageChoice = modelData.id
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: root.foreground
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.subtitle
                            color: modelData.id === "privacy" ? "#1d7044" : root.accent
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
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
