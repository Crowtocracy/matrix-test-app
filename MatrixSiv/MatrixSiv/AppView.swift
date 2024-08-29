//
//  AppView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/13/24.
//

import SwiftUI
import MatrixRustSDK
import Combine

enum AppLoginState {
    case loggedIn, withSession, toLogin
}
struct AppView: View {
    @State var client: Client?
    @State var listener: ClientListener?
//    @State var rooms: [RoomListItem] = []
    @State var rooms: [RoomSummary] = []
    private let diffsPublisher = PassthroughSubject<[RoomListEntriesUpdate], Never>()
    private let serialDispatchQueue: DispatchQueue = DispatchQueue(label: "siv.siv.siv", qos: .default)
    private let sendQueueStatusSubject = CurrentValueSubject<Bool, Never>(false)
    @State var delegateHandle: TaskHandle?
    @State var stateUpdatesTaskHandle: TaskHandle?
    @State var sendQueueListenerTaskHandle: TaskHandle?
    @State var roomListService: RoomListService?
    @State var syncService: SyncService?
    @State var loginState: AppLoginState = .withSession

  @State var cancellables = Set<AnyCancellable>()
    var body: some View {
        Text("Hello?")
            .task(id: (client == nil).description) {
                if let client {
                    loginState = .loggedIn
                }
            }
        if loginState != .loggedIn {
            Button("Logout") {
                Task {
                    guard let client else {
                        print("Failed to logout")
                        return
                    }
                    do {
                        let _ = try await client.logout()
                        print("Successfully logged out")
                    } catch {
                        print("ERROR: Failed to logout \(error)")
                    }
                    Session.clearFromUserDefaults()
                    self.client = nil
                    loginState = .toLogin
                    
                    
                }
            }
        }
        
        Button("Try refresh?") {
            Task {
                _ = try? await roomListService?.allRooms().entriesWithDynamicAdapters(pageSize: UInt32(200), listener: RoomListEntriesListenerProxy { updates in
                  diffsPublisher.send(updates)
    //                            updateRoomsWithDiffs(updates)
                })
            }
            
        }
        
        if let client, loginState == .loggedIn {
          Home(client: client, rooms: $rooms)
        } else if loginState == .withSession {
            Text("Trying to restore session...")
                .task {
                    if let newClient = await restoreSession() {
                        loginState = .loggedIn
                        client = newClient
                    } else {
                        loginState = .toLogin
                    }
                }
        } else {
            AuthView(client: $client)
        }
    }
    
    func restoreSession() async -> Client? {
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
            print("session restored")
            return newClient
        } catch {
            print("ERROR: unable to restore session")
            return nil
        }
    }


  func updateRoomsWithDiffs(_ diffs: [RoomListEntriesUpdate]) {
    rooms = diffs.reduce(rooms) { currentItems, diff in
        processDiff(diff, on: currentItems)
    }
//    .filter({ summary in
//        do {
//            return try summary.roomListItem.fullRoom().joinedMembersCount() > 0
//        } catch {
//            return true
//        }
//        
//    })
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
      } catch {

      }
      semaphore.signal()
    }
    semaphore.wait()
    return (result.roomInfo, result.latestEvent)
  }

  private func buildRoomSummary(from roomListItem: RoomListItem) -> RoomSummary {
    let roomDetails = fetchRoomDetails(from: roomListItem)

    guard let roomInfo = roomDetails.roomInfo else {
      fatalError("Missing room info for \(roomListItem.id())")
    }

    var attributedLastMessage: AttributedString?
    var lastMessageFormattedTimestamp: String?

    //  if let latestRoomMessage = roomDetails.latestEvent {
    //    let lastMessage = EventTimelineItemProxy(item: latestRoomMessage, id: "0")
    //    lastMessageFormattedTimestamp = lastMessage.timestamp.formattedMinimal()
    //    attributedLastMessage = eventStringBuilder.buildAttributedString(for: lastMessage)
    //  }

    //  var inviterProxy: RoomMemberProxyProtocol?
    //  if let inviter = roomInfo.inviter {
    //    inviterProxy = RoomMemberProxy(member: inviter)
    //  }

    // MARK - modified
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

    func login() async throws -> Client? {
        /// get uniqueish date string
        let dateStr = Date.now.description

        let client = try await ClientBuilder()
            .sessionPath(path: URL.applicationSupportDirectory.path() + dateStr)
            .serverNameOrHomeserverUrl(serverNameOrUrl: "matrix.org")
            .build()
        
        if let session = Session.getFromUserDefaults() {
            do {
                print("restore session")
                try await client.restoreSession(session: session)
                print("session restored")
            } catch {
                print("ERROR: unable to restore session")
                try await freshLogin()
            }
            
        } else {
            try await freshLogin()
        }
        func freshLogin() async throws {
            print("logging in user")
            let username = ProcessInfo.processInfo.environment["MUSERNAME"]
            let password = ProcessInfo.processInfo.environment["MPASSWORD"]
            guard let username, let password else {
                fatalError("Username or password is not set in the env variables")
            }
            try await client.login(username: username, password: password, initialDeviceName: nil, deviceId: nil)
            let session = try client.session()
            session.setToUserDefaults()
            
        }
        
        return client
    }	

  class ClientListener: ClientDelegate {
    var client: Client
    init(client: Client
    ) {
      self.client = client
    }

    func didRefreshTokens() {
      print("Tokens refreshed")
    }

    func didReceiveSyncUpdate() {
//      self.rooms = self.client.rooms()
      print("didrecievesyncupdate")
    }

    func didReceiveAuthError(isSoftLogout: Bool) {
      // Ask the user to reauthenticate.
    }

    func didUpdateRestoreToken() {
      let session = try? client.session()
        session?.setToUserDefaults()
      // Update the session in the keychain.
    }
  }

  private class RoomListEntriesListenerProxy: RoomListEntriesListener {
    private let onUpdateClosure: ([RoomListEntriesUpdate]) -> Void

    init(_ onUpdateClosure: @escaping ([RoomListEntriesUpdate]) -> Void) {
      self.onUpdateClosure = onUpdateClosure
    }

    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
      onUpdateClosure(roomEntriesUpdate)
    }
  }

  private class RoomListStateObserver: RoomListLoadingStateListener {
    private let onUpdateClosure: (RoomListLoadingState) -> Void

    init(_ onUpdateClosure: @escaping (RoomListLoadingState) -> Void) {
      self.onUpdateClosure = onUpdateClosure
    }

    func onUpdate(state: RoomListLoadingState) {
      onUpdateClosure(state)
    }
  }

  private class SendQueueRoomErrorListenerProxy: SendQueueRoomErrorListener {
    private let onErrorClosure: (String, ClientError) -> Void

    init(onErrorClosure: @escaping (String, ClientError) -> Void) {
      self.onErrorClosure = onErrorClosure
    }

    func onError(roomId: String, error: ClientError) {
      onErrorClosure(roomId, error)
    }
  }

  enum ReachabilityStatus {
    case reachable
    case unreachable
  }

  private class ClientDelegateWrapper: ClientDelegate {
    private let authErrorCallback: (Bool) -> Void

    init(authErrorCallback: @escaping (Bool) -> Void) {
      self.authErrorCallback = authErrorCallback
    }

    // MARK: - ClientDelegate

    func didReceiveAuthError(isSoftLogout: Bool) {
      print("Received authentication error, softlogout=\(isSoftLogout)")
      authErrorCallback(isSoftLogout)
    }

    func didRefreshTokens() {
      print("Delegating session updates to the ClientSessionDelegate.")
    }
  }

}

extension Session: Codable {
    enum CodingKeys: CodingKey {
        case accessToken, refreshToken, userId, deviceId, homeserverUrl, oidcData, slidingSyncProxy
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(homeserverUrl, forKey: .homeserverUrl)
        try container.encode(oidcData, forKey: .oidcData)
        try container.encode(slidingSyncProxy, forKey: .slidingSyncProxy)
    }
    
    public func setToUserDefaults() {
        do {
            let encoded = try JSONEncoder().encode(self)
            UserDefaults.standard.setValue(encoded, forKey: "session")
        } catch {
            print("ERROR: unable to encode to UserDefaults \(error)")
        }
    }
    
    static public func clearFromUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "session")
    }
    static public func getFromUserDefaults() -> Session?  {
        do {
            if let data = UserDefaults.standard.data(forKey: "session") {
                print(data)
                let session = try JSONDecoder().decode(Session.self, from: data)
                return self.init(accessToken: session.accessToken, refreshToken: session.refreshToken, userId: session.userId, deviceId: session.deviceId, homeserverUrl: session.homeserverUrl, oidcData: session.oidcData, slidingSyncProxy: session.slidingSyncProxy)
            }
        } catch {
            print("ERROR: unable to get from UserDefaults")
        }
        return nil
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let accessToken = try container.decode(String.self, forKey: CodingKeys.accessToken)
        let refreshToken = try? container.decode(String.self, forKey: .refreshToken)
        let userId = try container.decode(String.self, forKey: .userId)
        let deviceId = try container.decode(String.self, forKey: .deviceId)
        let homeserverUrl = try container.decode(String.self, forKey: .homeserverUrl)
        let oidcData = try? container.decode(String.self, forKey: .oidcData)
        let slidingSyncProxy = try? container.decode(String.self, forKey: .slidingSyncProxy)
        self.init(accessToken: accessToken, refreshToken: refreshToken, userId: userId, deviceId: deviceId, homeserverUrl: homeserverUrl, oidcData: oidcData, slidingSyncProxy: slidingSyncProxy)
    }
    
    
}

enum SivErrors: Error{
    case SessionError
}

//#Preview {
//    AppView()
//}
