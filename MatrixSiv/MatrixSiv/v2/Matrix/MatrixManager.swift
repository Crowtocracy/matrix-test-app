//
//  MatrixManager.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/14/25.
//

import Foundation
import MatrixRustSDK
import Combine
import UIKit

@MainActor @Observable final class MatrixManager {
    static let shared: MatrixManager = MatrixManager()
    
    private(set) var client: Client? = nil
    private var clientDelegateTaskHandle: TaskHandle? = nil
    
    private var syncService: SyncService? = nil
    private var syncStateTaskHandle: TaskHandle? = nil
    
    private var roomListService: RoomListService? = nil
    
    private var roomListEntriesResult: RoomListEntriesWithDynamicAdaptersResult? = nil
    private var roomListEntriesResultTaskHandle: TaskHandle? = nil
    private var roomListEntriesResultEntriesStream: TaskHandle? = nil
    
    
    private var stateUpdatesTaskHandle: TaskHandle? = nil
    
    var cancellables = Set<AnyCancellable>()
    
    var roomManagersDict: [String: RoomManager] = [:]
    
    var rooms: [SivRoom] = []
    var rawRooms: [Room] = []
    var emptyRooms: [SivRoom] = []
    
    var rawRoomListItems: [RoomListItem] = []
    var roomUpdateToggle: Bool = false
    
    init() {
    }
    
    func isUserId(id: String) -> Bool {
        guard let userId = try? client?.userId() else {
            return false
        }
        return userId == id
    }
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

    
    func logout() async {
        do {
            try await client?.logout()
            self.client = nil
            self.clientDelegateTaskHandle = nil
            self.syncService = nil
            self.syncStateTaskHandle = nil
            
            self.roomListService = nil
            roomListEntriesResult = nil
            roomListEntriesResultTaskHandle = nil
            
            
            stateUpdatesTaskHandle = nil
            
            cancellables = Set<AnyCancellable>()
            
            roomManagersDict = [:]
            
             rooms = []
             rawRooms = []
             emptyRooms = []
        } catch {
            print("Error logging out: \(error)")
        }
        
    }
    
    func getData(avatar: String) async -> UIImage? {
        do {
            let data = try await client?.getMediaContent(mediaSource: .fromUrl(url: avatar))
            let uiimage = UIImage(data: data!)
            return uiimage
        } catch {
            print("error getting avatar \(error)")
            return nil
        }
    }
    func getRoomManager(roomId: String) async -> RoomManager? {
        if let existing =  roomManagersDict[roomId] {
            return existing
        }
        do {
            let roomListItem = await getRoomListItem(roomId: roomId)
            let roomInfo = try await roomListItem?.roomInfo()
            let room = await roomListItem?.convertToSivRoom()
            if let room, let roomListItem, let roomInfo {
                let manager = RoomManager(sivRoom: room, roomListItem: roomListItem, roomInfo: roomInfo)
                try await manager.setup()
                roomManagersDict[roomId] = manager
                return manager
            } else {
                return nil
            }
        } catch {
            print("Unable to get roomManager \(roomId)")
            return nil
        }
    
    }
    
    func loadClient() async throws {
        guard self.client != nil else {
            return
        }
        clientDelegateTaskHandle = client?.setDelegate(delegate: self)
        syncService = try await client?.syncService().finish()
        await syncService?.start()
        roomListService = syncService?.roomListService()
        syncStateTaskHandle = syncService?.state(listener: self)
        let roomList = try await roomListService?.allRooms()
        roomListEntriesResult = roomList?.entriesWithDynamicAdapters(pageSize: 20, listener: self)
        _ = roomListEntriesResult?.controller().setFilter(kind: .unread)
        roomListEntriesResultEntriesStream = roomListEntriesResult?.entriesStream()
        let stateUpdatesSubscriptionResult = try roomList?.loadingState(listener: self)
        stateUpdatesTaskHandle = stateUpdatesSubscriptionResult?.stateStream
        
        await client?.enableAllSendQueues(enable: true)
        
        try await Task.sleep(for: .seconds(3))
        
        await refreshRooms()
        
    }
    
    
    func joinRoom(roomId: String) async -> Room? {
        guard let client = client else {
            fatalError("Client not set up yet")
        }
        do {
            return try await client.joinRoomById(roomId: roomId)
        } catch {
            print("Error joining room: \(error)")
            return nil
            
        }
    }
    
    func getOrCreateDMRoom(userId: String) async -> Room? {
        do {
            // check if there's already a dm with the user
            let room = try  self.client?.getDmRoom(userId: userId)
            if let room {
                return room
            }
            let roomId = try await self.client!.createRoom(request: .init(name: nil, isEncrypted: false, isDirect: true, visibility: .private, preset: .trustedPrivateChat, invite: [userId]))
            return try self.client!.getDmRoom(userId: userId)
        } catch {
            print("Error getting DM room \(error)")
        }
        return nil
    }
    
    func createDM(userId: String, initialMessage: String) async -> RoomManager? {
        let room = await getOrCreateDMRoom(userId: userId)
        guard let room else { return nil }
        let roomManager = await getRoomManager(roomId: room.id())
        if let message = initialMessage.nullableTrimmed {
            await roomManager?.sendPlainMessage(message: message, parentMessage: nil)
        }
        return roomManager
    }
    
    func createRoom(roomName: String, topic: String?, userIds: [String], initialMessage: String) async -> RoomManager? {
        do {
            let roomId = try await MatrixManager.shared.client?.createRoom(request: .init(name: roomName, topic: topic, isEncrypted: false, visibility: .private, preset: .privateChat, invite: userIds))
            guard let roomId else { return nil }
            let roomManager = await getRoomManager(roomId: roomId)
            if let message = initialMessage.nullableTrimmed {
                await roomManager?.sendPlainMessage(message: message, parentMessage: nil)
            }
            return roomManager
        } catch {
            print("Error creating room: \(error)")
            return nil
        }
    }
    func refreshRooms() async -> [SivRoom]{
        // filter to show joined rooms only
        rawRooms = client?.rooms() ?? []
        rooms = await getRooms()
        
        print("rooms: \(rooms.count)")
        return rooms
    }
    
    func getRooms() async -> [SivRoom]  {
        
       
        let rawRooms = client?.rooms() ?? []
        print("raw rooms: \(rawRooms.count)")
        let updatedRooms = await withTaskGroup(of:SivRoom.self , returning: [SivRoom].self) { group in
            
            for room in rawRooms {
                group.addTask {
                    await room.convertToSivRoom()
                }
                
            }
            var rooms : [SivRoom] = []
            for await result in group {
                rooms.append(result)
            }
            return rooms
        }
        Task {
            do {
                try roomListService?.subscribeToRooms(roomIds: updatedRooms.map({ $0.id }))
                print("successfully subscribed to rooms")
            } catch {
                print("unable to subscribe to rooms: \(error)")
            }
            
        }
        
        return updatedRooms
    }
    
    func getRoomListItem(roomId: String, persitent: Bool = true) async -> RoomListItem? {
        guard let roomListService else { return nil }
        
        do {
            let roomListItem = try roomListService.room(roomId: roomId)
            return roomListItem
        } catch {
            print("Error getting roomListItem: \(error)")
            try? await Task.sleep(for: .seconds(2))
            return await getRoomListItem(roomId: roomId)
        }
    }
    
    
    
}
extension MatrixManager: @preconcurrency RoomListEntriesListener {
    func onUpdate(roomEntriesUpdate: [MatrixRustSDK.RoomListEntriesUpdate]) {
        var updatedRooms: [RoomListItem] = rawRoomListItems
        var changes = [CollectionDifference<MatrixRustSDK.RoomListItem>.Change]()
        for update in roomEntriesUpdate {
            switch update {
            case .append(let values):
                for (index, item) in values.enumerated() {
                    changes.append(.insert(offset: updatedRooms.count + index, element: item, associatedWith: nil))
                }
            case .clear:
                for (index, item) in updatedRooms.enumerated() {
                    changes.append(.remove(offset: index, element: item, associatedWith: nil))
                }
            case .pushFront(let value):
                changes.append(.insert(offset: 0, element: value, associatedWith: nil))
            case .pushBack(let value):
                changes.append(.insert(offset: updatedRooms.count, element: value, associatedWith: nil))
            case .insert(let index, let value):
                changes.append(.insert(offset: Int(index), element: value, associatedWith: nil))
            case .set(let index, let value):
                changes.append(.remove(offset: Int(index), element: value, associatedWith: nil))
                changes.append(.insert(offset: Int(index), element: value, associatedWith: nil))
            case .remove(let index):
                changes.append(.remove(offset: Int(index), element: updatedRooms[Int(index)], associatedWith: nil))
            case .truncate(_):
                break
            case .reset(let values):
                for (index, item) in updatedRooms.enumerated() {
                    changes.append(.remove(offset: index, element: item, associatedWith: nil))
                }
                for (index, item) in values.enumerated() {
                    changes.append(.insert(offset: index, element: item, associatedWith: nil))
                }
            default:
                break
            }
        }
        let diff = CollectionDifference(changes)
        if let diff {
            updatedRooms = updatedRooms.applying(diff) ?? []
        } else {
            print("🔴 Failed to apply diff")
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.roomUpdateToggle.toggle()
            self?.rawRoomListItems = updatedRooms
        }
    }
    
}

extension MatrixManager: @preconcurrency ClientDelegate {
    func didReceiveAuthError(isSoftLogout: Bool) {
        print("received auth error")
    }
    
    func didRefreshTokens() {
        print("token refreshed")
    }

}
extension MatrixManager: @preconcurrency SyncServiceStateObserver {
    func onUpdate(state: MatrixRustSDK.SyncServiceState) {
        print("Sync state updated: \(state)")
        rawRooms = client?.rooms() ?? []
    }
}

extension MatrixManager: @preconcurrency RoomListLoadingStateListener {
    func onUpdate(state: MatrixRustSDK.RoomListLoadingState) {
        print("RoomListLoadingState updated: \(state)")
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
            print("Successfully restored session")
        } catch {
            print("Error restoring session: \(error)")
        }
        
        
        
    }
}

struct SivRoom: Identifiable {
    let id: String
    let avatarUrl: String?
    let displayName: String
    var isDirect: Bool = false
    let room: Room?
    let membersCount: Int
    var membership: Membership = .invited
    let isEmpty: Bool = false
    var isMarkedUnread = true
    
//    init(room: Room) {
//        self.id = room.id()
//        self.avatarUrl = room.avatarUrl()
//        self.displayName = room.displayName() ?? "no name"
//        self.room = room
//    }
//    func getOtherDetails() {
//        Task {
//            isDirect = await room.isDirect()
//        }
//    }
}

extension Room {
    func convertToSivRoom() async -> SivRoom {
            let isDirect = await self.isDirect()
            let membersCount = try? await self.members().len()
            return SivRoom(
                id: self.id(),
                avatarUrl: self.avatarUrl(),
                displayName: self.displayName() ?? "no name",
                isDirect: isDirect,
                room: self,
                membersCount: Int(membersCount ?? 0)
            )
    }
    func convertToBasicSivRoom() -> SivRoom {
        return SivRoom(
            id: self.id(),
            avatarUrl: self.avatarUrl(),
            displayName: self.displayName() ?? "no name",
            isDirect: false,
            room: self,
            membersCount: 0
        )
    }
    
    
}

extension RoomListItem {
    func convertToSivRoom() async -> SivRoom {
        let isDirect = await self.isDirect()
        let room = try?  self.fullRoom()
        var isMarkedUnread: Bool = true
        
        do {
            let roomInfo = try await self.roomInfo()
            isMarkedUnread = roomInfo.isMarkedUnread
        } catch {
            print("unable to retrieve roominfo")
        }
        return SivRoom(
            id: self.id(),
            avatarUrl: self.avatarUrl(),
            displayName: self.displayName() ?? "",
            isDirect: isDirect,
            room: room,
            membersCount: 0,
            membership: self.membership(),
            isMarkedUnread: isMarkedUnread
        )
    }
    
    func convertToBasicSivRoom() -> SivRoom {
//        let isDirect = await self.isDirect()
        let room = try?  self.fullRoom()
        var isMarkedUnread: Bool = true
        return SivRoom(
            id: self.id(),
            avatarUrl: self.avatarUrl(),
            displayName: self.displayName() ?? "",
            isDirect: false,
            room: room,
            membersCount: 0,
            membership: self.membership(),
            isMarkedUnread: isMarkedUnread
        )
    }
}

extension EventTimelineItem {
    func getMessage() -> String? {
            switch self.content {
            case .msgLike(let content):
                return content.getMessage()
            case .callInvite:
                return "Call Invite"
            case .callNotify:
                return "Call Notify"
            case .roomMembership(let userId, let userDisplayName, let change, let reason):
                return "\(userDisplayName ?? userId) \(change.debugDescription)"
    //        )
    //        case .profileChange(displayName: String?, prevDisplayName: String?, avatarUrl: String?, prevAvatarUrl: String?
    //        )
    //        case .state(stateKey: String, content: OtherState
    //        )
    //        case .failedToParseMessageLike(eventType: String, error: String
    //        )
    //        case .failedToParseState(eventType: String, stateKey: String, error: String
    //        )
            default:
                return nil
            }
        }
    
    func generateSivMessage(previousMessage: SivMessage? = nil) -> SivMessage {
        var message: String? = nil
        var reactions: [Reaction] = []
        var parentId: String? = nil
        
        switch self.content {
        case .msgLike(let content):
            message = content.getMessage()
            reactions = content.reactions
            parentId = content.inReplyTo?.eventId()
        default:
            break
        }
        
        var newAvatar: String? = ""
        var newName = ""
        switch self.senderProfile {
        case .ready(let displayName, _, let avatarUrl):
            newAvatar = avatarUrl
            newName = displayName?.nullableTrimmed ?? "?"
        default:
            break
        }
        return SivMessage(id: self.eventOrTransactionId.getIdString(), message: message ?? "", timestamp: self.timestamp, parentId: parentId, avatarURL: newAvatar, senderName: newName, reactions: reactions)
    }
}

extension MsgLikeContent {
    func getMessage() -> String? {
        switch kind {
        case .message(let content):
            return content.body
        default:
            return nil
        }
    }
}

extension EventOrTransactionId {
    func getIdString() -> String {
        switch self {
        case .eventId(let eventId):
            return eventId
        case .transactionId(let transactionId):
            return transactionId
        }
    }
}
