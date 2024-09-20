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
    var clientDelegateTaskHandle: TaskHandle?
    var sendQueueListenerTaskHandle: TaskHandle?
    var listUpdatesSubscriptionResult: RoomListEntriesWithDynamicAdaptersResult?
    var stateUpdatesTaskHandle: TaskHandle?
    
    @Published var syncService: SyncService?
    @Published var roomListService: RoomListService?
    @Published var rooms: [RoomSummary] = []
    
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
        self.clientDelegateTaskHandle =  self.client.setDelegate(delegate: self)
        Task {
            self.syncService = try await client.syncService().finish()
            await syncService?.start()
            roomListService = self.syncService?.roomListService()
            self.sendQueueListenerTaskHandle = client.subscribeToSendQueueStatus(listener: self)
            let roomList = try await roomListService?.allRooms()
            self.listUpdatesSubscriptionResult = roomList?.entriesWithDynamicAdapters(pageSize: UInt32(200), listener: self)
            let stateUpdatesSubscriptionResult = try roomList?.loadingState(listener: self)
            stateUpdatesTaskHandle = stateUpdatesSubscriptionResult?.stateStream
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
        let updatedRooms = roomEntriesUpdate.reduce(rooms) { currentItems, diff in
            processDiff(diff, on: currentItems)
        }
        Task { @MainActor in
            self.rooms = updatedRooms
        }
        
    }
    private func processDiff(_ diff: RoomListEntriesUpdate, on currentItems: [RoomSummary]) -> [RoomSummary] {
        guard let collectionDiff = buildDiff(from: diff, on: currentItems) else {
            return currentItems
        }

        guard let updatedItems = currentItems.applying(collectionDiff) else {
            return currentItems
        }

        return updatedItems
    }
    private func buildDiff(from diff: RoomListEntriesUpdate, on rooms: [RoomSummary]) -> CollectionDifference<RoomSummary>? {
        var changes = [CollectionDifference<RoomSummary>.Change]()

        switch diff {
        case .append(let values):
            for (index, value) in values.enumerated() {
                let summary = buildRoomSummary(from: value)
                changes.append(.insert(offset: rooms.count + index, element: summary, associatedWith: nil))
            }
        case .clear:
            for (index, value) in rooms.enumerated() {
                changes.append(.remove(offset: index, element: value, associatedWith: nil))
            }
        case .insert(let index, let value):
            let summary = buildRoomSummary(from: value)
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
            let summary = buildRoomSummary(from: value)
            changes.append(.insert(offset: rooms.count, element: summary, associatedWith: nil))
        case .pushFront(let value):
            let summary = buildRoomSummary(from: value)
            changes.append(.insert(offset: 0, element: summary, associatedWith: nil))
        case .remove(let index):
            let summary = rooms[Int(index)]
            changes.append(.remove(offset: Int(index), element: summary, associatedWith: nil))
        case .reset(let values):
            for (index, summary) in rooms.enumerated() {
                changes.append(.remove(offset: index, element: summary, associatedWith: nil))
            }

            for (index, value) in values.enumerated() {
                changes.append(.insert(offset: index, element: buildRoomSummary(from: value), associatedWith: nil))
            }
        case .set(let index, let value):
            let summary = buildRoomSummary(from: value)
            changes.append(.remove(offset: Int(index), element: summary, associatedWith: nil))
            changes.append(.insert(offset: Int(index), element: summary, associatedWith: nil))
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
    
    private func buildRoomSummary(from roomListItem: RoomListItem) -> RoomSummary {
        let roomDetails = fetchRoomDetails(from: roomListItem)

        guard let roomInfo = roomDetails.roomInfo else {
            fatalError("Missing room info for \(roomListItem.id())")
        }

        let attributedLastMessage: AttributedString? = nil
        let lastMessageFormattedTimestamp: String? = nil

        //  if let latestRoomMessage = roomDetails.latestEvent {
        //    let lastMessage = EventTimelineItemProxy(item: latestRoomMessage, id: "0")
        //    lastMessageFormattedTimestamp = lastMessage.timestamp.formattedMinimal()
        //    attributedLastMessage = eventStringBuilder.buildAttributedString(for: lastMessage)
        //  }

        //  var inviterProxy: RoomMemberProxyProtocol?
        //  if let inviter = roomInfo.inviter {
        //    inviterProxy = RoomMemberProxy(member: inviter)
        //  }

        // MARK: - modified

        //  let notificationMode = roomInfo.userDefinedNotificationMode.flatMap { RoomNotificationModeProxy.from(roomNotificationMode: $0) }

        return RoomSummary(roomListItem: roomListItem,
                           id: roomInfo.id,
                           isInvite: roomInfo.membership == .invited,
                           //                     inviter: inviterProxy,
                           name: roomInfo.displayName ?? roomInfo.id,
                           isDirect: roomInfo.isDirect,
                           avatarURL: roomInfo.avatarUrl.flatMap(URL.init(string:)),
                           //                     heroes: [], // MARK - modified
                           lastMessage: attributedLastMessage,
                           lastMessageFormattedTimestamp: lastMessageFormattedTimestamp,
                           unreadMessagesCount: UInt(roomInfo.numUnreadMessages),
                           unreadMentionsCount: UInt(roomInfo.numUnreadMentions),
                           unreadNotificationsCount: UInt(roomInfo.numUnreadNotifications),
                           //                     notificationMode: .none, // MARK - modified
                           canonicalAlias: roomInfo.canonicalAlias,
                           hasOngoingCall: roomInfo.hasRoomCall,
                           isMarkedUnread: roomInfo.isMarkedUnread,
                           isFavourite: roomInfo.isFavourite)
    }
    
    private func fetchRoomDetails(from roomListItem: RoomListItem) -> (roomInfo: RoomInfo?, latestEvent: EventTimelineItem?) {
        class FetchResult {
            var roomInfo: RoomInfo?
            var latestEvent: EventTimelineItem?
        }

        let semaphore = DispatchSemaphore(value: 0)
        let result = FetchResult()

        Task {
            do {
                result.latestEvent = await roomListItem.latestEvent()
                result.roomInfo = try await roomListItem.roomInfo()
            } catch {}
            semaphore.signal()
        }
        semaphore.wait()
        return (result.roomInfo, result.latestEvent)
    }

}

extension MatrixManager: @preconcurrency RoomListLoadingStateListener {
    func onUpdate(state: MatrixRustSDK.RoomListLoadingState) {
        print("Received state update: \(state)")
        if state != .notLoaded {
            print("state loaded")

            self.listUpdatesSubscriptionResult?.controller().resetToOnePage()
            _ = self.listUpdatesSubscriptionResult?.controller().setFilter(kind: .all(filters: [.nonLeft]))
        }
    }
    
    
}
