// SPDX-License-Identifier: GPL-3.0-or-later

import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Page {
    id: welcome

    readonly property color accent: "#1589d6"
    readonly property color foreground: "#102235"
    readonly property color muted: "#53697d"

    background: Rectangle {
        color: "#f7fafc"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(38, parent.width * 0.06)
        anchors.rightMargin: Math.max(38, parent.width * 0.06)
        anchors.topMargin: Math.max(34, parent.height * 0.06)
        anchors.bottomMargin: Math.max(26, parent.height * 0.04)
        spacing: 18

        Label {
            Layout.fillWidth: true
            text: qsTr("Welcome to SchweisOS")
            color: welcome.foreground
            font.pixelSize: 34
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            Layout.maximumWidth: 680
            text: qsTr("A clean, privacy-respecting Arch-based desktop with transparent defaults and full user control. Let's prepare your new system.")
            color: welcome.muted
            font.pixelSize: 17
            lineHeight: 1.25
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.maximumWidth: 720
            Layout.preferredHeight: networkContent.implicitHeight + 28
            radius: 12
            color: Network.hasInternet ? "#eaf7f0" : "#fff6df"
            border.color: Network.hasInternet ? "#77ba93" : "#d6a94c"
            border.width: 1

            RowLayout {
                id: networkContent
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    radius: 6
                    color: Network.hasInternet ? "#21824b" : "#b27700"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Label {
                        Layout.fillWidth: true
                        text: Network.hasInternet ? qsTr("Internet connection detected") : qsTr("No Internet connection")
                        color: welcome.foreground
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: Network.hasInternet
                            ? qsTr("Repository-backed online services will be available after installation.")
                            : qsTr("Offline installation is fully available. Optional online services can be enabled later.")
                        color: welcome.muted
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: 720
            columns: 3
            columnSpacing: 12
            rowSpacing: 12

            Repeater {
                model: [
                    { title: qsTr("Private by default"), body: qsTr("No telemetry, forced account, or silent reporting.") },
                    { title: qsTr("Arch-compatible"), body: qsTr("Upstream packages and full-system updates stay intact.") },
                    { title: qsTr("Your system"), body: qsTr("Choose your browser, kernel, and optional tools.") }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 118
                    radius: 12
                    color: "#ffffff"
                    border.color: "#d6e0e8"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 7

                        Label {
                            Layout.fillWidth: true
                            text: modelData.title
                            color: welcome.foreground
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: modelData.body
                            color: welcome.muted
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ComboBox {
                id: languages
                Layout.preferredWidth: Math.min(390, welcome.width * 0.42)
                textRole: "label"
                currentIndex: config.localeIndex
                model: config.languagesModel
                onActivated: config.localeIndex = currentIndex
                Accessible.name: qsTr("Installer language")
            }

            Item { Layout.fillWidth: true }

            Label {
                text: qsTr("Maintained by Marijua")
                color: welcome.muted
                font.pixelSize: 12
            }
        }
    }
}
