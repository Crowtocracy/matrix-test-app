//
//  HomeViewModel.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/13/24.
//

/*
import Foundation
import MatrixRustSDK
import CryptoKit

class HomeViewModel: ClientDelegate, ObservableObject, RoomListServiceStateListener, RoomListEntriesListener {
    let client: Client
    var rooms: [Room] = []
    var syncService: SyncService?
    var roomListService: RoomListService?
    
    init(client: Client) {
        self.client = client
        
        rooms = client.rooms()
    }
    func setClientDelegate() async throws{
        print("setup")
        _ = client.setDelegate(delegate: self)
        syncService = try await client.syncService().finish()
        roomListService = syncService?.roomListService()
        _ = roomListService?.state(listener: self)
    }
    
    func createRoom() async throws {
        print("creating new room")
        _ = try await client.createRoom(request: CreateRoomParameters(name: "siv-test\(client.session().accessToken)", isEncrypted: false, visibility: .private, preset: .privateChat))
    }
    func sendMessage() async throws {
        print("sending first message")
        guard let room = client.rooms().first else {
            print("No rooms")
            return
        }
        rooms = client.rooms()
        
        _ = """
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
        _ = try await room.timeline().send(msg: htmlMsg)
    }
    func didReceiveAuthError(isSoftLogout: Bool) {
        print("Error authentication")
    }
    
    func didRefreshTokens() {
        print("Tokens refreshed")
    }

    func updateRooms() async throws {
        print("getting roomlist")
        let roomList = try await roomListService?.allRooms()
        let result = roomList?.entries(listener: self)
        print(result?.entries.count ?? 0)
        
    }
    func onUpdate(roomEntriesUpdate: [MatrixRustSDK.RoomListEntriesUpdate]) {
        print(roomEntriesUpdate)
    }
    func onUpdate(state: MatrixRustSDK.RoomListServiceState) {
        print(state)
    }
    
}
*/
