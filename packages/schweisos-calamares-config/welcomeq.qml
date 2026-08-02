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
    property string schweisosNetworkState: "unknown"
    property string schweisosNetworkReason: ""
    property string schweisosNetworkSource: ""
    readonly property bool schweisosInternetAvailable: schweisosNetworkState === "connected" || (schweisosNetworkState === "unknown" && Network.hasInternet)

    function updateNetworkState() {
        var request = new XMLHttpRequest()
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE)
                return
            if (request.status !== 0 && request.status !== 200)
                return

            var lines = request.responseText.split("\n")
            for (var index = 0; index < lines.length; index++) {
                var separator = lines[index].indexOf("=")
                if (separator < 1)
                    continue
                var key = lines[index].substring(0, separator)
                var value = lines[index].substring(separator + 1)
                if (key === "STATE")
                    schweisosNetworkState = value
                else if (key === "REASON")
                    schweisosNetworkReason = value
                else if (key === "SOURCE")
                    schweisosNetworkSource = value
            }
        }
        request.open("GET", "file:///run/schweisos-installer/network-state")
        request.send()
    }

    Component.onCompleted: updateNetworkState()

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: welcome.updateNetworkState()
    }

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
            color: welcome.schweisosInternetAvailable ? "#eaf7f0" : "#fff6df"
            border.color: welcome.schweisosInternetAvailable ? "#77ba93" : "#d6a94c"
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
                    color: welcome.schweisosInternetAvailable ? "#21824b" : "#b27700"
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Label {
                        Layout.fillWidth: true
                        text: welcome.schweisosInternetAvailable ? qsTr("Internet connected") : qsTr("Offline installation available")
                        color: welcome.foreground
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Label {
                        Layout.fillWidth: true
                        text: welcome.schweisosInternetAvailable
                            ? qsTr("Online features are enabled. Mirrors and optional packages can be refreshed when selected.")
                            : qsTr("No Internet connection was confirmed. Offline installation is fully available. Optional online features are disabled.")
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
