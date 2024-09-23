//
//  MatrixManager.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//
import CryptoKit
import Foundation
@preconcurrency import MatrixRustSDK

@MainActor class MatrixManager: ObservableObject {
    let client: Client
    var clientDelegateTaskHandle: TaskHandle?
    var sendQueueListenerTaskHandle: TaskHandle?
    var listUpdatesSubscriptionResult: RoomListEntriesWithDynamicAdaptersResult?
    var stateUpdatesTaskHandle: TaskHandle?

    @Published var syncService: SyncService?
    @Published var roomListService: RoomListService?
    @Published var rooms: [RoomSummary] = []
    @Published var roomListItems: [RoomListItem] = []

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

    func getClientDisplayName() async -> String? {
        return try? await client.displayName()
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
        self.clientDelegateTaskHandle = self.client.setDelegate(delegate: self)
        Task {
            self.syncService = try await client.syncService().finish()
            await syncService?.start()
            self.roomListService = self.syncService?.roomListService()
            self.sendQueueListenerTaskHandle = client.subscribeToSendQueueStatus(listener: self)
            let roomList = try await roomListService?.allRooms()
            self.listUpdatesSubscriptionResult = roomList?.entriesWithDynamicAdapters(pageSize: UInt32(200), listener: self)
            let stateUpdatesSubscriptionResult = try roomList?.loadingState(listener: self)
            self.stateUpdatesTaskHandle = stateUpdatesSubscriptionResult?.stateStream
        }
    }
}

extension MatrixManager: @preconcurrency ClientDelegate {
    func didReceiveAuthError(isSoftLogout: Bool) {
        print("didReceiveAuthError")
    }

    func didRefreshTokens() {
        print("didRefreshTokens")
    }
}

extension MatrixManager: @preconcurrency SendQueueRoomErrorListener {
    func onError(roomId: String, error: MatrixRustSDK.ClientError) {
        print("Send queue failed in room: \(roomId) with error: \(error)")
        if ReachabilityStatus.reachable == .reachable {
            print("Enabling all send queues")
            Task {
                await client.enableAllSendQueues(enable: true)
            }
        }
    }
}

extension MatrixManager: @preconcurrency RoomListEntriesListener {
    func onUpdate(roomEntriesUpdate: [MatrixRustSDK.RoomListEntriesUpdate]) {
        print("received room list update")
        let updatedRooms = roomEntriesUpdate.reduce(roomListItems) { currentItems, diff in
            processDiffNew(diff, on: currentItems)
        }
        Task { @MainActor in
            self.roomListItems = updatedRooms
        }
    }

    private func processDiffNew(_ diff: RoomListEntriesUpdate, on currentItems: [RoomListItem]) -> [RoomListItem] {
        guard let collectionDiff = buildDiff(from: diff, on: currentItems) else {
            return currentItems
        }

        guard let updatedItems = currentItems.applying(collectionDiff) else {
            return currentItems
        }

        return updatedItems
    }
    
    private func buildDiff(from diff: RoomListEntriesUpdate, on rooms: [RoomListItem]) -> CollectionDifference<RoomListItem>? {
        var changes = [CollectionDifference<RoomListItem>.Change]()

        switch diff {
        case .append(let values):
            for (index, value) in values.enumerated() {
                let summary = value
                changes.append(.insert(offset: rooms.count + index, element: summary, associatedWith: nil))
            }
        case .clear:
            for (index, value) in rooms.enumerated() {
                changes.append(.remove(offset: index, element: value, associatedWith: nil))
            }
        case .insert(let index, let value):
            let summary = value
            changes.append(.insert(offset: Int(index), element: summary, associatedWith: nil))
        case .popBack:
            guard let value = rooms.last else {
                fatalError()
            }

            changes.append(.remove(offset: rooms.count - 1, element: value, associatedWith: nil))
        case .popFront:
            let summary = rooms[0]
            changes.append(.remove(offset: 0, element: summary, associatedWith: nil))
        case .pushBack(let value):
            let summary = value
            changes.append(.insert(offset: rooms.count, element: summary, associatedWith: nil))
        case .pushFront(let value):
            let summary = value
            changes.append(.insert(offset: 0, element: summary, associatedWith: nil))
        case .remove(let index):
            let summary = rooms[Int(index)]
            changes.append(.remove(offset: Int(index), element: summary, associatedWith: nil))
        case .reset(let values):
            for (index, summary) in rooms.enumerated() {
                changes.append(.remove(offset: index, element: summary, associatedWith: nil))
            }

            for (index, value) in values.enumerated() {
                changes.append(.insert(offset: index, element: value, associatedWith: nil))
            }
        case .set(let index, let value):
            changes.append(.remove(offset: Int(index), element: value, associatedWith: nil))
            changes.append(.insert(offset: Int(index), element: value, associatedWith: nil))
        case .truncate(let length):
            for (index, value) in rooms.enumerated() {
                if index < length {
                    continue
                }

                changes.append(.remove(offset: index, element: value, associatedWith: nil))
            }
        }

        return CollectionDifference(changes)
    }

}

extension MatrixManager: @preconcurrency RoomListLoadingStateListener {
    func onUpdate(state: MatrixRustSDK.RoomListLoadingState) {
        print("Received state update: \(state)")
        if state != .notLoaded {
            print("state loaded")

            listUpdatesSubscriptionResult?.controller().resetToOnePage()
            _ = listUpdatesSubscriptionResult?.controller().setFilter(kind: .all(filters: [.nonLeft]))
        }
    }
}

struct SivMatrixRoom: Identifiable {
    let id: String
    let fullRoom: MatrixRustSDK.Room
    let displayName: String?
    let topic: String?
    let alias: String?
    let lastMessage: SivMessage?
}

extension RoomListItem {
    func generateSivMatrixRoom() async throws -> SivMatrixRoom {
        let id = self.id()
        let room = try self.fullRoom()
        let fullRoom = room
        let displayName = self.displayName()
        let topic = room.topic()
        let alias = room.canonicalAlias()
        let roomInfo = try await room.roomInfo()
        var lastMessage: SivMessage? = nil
        if let latestEvent = await self.latestEvent() {
            lastMessage = latestEvent.generateSivMessage()
        }
        
        return SivMatrixRoom(id: id, fullRoom: fullRoom, displayName: displayName, topic: topic, alias: alias, lastMessage: lastMessage)
        

    }
}

extension EventTimelineItem {
    func generateSivMessage() -> SivMessage? {
        guard let id = self.eventId() else { return nil }
        let timestamp = self.timestamp()
        if let message = self.content().asMessage() {
            switch message.msgtype() {
            case .notice(let content):
                return SivMessage(id: id, body: content.body, timestamp: timestamp, formatted: nil, isNotice: true)
            case .text(let content):
                return SivMessage(id: id, body: content.body, timestamp: timestamp, formatted: content.formatted?.body, isNotice: false)
            default:
                print("message is not text or notice")
                break
            }
        }
        return nil
    }
}



struct SivMessage {
    let id: String
    let body: String
    let timestamp: UInt64
    let formatted: String?
    let isNotice: Bool
}
