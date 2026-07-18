import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
	id: page

	// Configuration record (the shelf list itself) — not editable here
	property var cfg_fileList
	property alias cfg_cacheDir: dirField.text
	property alias cfg_hoverWidth: hoverSpin.value
	property alias cfg_edgeOpen: edgeOpenCheck.checked
	property string cfg_edgeOpenEdge
	property string cfg_panelIcon

	// SimpleKCM expects exactly ONE child-content, so all
	// non-visual dialogs are nested inside form elements
	Kirigami.FormLayout {
		RowLayout {
			Kirigami.FormData.label: "Panel icon:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.Button {
				icon.name: page.cfg_panelIcon || "document-multiple"
				icon.width: Kirigami.Units.iconSizes.medium
				icon.height: Kirigami.Units.iconSizes.medium
				QQC2.ToolTip.text: "Select icon"
				QQC2.ToolTip.visible: hovered
				onClicked: iconDialog.open()

				KIconThemes.IconDialog {
					id: iconDialog
					onIconNameChanged: {
						if (iconName.length > 0)
							page.cfg_panelIcon = iconName
					}
				}
			}

			QQC2.Button {
				icon.name: "edit-undo"
				text: "Default"
				enabled: page.cfg_panelIcon !== "document-multiple"
				onClicked: page.cfg_panelIcon = "document-multiple"
			}
		}

		RowLayout {
			Kirigami.FormData.label: "Hover area width:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.SpinBox {
				id: hoverSpin
				from: 0
				to: 600
				stepSize: 4
				editable: true
			}

			QQC2.Label {
				text: hoverSpin.value === 0 ? "px (0 — by icon size)" : "px"
				opacity: 0.7
			}
		}

		Item { Kirigami.FormData.isSection: true }

		QQC2.CheckBox {
			id: edgeOpenCheck
			Kirigami.FormData.label: "Drag and drop:"
			text: "Open shelf at screen edge"
		}

		RowLayout {
			Kirigami.FormData.label: "Screen edge:"
			spacing: Kirigami.Units.smallSpacing
			enabled: edgeOpenCheck.checked

			QQC2.ComboBox {
				readonly property var vals: ["right", "left", "top", "bottom"]
				model: ["Right", "Left", "Top", "Bottom"]
				currentIndex: {
					var i = vals.indexOf(page.cfg_edgeOpenEdge || "right")
					return i >= 0 ? i : 0
				}
				onActivated: index => page.cfg_edgeOpenEdge = vals[index]
			}
		}

		QQC2.Label {
			Layout.fillWidth: true
			Layout.maximumWidth: Kirigami.Units.gridUnit * 22
			wrapMode: Text.WordWrap
			font.pixelSize: Kirigami.Theme.smallFont.pixelSize
			opacity: 0.7
			text: "A barely visible strip (6 px, central 70% of the edge) "
			+ "will appear at the selected screen edge. Move a dragged "
			+ "file to it — the shelf will open; you can also drop the file "
			+ "directly onto the strip. Note: regular mouse clicks in "
			+ "this strip are intercepted by it."
		}

		Item { Kirigami.FormData.isSection: true }

		RowLayout {
			Kirigami.FormData.label: "Temporary files folder:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.TextField {
				id: dirField
				Layout.fillWidth: true
				placeholderText: "~/.cache (default)"
			}

			QQC2.Button {
				icon.name: "folder-open"
				QQC2.ToolTip.text: "Select folder"
				QQC2.ToolTip.visible: hovered
				onClicked: folderDialog.open()

				FolderDialog {
					id: folderDialog
					onAccepted: {
						var p = String(selectedFolder)
						if (p.indexOf("file://") === 0) {
							p = p.replace(/^file:\/\//, "")
							try { p = decodeURIComponent(p) } catch (e) { }
						}
						dirField.text = p
					}
				}
			}
		}

		QQC2.Label {
			Layout.fillWidth: true
			Layout.maximumWidth: Kirigami.Units.gridUnit * 22
			wrapMode: Text.WordWrap
			font.pixelSize: Kirigami.Theme.smallFont.pixelSize
			opacity: 0.7
			text: "A \"file-shelf\" subdirectory is created inside the specified "
			+ "folder — it stores zip archives of folders dropped onto the shelf. "
			+ "The \"Clear shelf\" button only removes this subdirectory. "
			+ "Existing archives are not moved when changing the folder."
		}
	}
}
