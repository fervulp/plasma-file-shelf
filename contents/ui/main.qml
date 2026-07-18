/*
 * File Shelf — temporary "shelf" for files (analog of Dropover on macOS).
 *
 *  • drag file(s) to the icon in the panel — they will be added to the shelf;
 *  • hover or drag a file to expand the shelf;
 *  • files can be dragged out of the shelf to other applications one by one
 *    (drag by the row) or all at once ("Drag all" button);
 *  • a dropped FOLDER is automatically packed into a zip
 *    (by default in ~/.cache/file-shelf/, base folder configurable),
 *    and the archive is what gets dragged out;
 *  • the list is stored in the plasmoid config and persists after restart.
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import org.kde.draganddrop as DnD
import Qt5Compat.GraphicalEffects as Effects

PlasmoidItem {
	id: root

	readonly property var files: plasmoid.configuration.fileList || []
	readonly property int count: files.length

	property bool autoOpened: false
	property bool dragOut: false
	property var pendingJobs: ({})
	property int zipJobs: 0

	switchWidth: Kirigami.Units.gridUnit * 8
		switchHeight: Kirigami.Units.gridUnit * 8

			toolTipMainText: "File Shelf"
			toolTipSubText: count > 0
			? count + " file(s) — drag from or to the shelf"
			: "Drag files here"

			function partsOf(e) { return String(e).split("|||") }
			function kindOf(e) {
				var p = partsOf(e)
				if (p.length >= 3)
					return p[2]
					return p.length === 2 ? "dir" : "file"
			}
			function isDirEntry(e) { return kindOf(e) === "dir" }
			function hasCacheCopy(e) { return kindOf(e) !== "file" }
			function dragUrlOf(e) { return partsOf(e)[0] }
			function origUrlOf(e) {
				var p = partsOf(e)
				return p.length >= 2 ? p[1] : p[0]
			}
			readonly property var dragUrls: files.map(e => dragUrlOf(e))

			property var selectedSet: ({})
			readonly property var selectedDragUrls:
			files.filter(e => selectedSet[e] === true).map(e => dragUrlOf(e))
			readonly property int selectedCount: selectedDragUrls.length

			function isSelected(e) { return selectedSet[String(e)] === true }
			function toggleSelect(e) {
				var s = {}
				for (var k in selectedSet)
					s[k] = selectedSet[k]
					var key = String(e)
					if (s[key] === true)
						delete s[key]
						else
							s[key] = true
							selectedSet = s
			}
			function selectAll() {
				var s = {}
				for (var i = 0; i < files.length; i++)
					s[String(files[i])] = true
					selectedSet = s
			}
			function clearSelection() { selectedSet = ({}) }

			function shellQuote(s) {
				return "'" + String(s).replace(/'/g, "'\\''") + "'"
			}

			function cacheDirSh() {
				var p = String(plasmoid.configuration.cacheDir || "").trim().replace(/\/+$/, "")
				if (p === "" )
					return '"${XDG_CACHE_HOME:-$HOME/.cache}/file-shelf"'
					if (p === "~")
						return '"$HOME/file-shelf"'
						if (p.indexOf("~/") === 0)
							return '"$HOME"' + shellQuote(p.substring(1) + "/file-shelf")
							return shellQuote(p + "/file-shelf")
			}

			function pathToUrl(p) {
				return "file://" + String(p).split("/").map(encodeURIComponent).join("/")
			}

			function urlToPath(u) {
				var s = String(u)
				if (s.indexOf("file://") !== 0)
					return ""
					s = s.replace(/^file:\/\//, "")
					try { s = decodeURIComponent(s) } catch (e) { }
					return s.replace(/\/+$/, "")
			}

			function entryExists(origUrl) {
				for (var i = 0; i < files.length; i++)
					if (origUrlOf(files[i]) === String(origUrl))
						return true
						return false
			}

			function pushEntry(e) {
				if (entryExists(origUrlOf(e)))
					return
					var arr = (plasmoid.configuration.fileList || []).slice()
					arr.push(String(e))
					plasmoid.configuration.fileList = arr
					if (!isSelected(e))
						toggleSelect(e)
			}

			readonly property string detectExtSh:
			"detect_ext() {\n"
			+ "  ext=$(file -b --extension -- \"$1\" 2>/dev/null | cut -d/ -f1)\n"
			+ "  case \"$ext\" in ''|'???')\n"
			+ "    mime=$(file -b --mime-type -- \"$1\" 2>/dev/null)\n"
			+ "    case \"$mime\" in\n"
			+ "      application/json) ext=json;; application/pdf) ext=pdf;;\n"
			+ "      application/zip) ext=zip;; application/gzip) ext=gz;;\n"
			+ "      application/x-tar) ext=tar;; application/x-7z-compressed) ext=7z;;\n"
			+ "      application/x-rar) ext=rar;; application/x-iso9660-image) ext=iso;;\n"
			+ "      text/html) ext=html;; text/csv) ext=csv;;\n"
			+ "      text/x-shellscript) ext=sh;; text/x-python|text/x-script.python) ext=py;;\n"
			+ "      image/png) ext=png;; image/jpeg) ext=jpg;; image/gif) ext=gif;;\n"
			+ "      image/webp) ext=webp;; image/svg+xml) ext=svg;; image/bmp) ext=bmp;;\n"
			+ "      image/avif) ext=avif;;\n"
			+ "      audio/mpeg) ext=mp3;; audio/flac) ext=flac;; audio/ogg) ext=ogg;;\n"
			+ "      video/mp4) ext=mp4;; video/x-matroska) ext=mkv;; video/webm) ext=webm;;\n"
			+ "      text/*) ext=txt;; *) ext=\"\";;\n"
			+ "    esac;;\n"
			+ "  esac\n"
			+ "  printf %s \"$ext\"\n"
			+ "}\n"

			function addUrls(urls) {
				if (!urls || urls.length === 0)
					return
					for (var i = 0; i < urls.length; i++) {
						var u = String(urls[i])
						if (u.length === 0 || entryExists(u))
							continue
							var path = urlToPath(u)
							if (path.length === 0) {
								if (u.indexOf("http://") === 0 || u.indexOf("https://") === 0)
									addWebUrl(u)
									else
										pushEntry(u)
										continue
							}
							var cmd = detectExtSh
							+ "p=" + shellQuote(path) + "\n"
							+ "cache=" + cacheDirSh() + "\n"
							+ "if [ -d \"$p\" ]; then\n"
							+ "  h=$(printf %s \"$p\" | md5sum | cut -c1-8)\n"
							+ "  d=\"$cache/$h\"\n"
							+ "  mkdir -p \"$d\"\n"
							+ "  out=\"$d/$(basename \"$p\").zip\"\n"
							+ "  rm -f \"$out\"\n"
							+ "  (cd \"$(dirname \"$p\")\" && zip -qry \"$out\" \"$(basename \"$p\")\")\n"
							+ "  echo \"DIR|||$out\"\n"
							+ "elif [ -e \"$p\" ]; then\n"
							+ "  base=$(basename \"$p\"); ext=\"\"\n"
							+ "  case \"$base\" in *.*) ;; *) ext=$(detect_ext \"$p\");; esac\n"
							+ "  if [ -n \"$ext\" ]; then\n"
							+ "    h=$(printf %s \"$p\" | md5sum | cut -c1-8)\n"
							+ "    d=\"$cache/$h\"\n"
							+ "    mkdir -p \"$d\"\n"
							+ "    out=\"$d/$base.$ext\"\n"
							+ "    cp -f -- \"$p\" \"$out\"\n"
							+ "    echo \"REN|||$out\"\n"
							+ "  else echo FILE; fi\n"
							+ "else echo MISSING\n"
							+ "fi"
							var jobs = {}
							for (var k in pendingJobs)
								jobs[k] = pendingJobs[k]
								jobs[cmd] = u
								pendingJobs = jobs
								zipJobs = zipJobs + 1
								probeRunner.connectSource(cmd)
					}
			}

			function addWebUrl(u) {
				var cmd = detectExtSh
				+ "u=" + shellQuote(u) + "\n"
				+ "cache=" + cacheDirSh() + "\n"
				+ "h=$(printf %s \"$u\" | md5sum | cut -c1-8)\n"
				+ "d=\"$cache/web-$h\"\n"
				+ "mkdir -p \"$d\"\n"
				+ "base=$(basename \"${u%%[?#]*}\")\n"
				+ "case \"$base\" in ''|'/'|'.'|'..') base=image;; esac\n"
				+ "out=\"$d/$base\"\n"
				+ "if curl -Lsf --max-time 90 -o \"$out\" -- \"$u\" 2>/dev/null"
				+ " || wget -q -T 90 -O \"$out\" \"$u\" 2>/dev/null; then\n"
				+ "  case \"$base\" in\n"
				+ "    *.*) echo \"WEB|||$out\";;\n"
				+ "    *)\n"
				+ "      ext=$(detect_ext \"$out\")\n"
				+ "      if [ -n \"$ext\" ]; then\n"
				+ "        mv -f -- \"$out\" \"$out.$ext\"\n"
				+ "        echo \"WEB|||$out.$ext\"\n"
				+ "      else echo \"WEB|||$out\"; fi;;\n"
				+ "  esac\n"
				+ "else\n"
				+ "  rm -rf \"$d\"\n"
				+ "  echo MISSING\n"
				+ "fi"
				var jobs = {}
				for (var k in pendingJobs)
					jobs[k] = pendingJobs[k]
					jobs[cmd] = u
					pendingJobs = jobs
					zipJobs = zipJobs + 1
					probeRunner.connectSource(cmd)
			}

			function textFileName(t) {
				var name = String(t).trim().split(/\s+/).slice(0, 3).join(" ")
				name = name.replace(/[\/\\:*?"<>|\x00-\x1f]/g, "").trim()
				if (name.length > 40)
					name = name.substring(0, 40).trim()
					if (name.length === 0)
						name = "text"
						return name + ".txt"
			}

			function addText(t) {
				var text = String(t || "")
				if (text.trim().length === 0)
					return
					var cmd = "cache=" + cacheDirSh() + "\n"
					+ "h=$(printf %s " + shellQuote(text) + " | md5sum | cut -c1-8)\n"
					+ "d=\"$cache/txt-$h\"\n"
					+ "mkdir -p \"$d\"\n"
					+ "f=\"$d\"/" + shellQuote(textFileName(text)) + "\n"
					+ "printf '%s\\n' " + shellQuote(text) + " > \"$f\"\n"
					+ "echo \"TXT|||$f\""
					var jobs = {}
					for (var k in pendingJobs)
						jobs[k] = pendingJobs[k]
						jobs[cmd] = ""
						pendingJobs = jobs
						zipJobs = zipJobs + 1
						probeRunner.connectSource(cmd)
			}

			function removeEntry(e) {
				var arr = (plasmoid.configuration.fileList || []).slice()
				var idx = arr.indexOf(String(e))
				if (idx < 0)
					return
					arr.splice(idx, 1)
					plasmoid.configuration.fileList = arr
					if (isSelected(e))
						toggleSelect(e)
						if (hasCacheCopy(e)) {
							var zp = urlToPath(dragUrlOf(e))
							if (zp.length > 0)
								cleanupRunner.connectSource("zp=" + shellQuote(zp)
								+ "; rm -f \"$zp\"; rmdir \"$(dirname \"$zp\")\" 2>/dev/null")
						}
			}

			property int copiedFlash: 0
			Timer {
				id: copiedTimer
				interval: 1500
				onTriggered: root.copiedFlash = 0
			}
			function copySelected() {
				if (selectedCount === 0)
					return
					var uris = selectedDragUrls.join("\n") + "\n"
					cleanupRunner.connectSource("printf %s " + shellQuote(uris)
					+ " | { wl-copy -t text/uri-list 2>/dev/null"
					+ " || xclip -selection clipboard -t text/uri-list 2>/dev/null; }")
					copiedFlash = selectedCount
					copiedTimer.restart()
			}

			// Ctrl+V: paste from clipboard — file URIs become shelf entries,
			// plain text becomes a .txt file
			function pasteClipboard() {
				pasteRunner.connectSource(
					"uris=$(wl-paste -n -t text/uri-list 2>/dev/null"
					+ " || xclip -selection clipboard -o -t text/uri-list 2>/dev/null)\n"
					+ "if [ -n \"$uris\" ]; then printf 'URIS\\n%s\\n' \"$uris\"\n"
					+ "else\n"
					+ "  txt=$(wl-paste -n -t text 2>/dev/null"
					+ " || xclip -selection clipboard -o 2>/dev/null)\n"
					+ "  [ -n \"$txt\" ] && printf 'TEXT\\n%s\\n' \"$txt\"\n"
					+ "fi")
			}

			P5Support.DataSource {
				id: pasteRunner
				engine: "executable"
				connectedSources: []
				onNewData: (source, data) => {
					disconnectSource(source)
					var out = String(data["stdout"] || "")
					if (out.indexOf("URIS\n") === 0) {
						root.addUrls(out.substring(5).trim().split(/\r?\n/)
							.filter(u => u.length > 0))
					} else if (out.indexOf("TEXT\n") === 0) {
						root.addText(out.substring(5).replace(/\n$/, ""))
					}
				}
			}

			property var sizeMap: ({})
			property var sizeJobs: ({})

			readonly property double totalBytes: {
				var t = 0
				for (var i = 0; i < files.length; i++) {
					var v = sizeMap[dragUrlOf(files[i])]
					if (v > 0)
						t += v
				}
				return t
			}

			function humanSize(b) {
				if (b === undefined || b < 0)
					return ""
					if (b < 1024) return b + " B"
						if (b < 1024 * 1024) return (b / 1024).toFixed(1) + " KB"
							if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1) + " MB"
								return (b / 1024 / 1024 / 1024).toFixed(2) + " GB"
			}

			onFilesChanged: refreshSizes()
			Component.onCompleted: refreshSizes()

			function refreshSizes() {
				if (files.length === 0) {
					sizeMap = ({})
					return
				}
				var urls = files.map(e => dragUrlOf(e))
				var cmd = ""
				for (var i = 0; i < urls.length; i++)
					cmd += "stat -Lc %s -- " + shellQuote(urlToPath(urls[i]))
					+ " 2>/dev/null || echo -1\n"
					var jobs = {}
					for (var k in sizeJobs)
						jobs[k] = sizeJobs[k]
						jobs[cmd] = urls
						sizeJobs = jobs
						sizeRunner.connectSource(cmd)
			}

			P5Support.DataSource {
				id: sizeRunner
				engine: "executable"
				connectedSources: []
				onNewData: (source, data) => {
					disconnectSource(source)
					var snap = root.sizeJobs[source]
					if (snap === undefined)
						return
						var jobs = {}
						for (var k in root.sizeJobs)
							if (k !== source)
								jobs[k] = root.sizeJobs[k]
								root.sizeJobs = jobs
								var lines = ((data["stdout"] || "")).trim().split("\n")
								var m = {}
								for (var i = 0; i < snap.length && i < lines.length; i++)
									m[snap[i]] = parseInt(lines[i])
									root.sizeMap = m
				}
			}

			property var arkJobs: ({})
			property bool arkWaiting: false

			function sendToArk() {
				var entries = files.filter(e => selectedCount === 0 || isSelected(e))
				var paths = []
				for (var i = 0; i < entries.length; i++) {
					var e = entries[i]
					// folders go as originals (the folder itself is archived);
					// cache-backed entries go as their staged copy (has the
					// proper name/extension)
					var p = urlToPath(isDirEntry(e) ? origUrlOf(e) : dragUrlOf(e))
					if (p.length > 0)
						paths.push(p)
				}
				if (paths.length === 0)
					return
					// Files are first hard-linked/copied flat into a staging
					// dir and Ark archives THAT, so the archive contains just
					// the files — no parent paths like ".cache/…" inside.
					// The finished archive is moved next to the first
					// non-cache file (or to $HOME).
					var cmd = "cache=" + cacheDirSh() + "; mkdir -p \"$cache\"\n"
						+ "stage=$(mktemp -d \"$cache/ark-stage.XXXXXX\")\n"
						+ "dest=\"\"\n"
						+ "for p in " + paths.map(p => shellQuote(p)).join(" ") + "; do\n"
						+ "  case \"$p\" in \"$cache\"/*) ;; *) [ -z \"$dest\" ] && dest=$(dirname \"$p\");; esac\n"
						+ "  b=$(basename \"$p\"); t=\"$stage/$b\"; i=1\n"
						+ "  while [ -e \"$t\" ]; do t=\"$stage/${i}_$b\"; i=$((i+1)); done\n"
						+ "  ln -- \"$p\" \"$t\" 2>/dev/null || cp -a -- \"$p\" \"$t\"\n"
						+ "done\n"
						+ "[ -z \"$dest\" ] && dest=\"$HOME\"\n"
						+ "m=$(mktemp \"$stage/.marker.XXXXXX\")\n"
						+ "ark --add --dialog \"$stage\"/* >/dev/null 2>&1\n"
						+ "out=$(find \"$stage\" -maxdepth 1 -type f -newer \"$m\" "
						+ "\\( -name '*.zip' -o -name '*.7z' -o -name '*.tar' -o -name '*.tar.*' -o -name '*.tgz' \\) "
						+ "-printf '%T@|%p\\n' 2>/dev/null | sort -nr | head -1 | cut -d'|' -f2-)\n"
						+ "if [ -n \"$out\" ]; then\n"
						+ "  n=$(basename \"$out\"); f=\"$dest/$n\"; i=1\n"
						+ "  while [ -e \"$f\" ]; do f=\"$dest/${i}_$n\"; i=$((i+1)); done\n"
						+ "  mv -- \"$out\" \"$f\" && printf %s \"$f\"\n"
						+ "fi\n"
						+ "rm -rf \"$stage\""
						var jobs = {}
						for (var k in arkJobs)
							jobs[k] = arkJobs[k]
							jobs[cmd] = entries
							arkJobs = jobs
							arkWaiting = true
							arkRunner.connectSource(cmd)
			}

			function replaceWithArchive(entries, archivePath) {
				var archiveUrl = pathToUrl(archivePath)
				var removeSet = {}
				for (var i = 0; i < entries.length; i++)
					removeSet[String(entries[i])] = true
					var arr = (plasmoid.configuration.fileList || []).slice()
					var kept = []
					for (var j = 0; j < arr.length; j++) {
						var e = String(arr[j])
						if (removeSet[e] !== true) {
							kept.push(e)
							continue
						}
						if (hasCacheCopy(e)) {
							var zp = urlToPath(dragUrlOf(e))
							if (zp.length > 0)
								cleanupRunner.connectSource("zp=" + shellQuote(zp)
								+ "; rm -f \"$zp\"; rmdir \"$(dirname \"$zp\")\" 2>/dev/null")
						}
					}
					if (kept.indexOf(archiveUrl) < 0)
						kept.push(archiveUrl)
						plasmoid.configuration.fileList = kept
						clearSelection()
			}

			P5Support.DataSource {
				id: arkRunner
				engine: "executable"
				connectedSources: []
				onNewData: (source, data) => {
					disconnectSource(source)
					var entries = root.arkJobs[source]
					var jobs = {}
					for (var k in root.arkJobs)
						if (k !== source)
							jobs[k] = root.arkJobs[k]
							root.arkJobs = jobs
							root.arkWaiting = false
							if (entries === undefined)
								return
								var archivePath = (data["stdout"] || "").trim()
								if (archivePath.length > 0)
									root.replaceWithArchive(entries, archivePath)
				}
			}

			function clearAll() {
				plasmoid.configuration.fileList = []
				clearSelection()
				cleanupRunner.connectSource("rm -rf " + cacheDirSh())
			}

			P5Support.DataSource {
				id: probeRunner
				engine: "executable"
				connectedSources: []
				onNewData: (source, data) => {
					disconnectSource(source)
					var orig = root.pendingJobs[source]
					if (orig === undefined)
						return
						var jobs = {}
						for (var k in root.pendingJobs)
							if (k !== source)
								jobs[k] = root.pendingJobs[k]
								root.pendingJobs = jobs
								root.zipJobs = Math.max(0, root.zipJobs - 1)

								var out = (data["stdout"] || "").trim()
								if (out.indexOf("DIR|||") === 0) {
									var zipPath = out.substring(6)
									root.pushEntry(root.pathToUrl(zipPath) + "|||" + orig)
								} else if (out.indexOf("REN|||") === 0) {
									var renPath = out.substring(6)
									root.pushEntry(root.pathToUrl(renPath) + "|||" + orig + "|||ren")
								} else if (out.indexOf("WEB|||") === 0) {
									root.pushEntry(root.pathToUrl(out.substring(6)) + "|||" + orig + "|||web")
								} else if (out.indexOf("TXT|||") === 0) {
									var txtUrl = root.pathToUrl(out.substring(6))
									root.pushEntry(txtUrl + "|||" + txtUrl + "|||txt")
								} else if (out === "FILE") {
									root.pushEntry(orig)
								}
				}
			}

			P5Support.DataSource {
				id: cleanupRunner
				engine: "executable"
				connectedSources: []
				onNewData: (source, data) => disconnectSource(source)
			}

			function fileName(u) {
				var s = String(u)
				try { s = decodeURIComponent(s) } catch (e) { }
				s = s.replace(/\/+$/, "")
				return s.substring(s.lastIndexOf("/") + 1)
			}

			function extOf(u) {
				var n = fileName(u).toLowerCase()
				var d = n.lastIndexOf(".")
				return d > 0 ? n.substring(d + 1) : ""
			}

			function isImage(u) {
				return ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"]
				.indexOf(extOf(u)) >= 0
			}

			function iconFor(u) {
				var e = extOf(u)
				if (e === "") return "unknown"
					if (isImage(u)) return "image-x-generic"
						if (["mp4", "mkv", "webm", "avi", "mov", "m4v"].indexOf(e) >= 0) return "video-x-generic"
							if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].indexOf(e) >= 0) return "audio-x-generic"
								if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) >= 0) return "application-zip"
									if (e === "pdf") return "application-pdf"
										if (["doc", "docx", "odt", "rtf"].indexOf(e) >= 0) return "x-office-document"
											if (["xls", "xlsx", "ods", "csv"].indexOf(e) >= 0) return "x-office-spreadsheet"
												if (["ppt", "pptx", "odp"].indexOf(e) >= 0) return "x-office-presentation"
													if (["html", "htm"].indexOf(e) >= 0) return "text-html"
														if (["sh", "py", "js", "qml", "cpp", "c", "h", "rs", "go", "json", "xml"].indexOf(e) >= 0) return "text-x-script"
															if (["txt", "md", "log"].indexOf(e) >= 0) return "text-x-generic"
																if (["iso", "img"].indexOf(e) >= 0) return "application-x-cd-image"
																	return "text-x-generic"
			}

			Timer {
				id: autoCloseTimer
				interval: 900
				onTriggered: {
					if (root.autoOpened && !root.dragOut) {
						root.expanded = false
						root.autoOpened = false
					}
				}
			}

			readonly property rect screenGeom: {
				var c = Plasmoid.containment
				return c && c.screenGeometry !== undefined
				? c.screenGeometry : Qt.rect(0, 0, 1920, 1080)
			}

			PlasmaCore.Dialog {
				id: edgeZone
				visible: plasmoid.configuration.edgeOpen === true
				location: PlasmaCore.Types.Floating
				flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
				backgroundHints: PlasmaCore.Types.NoBackground
				hideOnWindowDeactivate: false

				readonly property string edge: plasmoid.configuration.edgeOpenEdge || "right"
				readonly property bool horiz: edge === "top" || edge === "bottom"
				readonly property int thick: 6
				readonly property rect sg: root.screenGeom

				x: horiz ? sg.x + Math.round((sg.width - mainItem.width) / 2)
				: (edge === "left" ? sg.x : sg.x + sg.width - thick)
				y: horiz ? (edge === "top" ? sg.y : sg.y + sg.height - thick)
				: sg.y + Math.round((sg.height - mainItem.height) / 2)

				mainItem: Item {
					width: edgeZone.horiz ? Math.round(edgeZone.sg.width * 0.9) : edgeZone.thick
					height: edgeZone.horiz ? edgeZone.thick : Math.round(edgeZone.sg.height * 0.9)

					DnD.DropArea {
						id: edgeDrop
						anchors.fill: parent
						property bool hovering: false
						onDragEnter: {
							hovering = true
							autoCloseTimer.stop()
							root.autoOpened = true
							root.expanded = true
						}
						onDragLeave: hovering = false
						onDrop: event => {
							hovering = false
							if (event.mimeData.urls && event.mimeData.urls.length > 0)
								root.addUrls(event.mimeData.urls)
								else if (event.mimeData.text && event.mimeData.text.length > 0)
									root.addText(event.mimeData.text)
						}
					}

					// invisible while idle — highlighted only when a drag
					// approaches, so no stray line is left on screen
					Rectangle {
						anchors.fill: parent
						color: Kirigami.Theme.highlightColor
						opacity: edgeDrop.hovering ? 0.8 : 0
					}
				}
			}

			preferredRepresentation: compactRepresentation

			compactRepresentation: MouseArea {
				id: compact
				hoverEnabled: true
				// panels size applets by the Layout attached properties of
				// the compact representation, not by implicitWidth
				readonly property int wantedWidth: plasmoid.configuration.hoverWidth > 0
				? plasmoid.configuration.hoverWidth
				: Kirigami.Units.iconSizes.medium
				implicitWidth: wantedWidth
				implicitHeight: Kirigami.Units.iconSizes.medium
				Layout.minimumWidth: wantedWidth
				Layout.preferredWidth: wantedWidth
				Layout.maximumWidth: wantedWidth

				onClicked: {
					root.autoOpened = false
					root.expanded = !root.expanded
				}
				onEntered: { autoCloseTimer.stop(); hoverExpandTimer.restart() }
				onExited:  { hoverExpandTimer.stop(); autoCloseTimer.restart() }

				Timer {
					id: hoverExpandTimer
					interval: 300
					onTriggered: {
						if (!root.expanded) {
							root.autoOpened = true
							root.expanded = true
						}
					}
				}

				readonly property bool stripMode: plasmoid.configuration.stripMode === true

				Kirigami.Icon {
					visible: !compact.stripMode
					anchors.centerIn: parent
					width: Math.min(parent.width, parent.height)
					height: width
					source: plasmoid.configuration.panelIcon || "document-multiple"
					active: compact.containsMouse
				}

				// вид «полоска»: тонкая белая линия сверху и белый градиент,
				// затухающий вниз на ~30 px (как белая тень). Затухание — по
				// плавной кривой (несколько промежуточных стопов), реакция на
				// наведение анимирована.
				Item {
					visible: compact.stripMode
					anchors.fill: parent

					// содержимое полоски (рисуется через маску краёв ниже)
					Item {
						id: stripContent
						anchors.fill: parent
						visible: false

						Rectangle {
							anchors.top: parent.top
							anchors.left: parent.left
							anchors.right: parent.right
							height: Math.min(30, parent.height)
							opacity: compact.containsMouse ? 1 : 0.7
							Behavior on opacity {
								NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
							}
							gradient: Gradient {
								GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0.45) }
								GradientStop { position: 0.15; color: Qt.rgba(1, 1, 1, 0.30) }
								GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.16) }
								GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.08) }
								GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.03) }
								GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
							}
						}

						// линия без резкой кромки: собственный микроградиент,
						// растворяющийся в основное затухание
						Rectangle {
							anchors.top: parent.top
							anchors.left: parent.left
							anchors.right: parent.right
							height: 4
							opacity: compact.containsMouse ? 1 : 0.8
							Behavior on opacity {
								NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
							}
							gradient: Gradient {
								GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.95) }
								GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.55) }
								GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
							}
						}
					}

					// маска: плавное растворение полоски у левого и правого краёв
					Rectangle {
						id: stripMask
						anchors.fill: parent
						visible: false
						gradient: Gradient {
							orientation: Gradient.Horizontal
							GradientStop { position: 0.00; color: "transparent" }
							GradientStop { position: 0.18; color: "white" }
							GradientStop { position: 0.82; color: "white" }
							GradientStop { position: 1.00; color: "transparent" }
						}
					}

					Effects.OpacityMask {
						anchors.fill: parent
						source: stripContent
						maskSource: stripMask
					}
				}

				Rectangle {
					visible: root.count > 0
					anchors.right: parent.right
					anchors.top: parent.top
					height: badgeText.implicitHeight + 2
					width: Math.max(height, badgeText.implicitWidth + 6)
					radius: height / 2
					color: Kirigami.Theme.highlightColor
					Text {
						id: badgeText
						anchors.centerIn: parent
						text: root.count
						color: Kirigami.Theme.highlightedTextColor
						font.pixelSize: Kirigami.Theme.smallFont.pixelSize
						font.bold: true
					}
				}

				DnD.DropArea {
					anchors.fill: parent
					preventStealing: true
					onDragEnter: {
						autoCloseTimer.stop()
						root.autoOpened = true
						root.expanded = true
					}
					onDrop: event => {
						if (event.mimeData.urls && event.mimeData.urls.length > 0)
							root.addUrls(event.mimeData.urls)
							else if (event.mimeData.text && event.mimeData.text.length > 0)
								root.addText(event.mimeData.text)
					}
				}
			}

			fullRepresentation: Item {
				id: fullRep

				Layout.preferredWidth: Kirigami.Units.gridUnit * 18
				Layout.preferredHeight: Kirigami.Units.gridUnit * 20
				Layout.minimumWidth: Kirigami.Units.gridUnit * 14
				Layout.minimumHeight: Kirigami.Units.gridUnit * 10

				focus: true
				Keys.onPressed: event => {
					if (event.matches(StandardKey.SelectAll)) {
						root.selectAll()
						event.accepted = true
					} else if (event.matches(StandardKey.Copy)) {
						root.copySelected()
						event.accepted = true
					} else if (event.matches(StandardKey.Paste)) {
						root.pasteClipboard()
						event.accepted = true
					}
				}
				Connections {
					target: root
					function onExpandedChanged() {
						if (root.expanded)
							fullRep.forceActiveFocus()
					}
				}

				HoverHandler {
					onHoveredChanged: hovered ? autoCloseTimer.stop() : autoCloseTimer.restart()
				}

				DnD.DropArea {
					id: popupDrop
					anchors.fill: parent
					preventStealing: true
					property bool hovering: false
					onDragEnter: { hovering = true; autoCloseTimer.stop() }
					onDragLeave: hovering = false
					onDrop: event => {
						hovering = false
						if (event.mimeData.urls && event.mimeData.urls.length > 0)
							root.addUrls(event.mimeData.urls)
							else if (event.mimeData.text && event.mimeData.text.length > 0)
								root.addText(event.mimeData.text)
					}
				}

				Rectangle {
					anchors.fill: parent
					radius: 6
					visible: popupDrop.hovering
					color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
					border.width: 2
					border.color: Kirigami.Theme.highlightColor
					z: 100
				}

				ColumnLayout {
					anchors.fill: parent
					anchors.margins: Kirigami.Units.smallSpacing
					spacing: Kirigami.Units.smallSpacing

					RowLayout {
						Layout.fillWidth: true
						spacing: Kirigami.Units.smallSpacing

						PC3.Label {
							Layout.fillWidth: true
							text: root.copiedFlash > 0
							? "Copied: " + root.copiedFlash
							: (root.count === 0 ? "File Shelf"
							: (root.selectedCount > 0
							? "Selected: " + root.selectedCount + " of " + root.count
							: "Files: " + root.count))
							font.bold: true
							elide: Text.ElideRight
						}

						PC3.ToolButton {
							visible: root.count > 0
							icon.name: root.selectedCount === root.count && root.count > 0
							? "edit-select-none" : "edit-select-all"
							text: root.selectedCount === root.count && root.count > 0
							? "Deselect All" : "Select All"
							PC3.ToolTip.text: "Clicking a row also selects the file"
							PC3.ToolTip.visible: hovered
							PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
							onClicked: root.selectedCount === root.count
							? root.clearSelection() : root.selectAll()
						}

						PC3.ToolButton {
							visible: root.count > 0
							icon.name: "utilities-file-archiver"
							PC3.ToolTip.text: root.selectedCount > 0
							? "Pack selected into archive (Ark, support for passwords)"
							: "Pack all into archive (Ark, support for passwords)"
							PC3.ToolTip.visible: hovered
							PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
							onClicked: root.sendToArk()
						}

						PC3.ToolButton {
							visible: root.count > 0
							icon.name: "edit-clear-all"
							PC3.ToolTip.text: "Clear shelf"
							PC3.ToolTip.visible: hovered
							PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
							onClicked: root.clearAll()
						}
					}

					RowLayout {
						visible: root.zipJobs > 0 || root.arkWaiting
						Layout.fillWidth: true
						spacing: Kirigami.Units.smallSpacing
						PC3.BusyIndicator {
							Layout.preferredWidth: Kirigami.Units.iconSizes.small
							Layout.preferredHeight: Kirigami.Units.iconSizes.small
							running: parent.visible
						}
						PC3.Label {
							Layout.fillWidth: true
							text: root.zipJobs > 0
							? "Processing added file..."
							: "Ark is open — files will be replaced by the archive after creation"
							opacity: 0.7
						}
					}

					PlasmaExtras.PlaceholderMessage {
						visible: root.count === 0 && root.zipJobs === 0
						Layout.fillWidth: true
						Layout.fillHeight: true
						iconName: "document-import"
						text: "Shelf is empty"
						explanation: "Drag files or folders here. Folders will be automatically zipped."
					}

					ListView {
						id: listView
						visible: root.count > 0
						Layout.fillWidth: true
						Layout.fillHeight: true
						clip: true
						model: root.files
						spacing: 2
						interactive: false

						PC3.ScrollBar.vertical: PC3.ScrollBar { id: vScroll }

						WheelHandler {
							target: null
							onWheel: ev => {
								var max = Math.max(0, listView.contentHeight - listView.height)
								listView.contentY = Math.max(0, Math.min(max,
																		 listView.contentY - ev.angleDelta.y))
							}
						}

						delegate: Item {
							id: itemDrag
							required property var modelData
							readonly property string dragUrl: root.dragUrlOf(modelData)
							readonly property string origUrl: root.origUrlOf(modelData)
							readonly property string kind: root.kindOf(modelData)
							readonly property bool isDir: kind === "dir"
							readonly property bool selected: root.isSelected(modelData)
							readonly property bool dragsGroup: root.selectedCount > 0
							readonly property string uriList:
							(dragsGroup ? root.selectedDragUrls : [dragUrl]).join("\r\n")

							width: ListView.view ? ListView.view.width : 0
							height: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2

							Rectangle {
								anchors.fill: parent
								radius: 4
								color: itemDrag.selected
								? Qt.alpha(Kirigami.Theme.highlightColor, 0.3)
								: (rowMa.containsMouse
								? Qt.alpha(Kirigami.Theme.highlightColor, 0.15)
								: "transparent")
							}

							MouseArea {
								id: rowMa
								anchors.fill: parent
								hoverEnabled: true
								drag.target: dragProxy
								drag.onActiveChanged: dragProxy.Drag.active = rowMa.drag.active
								onClicked: root.toggleSelect(itemDrag.modelData)
								onPressed: itemDrag.grabToImage(result => {
									dragProxy.Drag.imageSource = result.url
								})
							}

							Item {
								id: dragProxy
								anchors.fill: parent
								Drag.dragType: Drag.Automatic
								Drag.supportedActions: Qt.CopyAction
								Drag.hotSpot.x: 0
								Drag.hotSpot.y: 0
								Drag.mimeData: ({ "text/uri-list": itemDrag.uriList })
								Drag.onDragStarted: root.dragOut = true
								Drag.onDragFinished: {
									root.dragOut = false
									autoCloseTimer.restart()
								}
							}

							RowLayout {
								anchors.fill: parent
								anchors.leftMargin: Kirigami.Units.smallSpacing
								anchors.rightMargin: Kirigami.Units.smallSpacing
								spacing: Kirigami.Units.smallSpacing

								PC3.CheckBox {
									checked: itemDrag.selected
									onToggled: root.toggleSelect(itemDrag.modelData)
								}

								Item {
									Layout.preferredWidth: Kirigami.Units.iconSizes.medium
									Layout.preferredHeight: Kirigami.Units.iconSizes.medium
									Image {
										anchors.fill: parent
										visible: !itemDrag.isDir && root.isImage(itemDrag.dragUrl)
										source: visible ? itemDrag.dragUrl : ""
										fillMode: Image.PreserveAspectCrop
										asynchronous: true
										sourceSize.width: Kirigami.Units.iconSizes.medium * 2
										sourceSize.height: Kirigami.Units.iconSizes.medium * 2
									}
									Kirigami.Icon {
										anchors.fill: parent
										visible: itemDrag.isDir || !root.isImage(itemDrag.dragUrl)
										source: itemDrag.isDir ? "folder-tar" : root.iconFor(itemDrag.dragUrl)
									}
								}

								ColumnLayout {
									Layout.fillWidth: true
									spacing: 0
									PC3.Label {
										Layout.fillWidth: true
										text: itemDrag.kind === "file"
										? root.fileName(itemDrag.origUrl)
										: root.fileName(itemDrag.dragUrl)
										elide: Text.ElideMiddle
									}
									PC3.Label {
										Layout.fillWidth: true
										readonly property string sizeStr:
										root.humanSize(root.sizeMap[itemDrag.dragUrl])
										text: (sizeStr.length > 0 ? sizeStr + "  ·  " : "")
										+ (itemDrag.kind === "dir"
										? "Folder archive: " + root.urlToPath(itemDrag.origUrl)
										: itemDrag.kind === "ren"
										? "Was without extension: " + root.urlToPath(itemDrag.origUrl)
										: itemDrag.kind === "txt"
										? "Created from dragged text"
										: itemDrag.kind === "web"
										? "Downloaded: " + itemDrag.origUrl
										: root.urlToPath(itemDrag.origUrl))
										elide: Text.ElideMiddle
										font.pixelSize: Kirigami.Theme.smallFont.pixelSize
										opacity: 0.6
									}
								}

								PC3.ToolButton {
									icon.name: "document-open"
									visible: rowMa.containsMouse
									PC3.ToolTip.text: "Open"
									PC3.ToolTip.visible: hovered
							PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
									onClicked: Qt.openUrlExternally(itemDrag.origUrl)
								}

								PC3.ToolButton {
									icon.name: "edit-delete-remove"
									opacity: rowMa.containsMouse ? 1 : 0.4
									PC3.ToolTip.text: "Remove from shelf"
									PC3.ToolTip.visible: hovered
							PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
									onClicked: root.removeEntry(itemDrag.modelData)
								}
							}
						}
					}

					PC3.Label {
						visible: root.count > 0 && root.totalBytes > 0
						Layout.fillWidth: true
						horizontalAlignment: Text.AlignRight
						text: "Total: " + root.humanSize(root.totalBytes)
						font.pixelSize: Kirigami.Theme.smallFont.pixelSize
						opacity: 0.45
					}
				}
			}
}
