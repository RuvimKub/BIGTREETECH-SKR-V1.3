import Cocoa

// Host app: only exists so macOS registers the Quick Look extensions inside it.
let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

let alert = NSAlert()
alert.messageText = "F3D Quick Look installed"
alert.informativeText = "Select a .f3d file in Finder and press Space.\nYou can quit and delete nothing: the extensions live inside this app, so keep it in Applications."
alert.addButton(withTitle: "OK")
alert.runModal()
