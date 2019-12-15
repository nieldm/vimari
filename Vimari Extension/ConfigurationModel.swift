//
//  ConfigurationModel.swift
//  Vimari Extension
//
//  Created by Daniel Mendez on 12/15/19.
//  Copyright © 2019 net.televator. All rights reserved.
//

protocol ConfigurationModelProtocol {
    func editConfigFile() throws
    func resetConfigFile() throws
    func getSettings() throws -> [String: Any]
}

import Foundation
import SafariServices

class ConfigurationModel: ConfigurationModelProtocol {
    
    private enum Constant {
        static let settingsFileName = "defaultSettings"
        static let userSettingsFileName = "userSettings"
        static let defaultEditor = "TextEdit"
    }
    
    func editConfigFile() throws {
        let settingsFilePath = try findOrCreateUserSettings()
        NSWorkspace.shared.openFile(
            settingsFilePath,
            withApplication: Constant.defaultEditor
        )
    }
    
    func resetConfigFile() throws {
        let settingsFilePath = try overwriteUserSettings()
        NSWorkspace.shared.openFile(
            settingsFilePath,
            withApplication: Constant.defaultEditor
        )
    }
    
    func getSettings() throws -> [String : Any] {
        let settingsData = try Bundle.main.getJSONData(from: Constant.settingsFileName)
        return try settingsData.toJSONObject()
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

private extension Data {
    func toJSONObject() throws -> [String: Any] {
        let serialized = try JSONSerialization.jsonObject(with: self, options: [])
        guard let result = serialized as? [String: Any] else {
            throw DataError.unableToParse
        }
        return result
    }
}

private extension Bundle {
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

private extension FileManager {
    static var documentDirectoryURL: URL {
        let documentDirectoryURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        return documentDirectoryURL
    }
}
