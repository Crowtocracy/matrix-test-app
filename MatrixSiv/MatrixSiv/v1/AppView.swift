//
//  AppView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/13/24.
//

import SwiftUI
import MatrixRustSDK

struct AppView: View {
//    @State var client: Client?
    var body: some View {
        Text("Hello World")
//        if let client {
//            Home(viewModel: HomeViewModel(client: client))
//        } else {
//            Text("Logging In")
//                .task {
//                    do {
//                        client = try await login()
//                    } catch {
//                        print("Error logging in: \(error)")
//                    }
//                }
//                
//        }
    }
    
//    func login() async throws -> Client? {
//        /// get uniqueish date string
//        let dateStr = Date.now.description
//        let service = AuthenticationService(sessionPath: URL.applicationSupportDirectory.path() + dateStr, passphrase: nil, userAgent: nil, additionalRootCertificates: [], proxy: nil, oidcConfiguration: nil, customSlidingSyncProxy: nil, sessionDelegate: nil, crossProcessRefreshLockId: nil)
//        
//        // Configure the service for a particular homeserver.
//        // Note that we can pass a server name (the second part of a Matrix user ID) instead of the direct URL.
//        // This allows the SDK to discover the homeserver's well-known configuration for OIDC and Sliding Sync support.
//        print("comfiguring homeserver")
//        try await service.configureHomeserver(serverNameOrHomeserverUrl: "matrix.org")
//        
//        // Login through the service which creates a client.
//        print("logging in")
//        let username = ProcessInfo.processInfo.environment["MUSERNAME"]
//        let password = ProcessInfo.processInfo.environment["MPASSWORD"]
//        guard let username, let password else {
//            fatalError("Username or password is not set in the env variables")
//        }
//        return try await service.login(username: username, password: password, initialDeviceName: nil, deviceId: nil)
//    }
}

#Preview {
    AppView()
}
