import SafariServices

enum ActionType: String {
    case openLinkInTab
    case openNewTab
    case tabForward
    case tabBackward
    case closeTab
    case updateSettings
}

enum InputAction: String {
    case openSettings
    case resetSettings
}

enum TabDirection: String {
    case forward
    case backward
}

func mod(_ a: Int, _ n: Int) -> Int {
    // https://stackoverflow.com/questions/41180292/negative-number-modulo-in-swift
    precondition(n > 0, "modulus must be positive")
    let r = a % n
    return r >= 0 ? r : r + n
}

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    private enum Constant {
        static let settingsFileName = "defaultSettings"
        static let userSettingsFileName = "userSettings"
    }
    
    private func getActivePage(completionHandler: @escaping (SFSafariPage?) -> Void) {
        SFSafariApplication.getActiveWindow {
            $0?.getActiveTab {
                $0?.getActivePage(completionHandler: completionHandler)
            }
        }
    }
    
    override func messageReceivedFromContainingApp(withName messageName: String, userInfo: [String : Any]? = nil) {
        do {
            
        }
        switch InputAction(rawValue: messageName) {
        case .openSettings:
            editConfigFile()
        case .resetSettings:
            resetConfigFile()
        default:
            NSLog("Input not supported " + messageName)
        }
    }
    
    private func updateSettings() {
        do {
            let settingsData = try Bundle.main.getJSONData(from: Constant.settingsFileName)
            let settings = try settingsData.toJSONObject()
            getActivePage {
                $0?.dispatch(settings: settings)
            }
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String: Any]?) {
        guard let action = ActionType(rawValue: messageName) else {
            NSLog("Received message with unsupported type: \(messageName)")
            return
        }

        NSLog("Received message: \(messageName)")
        switch action {
        case .openLinkInTab:
            let url = URL(string: userInfo?["url"] as! String)
            openInNewTab(url: url!)
        case .openNewTab:
            openNewTab()
        case .tabForward:
            changeTab(withDirection: .forward, from: page)
        case .tabBackward:
            changeTab(withDirection: .backward, from: page)
        case .closeTab:
            closeTab(from: page)
        case .updateSettings:
            updateSettings()
        }
    }

    override func toolbarItemClicked(in _: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
        NSLog("The extension's toolbar item was clicked")
        NSWorkspace.shared.launchApplication("Vimari")
    }

    override func validateToolbarItem(in _: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        NSLog("Validate?")
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
    private func openInNewTab(url: URL) {
        SFSafariApplication.getActiveWindow { activeWindow in
            activeWindow?.openTab(with: url, makeActiveIfPossible: false, completionHandler: { _ in
                // Perform some action here after the page loads
            })
        }
    }

    private func openNewTab() {
        // Ideally this URL would be something that represents an empty tab better than localhost
        let url = URL(string: "http://localhost")!
        SFSafariApplication.getActiveWindow { activeWindow in
            activeWindow?.openTab(with: url, makeActiveIfPossible: true, completionHandler: { _ in
                // Perform some action here after the page loads
            })
        }
    }

    private func changeTab(withDirection direction: TabDirection, from page: SFSafariPage, completionHandler: (() -> Void)? = nil ) {
        page.getContainingTab(completionHandler: { currentTab in
            currentTab.getContainingWindow(completionHandler: { window in
                window?.getAllTabs(completionHandler: { tabs in
                    if let currentIndex = tabs.firstIndex(of: currentTab) {
                        let indexStep = direction == TabDirection.forward ? 1 : -1

                        // Wrap around the ends with a modulus operator.
                        // % calculates the remainder, not the modulus, so we need a
                        // custom function.
                        let newIndex = mod(currentIndex + indexStep, tabs.count)
    
                        tabs[newIndex].activate(completionHandler: completionHandler ?? {})
                        
                    }
                })
            })
        })
    }
    
    private func closeTab(from page: SFSafariPage) {
        page.getContainingTab {
            tab in
            tab.close()
        }
    }
    
    private func editConfigFile() {
        do {
            let settingsFilePath = try findOrCreateUserSettings()
            NSWorkspace.shared.openFile(settingsFilePath, withApplication: "TextEdit")
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    private func resetConfigFile() {
        do {
            let settingsFilePath = try overwriteUserSettings()
            NSWorkspace.shared.openFile(settingsFilePath, withApplication: "TextEdit")
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    private func findOrCreateUserSettings() throws -> String {
        let url = FileManager.documentDirectoryURL
            .appendingPathComponent(Constant.userSettingsFileName)
            .appendingPathExtension("json")
        let urlString = url.path
        if FileManager.default.fileExists(atPath: urlString) {
            return urlString
        }
        let data = try Bundle.main.getJSONData(from: Constant.settingsFileName)
        try data.write(to: url)
        return urlString
    }
    
    private func overwriteUserSettings() throws -> String {
        let url = FileManager.documentDirectoryURL
            .appendingPathComponent(Constant.userSettingsFileName)
            .appendingPathExtension("json")
        let urlString = url.path
        let data = try Bundle.main.getJSONData(from: Constant.settingsFileName)
        try data.write(to: url)
        return urlString
    }
}

enum DataError: Error {
    case unableToParse
    case notFound
}

extension Data {
    func toJSONObject() throws -> [String: Any] {
        let serialized = try JSONSerialization.jsonObject(with: self, options: [])
        guard let result = serialized as? [String: Any] else {
            throw DataError.unableToParse
        }
        return result
    }
}

extension Bundle {
    func getJSONPath(for file: String) throws -> String {
        guard let result = self.path(forResource: file, ofType: ".json") else {
            throw DataError.notFound
        }
        return result
    }
    
    func getJSONData(from file: String) throws -> Data {
        let settingsPath = try self.getJSONPath(for: file)
        let urlSettingsFile = URL(fileURLWithPath: settingsPath)
        return try Data(contentsOf: urlSettingsFile)
    }
}

extension SFSafariPage {
    func dispatch(settings: [String: Any]) {
        self.dispatchMessageToScript(
            withName: "updateSettingsEvent",
            userInfo: settings
        )
    }
}


extension FileManager {
    static var documentDirectoryURL: URL {
        let documentDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return documentDirectoryURL
    }
}
