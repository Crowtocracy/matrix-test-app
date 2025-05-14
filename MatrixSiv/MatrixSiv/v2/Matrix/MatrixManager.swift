//
//  MatrixManager.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/14/25.
//

import Foundation
import MatrixRustSDK

@Observable final class MatrixManager {
    static let shared: MatrixManager = MatrixManager()
    
    private var client: Client? = nil
    private var syncService: SyncService? = nil
    private var roomListService: RoomListService? = nil
    
    var rooms: [SivRoom] = []
    
    func isLoggedIn() -> Bool {
        client != nil
    }
    func newLogin(client: Client) {
        self.client = client
        Task {
            do {
                try await loadClient()
            } catch {
                print("Error setting up client: \(error)")
            }
            
        }
    }

    
    func loadClient() async throws {
        guard self.client != nil else {
            return
        }
        
        _ = client?.setDelegate(delegate: nil)
        syncService = try await client?.syncService().finish()
        await syncService?.start()
        
        roomListService = syncService?.roomListService()
        await client?.enableAllSendQueues(enable: true)
        
        try await Task.sleep(for: .seconds(3))
        
//        let rooms = try await roomListService?.allRooms()
        print("We have \(client?.rooms().count ?? 0) rooms")
        rooms = client?.rooms().map({ SivRoom(room: $0) }) ?? []
        
    }
    
    func getRooms() -> [SivRoom] {
        (client?.rooms() ?? []).map({ SivRoom(room: $0) })
    }
    
    
    
}

// MARK: static functions
extension MatrixManager {
    static func login(homeserver: String, email: String, password: String) async -> Client? {
        do {
            let newClient = try await ClientBuilder()
                .slidingSyncVersionBuilder(versionBuilder: .native)
                .serverNameOrHomeserverUrl(serverNameOrUrl: homeserver)
                .build()
            try await newClient.login(username: email, password: password, initialDeviceName: nil, deviceId: nil)
            let session = try newClient.session()
            session.saveToUserDefaults()
            print("Hello \(session.userId)")
            MatrixManager.shared.newLogin(client: newClient)
            return newClient
        } catch {
            print("Error loggin in: \(error)")
            return nil
        }
       
    }
    static func restoreSession(session: Session) async {
        do {
            let newClient = try await ClientBuilder()
                .slidingSyncVersionBuilder(versionBuilder: .native)
                .serverNameOrHomeserverUrl(serverNameOrUrl: session.homeserverUrl)
                .build()
            try await newClient.restoreSession(session: session)
            let session = try newClient.session()
            session.saveToUserDefaults()
            MatrixManager.shared.newLogin(client: newClient)
        } catch {
            print("Error restoring session: \(error)")
        }
        
        
        
    }
}

struct SivRoom: Identifiable {
    let id: String
    let avatarUrl: String?
    let displayName: String
    
    init(room: Room) {
        self.id = room.id()
        self.avatarUrl = room.avatarUrl()
        self.displayName = room.displayName() ?? "no name"
    }
}
