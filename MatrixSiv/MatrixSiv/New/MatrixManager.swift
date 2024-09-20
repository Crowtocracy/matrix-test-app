//
//  MatrixManager.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//
@preconcurrency import MatrixRustSDK
import Foundation
import CryptoKit

@MainActor class MatrixManager: ObservableObject {
    let client: Client
    static let homeserver = "crowtocracy.etke.host"

    static func restoreSession() async -> Client? {
        print("restoring session")
        guard let session = Session.getFromUserDefaults() else {
            print("no session. proceeding to login")
            return nil
        }
        do {
            print("building client")
            let newClient = try await ClientBuilder()
                .sessionPath(path: URL.applicationSupportDirectory.path() + Date.now.description)
                .serverNameOrHomeserverUrl(serverNameOrUrl: session.homeserverUrl)
                .build()

            print("restore session")
            try await newClient.restoreSession(session: session)
            try newClient.session().setToUserDefaults()
            print("session restored")
            return newClient
        } catch {
            print("ERROR: unable to restore session")
            return nil
        }
    }
    
    static func loginUser(username: String) async -> Client? {
        do {
            print("building client")
            let newClient = try await ClientBuilder()
                .sessionPath(path: URL.applicationSupportDirectory.path() + Date.now.description)
                .serverNameOrHomeserverUrl(serverNameOrUrl: homeserver)
                .build()
            print("logging in user")
            guard !username.isEmpty, let password = generatePassword(username: username) else {
                fatalError("Username or password is not set in the env variables")
            }
            try await newClient.login(username: username, password: password, initialDeviceName: nil, deviceId: nil)
            let session = try newClient.session()
            session.setToUserDefaults()
            return newClient
        } catch {
            print("ERROR: cannot login \(error)")
        }
        return nil
    }
    
    static func generatePassword(username: String) -> String? {
        guard let secret = ProcessInfo.processInfo.environment["CROWTOCRACY_SECRET"] else {
            return nil
        }
        
        let encodedUsername = Data(username.utf8)
        let encodedSecret = Data(secret.utf8)
        
        var combinedData = Data()
        combinedData.append(encodedUsername)
        combinedData.append(encodedSecret)
        
        let hashedData = SHA256.hash(data: combinedData)
        let hashedString = hashedData.map { String(format: "%02hhx", $0) }.joined()
        
        return hashedString
    }
    
    func logout() async throws {
        do {
            _ = try await client.logout()
            Session.clearFromUserDefaults()
        } catch {
            print("Error: Unable to logout: \(error.localizedDescription)")
            throw error
        }
    }
    
    init(client: Client) {
        self.client = client
    }
}
