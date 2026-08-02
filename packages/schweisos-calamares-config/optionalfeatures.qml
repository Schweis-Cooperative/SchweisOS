// SPDX-License-Identifier: GPL-3.0-or-later

import io.calamares.core 1.0

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
    property int activeCategoryIndex: 0
    property var selectedIds: []

    readonly property var categories: [
        {
            title: qsTr("Privacy & Security"),
            description: qsTr("Tools that improve privacy and local defensive posture without changing SchweisOS trust boundaries."),
            features: [
                {
                    id: "privacy",
                    title: qsTr("Tor Browser Launcher"),
                    packages: "torbrowser-launcher",
                    why: qsTr("Installs the upstream Tor Browser launcher. The browser itself is verified and downloaded when first used, so network access is required then."),
                    note: qsTr("Keeps anonymized browsing separate from the default browser.")
                },
                {
                    id: "security",
                    title: qsTr("Firewall Integration"),
                    packages: "firewalld, plasma-firewall",
                    why: qsTr("Adds a maintained firewall service and the Plasma firewall configuration interface."),
                    note: qsTr("Useful for laptops, public networks, and users who want visible firewall control.")
                }
            ]
        },
        {
            title: qsTr("Gaming & Performance"),
            description: qsTr("Gaming tools and visible performance helpers. No hidden tuning is applied."),
            features: [
                {
                    id: "gaming",
                    title: qsTr("Gaming Tools"),
                    packages: "gamemode, mangohud, lutris",
                    why: qsTr("Adds per-game performance requests, metrics, and game-library integration."),
                    note: qsTr("Good default for Steam-compatible and Lutris-managed games.")
                },
                {
                    id: "power-management",
                    title: qsTr("Power Profiles"),
                    packages: "power-profiles-daemon",
                    why: qsTr("Exposes supported platform power profiles to Plasma without applying undocumented tuning."),
                    note: qsTr("Helpful for balancing battery life and performance on laptops.")
                }
            ]
        },
        {
            title: qsTr("Development & Virtualization"),
            description: qsTr("Practical tools for building software, containers, remote work, and virtual machines."),
            features: [
                {
                    id: "development",
                    title: qsTr("Development Tools"),
                    packages: "git, cmake, ninja",
                    why: qsTr("Adds common source-control and native build tools while leaving language-specific stacks to the user."),
                    note: qsTr("Recommended for contributors and local source builds.")
                },
                {
                    id: "virtualization",
                    title: qsTr("Virtualization Tools"),
                    packages: "qemu-desktop, virt-manager",
                    why: qsTr("Adds KVM/QEMU virtual-machine management. Hardware virtualization support is still required."),
                    note: qsTr("Useful for testing other systems and SchweisOS development images.")
                },
                {
                    id: "containers",
                    title: qsTr("Container Tools"),
                    packages: "distrobox, podman",
                    why: qsTr("Adds rootless container and compatibility environments. Distrobox is not presented as a security sandbox."),
                    note: qsTr("Good for development isolation and non-native tooling.")
                },
                {
                    id: "network-tools",
                    title: qsTr("Network Tools"),
                    packages: "openssh, rsync",
                    why: qsTr("Adds secure remote access, file transfer, backup, and recovery workflows."),
                    note: qsTr("Useful for administrators and developer workstations.")
                }
            ]
        },
        {
            title: qsTr("Productivity & Media"),
            description: qsTr("Office, media playback, international documents, and printer support."),
            features: [
                {
                    id: "multimedia",
                    title: qsTr("Multimedia"),
                    packages: "vlc",
                    why: qsTr("Adds a widely compatible local media player from the official Arch repositories."),
                    note: qsTr("Useful for offline video and audio playback.")
                },
                {
                    id: "office",
                    title: qsTr("Office Suite"),
                    packages: "libreoffice-fresh",
                    why: qsTr("Adds word processing, spreadsheets, presentations, and document interoperability."),
                    note: qsTr("Best choice for a daily-use workstation.")
                },
                {
                    id: "fonts",
                    title: qsTr("International Fonts"),
                    packages: "noto-fonts, noto-fonts-cjk, noto-fonts-emoji",
                    why: qsTr("Improves multilingual document and web coverage without replacing the default UI font."),
                    note: qsTr("Recommended for international users and mixed-language documents.")
                },
                {
                    id: "printing",
                    title: qsTr("Printing Support"),
                    packages: "cups, system-config-printer",
                    why: qsTr("Adds local and network printer support and a graphical configuration tool."),
                    note: qsTr("Install this if you expect to configure printers after first boot.")
                }
            ]
        },
        {
            title: qsTr("Hardware & Accessibility"),
            description: qsTr("Bluetooth, accessibility, and display-stack compatibility tools."),
            features: [
                {
                    id: "bluetooth",
                    title: qsTr("Bluetooth Support"),
                    packages: "bluez, bluez-utils",
                    why: qsTr("Adds the standard Linux Bluetooth stack and diagnostic command-line tools."),
                    note: qsTr("Useful for wireless peripherals and Bluetooth audio.")
                },
                {
                    id: "accessibility",
                    title: qsTr("Accessibility"),
                    packages: "orca, speech-dispatcher",
                    why: qsTr("Adds screen-reader and speech services for users who need them."),
                    note: qsTr("Keeps accessibility support available without forcing it on every install.")
                },
                {
                    id: "wayland-tools",
                    title: qsTr("Wayland Tools"),
                    packages: "wayland-utils",
                    why: qsTr("Adds protocol and compositor diagnostics for the default modern display stack."),
                    note: qsTr("Useful for debugging display, scaling, and compositor issues.")
                },
                {
                    id: "x11-compatibility",
                    title: qsTr("X11 Compatibility"),
                    packages: "xorg-xwayland",
                    why: qsTr("Runs supported X11 applications inside the default Plasma Wayland session without changing the session type."),
                    note: qsTr("Recommended for legacy desktop applications and games.")
                }
            ]
        },
        {
            title: qsTr("Diagnostics & Recovery"),
            description: qsTr("Explicit maintenance and recovery tools for users who want them installed from day one."),
            features: [
                {
                    id: "diagnostics",
                    title: qsTr("Storage Diagnostics"),
                    packages: "smartmontools, nvme-cli",
                    why: qsTr("Exposes drive health and NVMe diagnostics without background telemetry."),
                    note: qsTr("Useful for troubleshooting SSDs and storage failures.")
                },
                {
                    id: "recovery",
                    title: qsTr("Recovery Tools"),
                    packages: "gparted, testdisk",
                    why: qsTr("Adds partition repair and data-recovery tools. Use them carefully and keep backups."),
                    note: qsTr("For advanced users and recovery sessions.")
                },
                {
                    id: "maintenance",
                    title: qsTr("Maintenance Tools"),
                    packages: "pacman-contrib, reflector",
                    why: qsTr("Adds supported package-cache, mirror, and maintenance utilities without automatic hidden changes."),
                    note: qsTr("Useful for keeping an Arch-compatible system healthy.")
                }
            ]
        }
    ]

    function activeFeatures() {
        return categories[activeCategoryIndex].features
    }

    function isKnownFeature(featureId) {
        for (var i = 0; i < categories.length; ++i) {
            var features = categories[i].features
            for (var j = 0; j < features.length; ++j) {
                if (features[j].id === featureId)
                    return true
            }
        }
        return false
    }

    function isSelected(featureId) {
        return selectedIds.indexOf(featureId) !== -1
    }

    function setSelected(featureId, selected) {
        if (!isKnownFeature(featureId))
            return

        var next = selectedIds.slice()
        var index = next.indexOf(featureId)
        if (selected && index === -1)
            next.push(featureId)
        else if (!selected && index !== -1)
            next.splice(index, 1)

        selectedIds = next
        syncGlobalStorage()
    }

    function toggleFeature(featureId) {
        setSelected(featureId, !isSelected(featureId))
    }

    function syncGlobalStorage() {
        Global.insert("packagechooser_extras", selectedIds.join(","))
    }

    function restoreFromGlobalStorage() {
        if (!Global.contains("packagechooser_extras")) {
            syncGlobalStorage()
            return
        }

        var raw = String(Global.value("packagechooser_extras"))
        if (raw.length === 0) {
            selectedIds = []
            syncGlobalStorage()
            return
        }

        var restored = []
        var values = raw.split(",")
        for (var i = 0; i < values.length; ++i) {
            if (isKnownFeature(values[i]) && restored.indexOf(values[i]) === -1)
                restored.push(values[i])
        }
        selectedIds = restored
        syncGlobalStorage()
    }

    Component.onCompleted: restoreFromGlobalStorage()

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
                text: qsTr("Choose optional features")
                color: root.foreground
                font.pixelSize: 30
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Label {
                Layout.fillWidth: true
                Layout.maximumWidth: 900
                text: qsTr("Profiles provide a safe starting point. Add only the package groups you want in the installed system; every selectable feature is already available in the signed offline ISO payload.")
                color: root.muted
                font.pixelSize: 14
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: Math.min(292, root.width * 0.32)
                Layout.fillHeight: true
                radius: 16
                color: root.cardBackground
                border.color: root.borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Categories")
                        color: root.foreground
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: root.categories

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 12
                            color: index === root.activeCategoryIndex ? "#e9f5ff" : "#ffffff"
                            border.color: index === root.activeCategoryIndex ? root.accent : root.borderColor
                            border.width: 1

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.activeCategoryIndex = index
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 2

                                Label {
                                    width: parent.width
                                    text: modelData.title
                                    color: root.foreground
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Label {
                                    width: parent.width
                                    text: qsTr("%1 options").arg(modelData.features.length)
                                    color: root.muted
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52
                        radius: 12
                        color: "#f3f8fc"
                        border.color: root.borderColor

                        Label {
                            anchors.centerIn: parent
                            text: selectedIds.length === 1 ? qsTr("1 feature selected") : qsTr("%1 features selected").arg(selectedIds.length)
                            color: root.foreground
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: root.cardBackground
                border.color: root.borderColor
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Label {
                        Layout.fillWidth: true
                        text: root.categories[root.activeCategoryIndex].title
                        color: root.foreground
                        font.pixelSize: 22
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.categories[root.activeCategoryIndex].description
                        color: root.muted
                        font.pixelSize: 13
                        lineHeight: 1.25
                        wrapMode: Text.WordWrap
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        ColumnLayout {
                            width: parent.width
                            spacing: 12

                            Repeater {
                                model: root.activeFeatures()

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 132
                                    radius: 14
                                    color: root.isSelected(modelData.id) ? "#eef8ff" : "#ffffff"
                                    border.color: root.isSelected(modelData.id) ? root.accent : root.borderColor
                                    border.width: root.isSelected(modelData.id) ? 2 : 1

                                    MouseArea {
                                        id: featureHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }

                                    ToolTip.visible: featureHover.containsMouse
                                    ToolTip.text: modelData.why
                                    ToolTip.delay: 350

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        spacing: 12

                                        CheckBox {
                                            checked: root.isSelected(modelData.id)
                                            onClicked: root.setSelected(modelData.id, checked)
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.title
                                                color: root.foreground
                                                font.pixelSize: 17
                                                font.weight: Font.DemiBold
                                                wrapMode: Text.WordWrap
                                            }

                                            Label {
                                                Layout.fillWidth: true
                                                text: qsTr("Packages: %1.").arg(modelData.packages)
                                                color: root.accent
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                wrapMode: Text.WordWrap
                                            }

                                            Label {
                                                Layout.fillWidth: true
                                                text: modelData.note
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
            }
        }
    }
}
