//
//  Home.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/9/24.
//

import SwiftUI
import MatrixRustSDK

/*
struct Home: View {
    @State var clientName: String? = nil
    @StateObject var viewModel: HomeViewModel
    var body: some View {
        Text("Hello, \(clientName == nil ? "World" : clientName ?? "")!" )
            .task {
                do {
                    try await viewModel.setClientDelegate()
                    
                    try await viewModel.updateRooms()
                    try await viewModel.createRoom()
                    try await viewModel.sendMessage()
                } catch {
                    print("Error: \(error)")
                }
            }
//            .task {
//                do {
//                    try await connectToMatrix()
//                } catch {
//                    print("Error: \(error)")
//                }
//                
//            }
    }
    
    func connectToMatrix() async throws {
        /// get uniqueish date string
        let dateStr = Date.now.description
        let service = AuthenticationService(sessionPath: URL.applicationSupportDirectory.path() + dateStr, passphrase: nil, userAgent: nil, additionalRootCertificates: [], proxy: nil, oidcConfiguration: nil, customSlidingSyncProxy: nil, sessionDelegate: nil, crossProcessRefreshLockId: nil)
        
        // Configure the service for a particular homeserver.
        // Note that we can pass a server name (the second part of a Matrix user ID) instead of the direct URL.
        // This allows the SDK to discover the homeserver's well-known configuration for OIDC and Sliding Sync support.
        print("comfiguring homeserver")
        try await service.configureHomeserver(serverNameOrHomeserverUrl: "matrix.org")
        
        // Login through the service which creates a client.
        print("logging in")
        let client = try await service.login(username: "rmcastor", password: "assbutt6969", initialDeviceName: nil, deviceId: nil)

        print("creating new room")
        let newRoom = try await client.createRoom(request: CreateRoomParameters(name: "siv-test\(dateStr)", isEncrypted: false, visibility: .private, preset: .privateChat))
        let rooms = client.rooms()
        print(rooms)
        
        print("sending first message")
        let htmlText = """
            <body>

                <p>This is a paragraph.</p>
                <p>This is another paragraph.</p>

            </body>
        """
        let html2 = """
            <!DOCTYPE html>
            <html>
                <body>

                    <h2>HTML Images</h2>
                    <p>HTML images are defined with the img tag:</p>

                    <img src="w3schools.jpg" alt="W3Schools.com" width="104" height="142">

                </body>
            </html>
        """
        let htmlMsg = messageEventContentFromHtml(body: "Hello ", htmlBody: html2)
        let markdownMsg = messageEventContentFromMarkdown(md: "Hello wazzup from dummy")
        try await rooms.first?.timeline().send(msg: htmlMsg)
        

        
//        let session = try client.session()
        // Store the session in the keychain.
        
//        clientName = try await client.displayName()
    }
}

//#Preview {
//    Home()
//}
*/
