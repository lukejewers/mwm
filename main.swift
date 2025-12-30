import Carbon
import Cocoa

enum LayoutState {
    case fullscreen, twoPane
}

var currentLayoutState: LayoutState = .fullscreen
var isSwapped: Bool = false

enum AppConfig: UInt32, CaseIterable {
    case emacs, firefox, ghostty, messages
    case moveLeft, moveRight, maximize, centre
    case layoutFull, layoutSplit

    var keyCode: UInt32 {
        switch self {
        case .emacs:       return UInt32(kVK_ANSI_J)
        case .firefox:     return UInt32(kVK_ANSI_K)
        case .ghostty:     return UInt32(kVK_ANSI_L)
        case .messages:    return UInt32(kVK_ANSI_M)
        case .moveLeft:    return UInt32(kVK_LeftArrow)
        case .moveRight:   return UInt32(kVK_RightArrow)
        case .maximize:    return UInt32(kVK_UpArrow)
        case .centre:      return UInt32(kVK_DownArrow)
        case .layoutFull:  return UInt32(kVK_ANSI_F)
        case .layoutSplit: return UInt32(kVK_ANSI_E)
        }
    }

    var bundleID: String? {
        switch self {
        case .emacs:    return "org.gnu.Emacs"
        case .firefox:  return "org.mozilla.firefox"
        case .ghostty:  return "com.mitchellh.ghostty"
        case .messages: return "com.apple.MobileSMS"
        default:        return nil
        }
    }

    var isPopup: Bool {
        return [.messages].contains(self)
    }
}

func moveFocusedWindow(toUnit unit: CGRect) {
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return }
    let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
    var focusedWindow: CFTypeRef?

    let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
    guard result == .success, let window = focusedWindow as! AXUIElement? else { return }

    guard let screen = NSScreen.main else { return }
    let visibleFrame = screen.visibleFrame
    let fullFrame = screen.frame

    let newWidth = visibleFrame.width * unit.size.width
    let newHeight = visibleFrame.height * unit.size.height
    let newX = visibleFrame.origin.x + (visibleFrame.width * unit.origin.x)
    let cocoaY = visibleFrame.origin.y + (visibleFrame.height * unit.origin.y)
    let newY = fullFrame.height - cocoaY - newHeight

    var position = CGPoint(x: newX, y: newY)
    var size = CGSize(width: newWidth, height: newHeight)

    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &position)!)
    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &size)!)
}

func openAndActivate(app: AppConfig) {
    guard let bundleID = app.bundleID else { return }
    let workspace = NSWorkspace.shared

    if let runningApp = workspace.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
        if runningApp.isActive && app.isPopup {
            runningApp.hide()
        } else {
            runningApp.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if app.isPopup {
                    moveFocusedWindow(toUnit: CGRect(x: 0.19, y: 0.19, width: 0.62, height: 0.62))
                } else if currentLayoutState == .fullscreen {
                    moveFocusedWindow(toUnit: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
            }
        }
    } else if let url = workspace.urlForApplication(withBundleIdentifier: bundleID) {
        workspace.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if app.isPopup { moveFocusedWindow(toUnit: CGRect(x: 0.19, y: 0.19, width: 0.62, height: 0.62)) }
            }
        }
    }
}

func switchLayouts(to state: LayoutState) {
    if state == .twoPane {
        if currentLayoutState == .twoPane { isSwapped.toggle() }
        else { currentLayoutState = .twoPane; isSwapped = false }

        let left = CGRect(x: 0, y: 0, width: 0.5, height: 1)
        let right = CGRect(x: 0.5, y: 0, width: 0.5, height: 1)

        openAndActivate(app: .firefox)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            moveFocusedWindow(toUnit: isSwapped ? left : right)
            openAndActivate(app: .emacs)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                moveFocusedWindow(toUnit: isSwapped ? right : left)
            }
        }
    } else {
        currentLayoutState = .fullscreen
        moveFocusedWindow(toUnit: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}

func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    GetEventParameter(event, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

    if let app = AppConfig(rawValue: hotKeyID.id) {
        switch app {
        case .moveLeft:    moveFocusedWindow(toUnit: CGRect(x: 0, y: 0, width: 0.5, height: 1))
        case .moveRight:   moveFocusedWindow(toUnit: CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        case .maximize:    moveFocusedWindow(toUnit: CGRect(x: 0, y: 0, width: 1, height: 1))
        case .centre:      moveFocusedWindow(toUnit: CGRect(x: 0.19, y: 0.19, width: 0.62, height: 0.62))
        case .layoutFull:  switchLayouts(to: .fullscreen)
        case .layoutSplit: switchLayouts(to: .twoPane)
        default:           openAndActivate(app: app)
        }
    }
    return noErr
}

func bind(app: AppConfig) {
    var hotKeyRef: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: 0, id: app.rawValue)
    let modifiers = UInt32(cmdKey | controlKey)
    RegisterEventHotKey(app.keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
}

func checkAccessibilityPermissions() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
    if !accessEnabled {
        print("Access not enabled. Opening System Settings...")
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
var eventSpec = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))]
InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventSpec, nil, nil)
for config in AppConfig.allCases {
    bind(app: config)
}
checkAccessibilityPermissions()
app.run()
