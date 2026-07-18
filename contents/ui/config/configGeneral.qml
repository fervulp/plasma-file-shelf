import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
	id: page

	// служебная запись конфига (сам список полки) — здесь не редактируется
	property var cfg_fileList
	property alias cfg_cacheDir: dirField.text
	property alias cfg_hoverWidth: hoverSpin.value
	property alias cfg_edgeOpen: edgeOpenCheck.checked
	property string cfg_edgeOpenEdge
	property string cfg_panelIcon

	// SimpleKCM ждёт ровно ОДНОГО ребёнка-содержимое, поэтому все
	// невизуальные диалоги вложены внутрь элементов формы
	Kirigami.FormLayout {
		RowLayout {
			Kirigami.FormData.label: "Иконка в панели:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.Button {
				icon.name: page.cfg_panelIcon || "document-multiple"
				icon.width: Kirigami.Units.iconSizes.medium
				icon.height: Kirigami.Units.iconSizes.medium
				QQC2.ToolTip.text: "Выбрать иконку"
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
				text: "По умолчанию"
				enabled: page.cfg_panelIcon !== "document-multiple"
				onClicked: page.cfg_panelIcon = "document-multiple"
			}
		}

		RowLayout {
			Kirigami.FormData.label: "Ширина области наведения:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.SpinBox {
				id: hoverSpin
				from: 0
				to: 600
				stepSize: 4
				editable: true
			}

			QQC2.Label {
				text: hoverSpin.value === 0 ? "px (0 — по размеру иконки)" : "px"
				opacity: 0.7
			}
		}

		Item { Kirigami.FormData.isSection: true }

		QQC2.CheckBox {
			id: edgeOpenCheck
			Kirigami.FormData.label: "Перетаскивание:"
			text: "Открывать полку у края экрана"
		}

		RowLayout {
			Kirigami.FormData.label: "Край экрана:"
			spacing: Kirigami.Units.smallSpacing
			enabled: edgeOpenCheck.checked

			QQC2.ComboBox {
				readonly property var vals: ["right", "left", "top", "bottom"]
				model: ["Правый", "Левый", "Верхний", "Нижний"]
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
			text: "У выбранного края экрана появится едва заметная полоска "
				+ "(6 px, центральные 70% края). Поднесите к ней перетаскиваемый "
				+ "файл — полка откроется; бросить файл можно и прямо на полоску. "
				+ "Внимание: обычные клики мыши в этой полоске перехватываются ею."
		}

		Item { Kirigami.FormData.isSection: true }

		RowLayout {
			Kirigami.FormData.label: "Папка для временных файлов:"
			spacing: Kirigami.Units.smallSpacing

			QQC2.TextField {
				id: dirField
				Layout.fillWidth: true
				placeholderText: "~/.cache (по умолчанию)"
			}

			QQC2.Button {
				icon.name: "folder-open"
				QQC2.ToolTip.text: "Выбрать папку"
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
			text: "Внутри указанной папки создаётся подкаталог «file-shelf» — "
				+ "в нём хранятся zip-архивы брошенных на полку папок. "
				+ "Кнопка «Очистить полку» удаляет только этот подкаталог. "
				+ "Уже созданные архивы при смене папки не переносятся."
		}
	}
}
