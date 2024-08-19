//
//  AppView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/13/24.
//

import SwiftUI
import MatrixRustSDK
import Combine

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

  @State var cancellables = Set<AnyCancellable>()
    var body: some View {
        if let client {
          Home(client: client, rooms: $rooms)
        } else {
            Text("Logging In")
                .task {
                    do {
                        client = try await login()
                      if let client {
                        diffsPublisher
                          .receive(on: serialDispatchQueue)
                          .sink { self.updateRoomsWithDiffs($0) }
                          .store(in: &cancellables)

                        delegateHandle = client.setDelegate(delegate: ClientDelegateWrapper { isSoftLogout in
                        })
                        let syncService = try await client.syncService().finish()
                        await syncService.start()

                        let roomListService = syncService.roomListService()

                        let roomList = try await roomListService.allRooms()

                        sendQueueListenerTaskHandle = client.subscribeToSendQueueStatus(listener: SendQueueRoomErrorListenerProxy { roomID, error in
                          print("Send queue failed in room: \(roomID) with error: \(error)")
                          self.sendQueueStatusSubject.send(false)
                        })

                        sendQueueStatusSubject
                        // .combineLatest(networkMonitor.reachabilityPublisher)
                          .combineLatest(Just<ReachabilityStatus>(.reachable))
                          .debounce(for: 1.0, scheduler: DispatchQueue.main)
                          .sink { enabled, reachability in
                            print("Send queue status changed to enabled: \(enabled), reachability: \(reachability)")

                            if enabled == false, reachability == .reachable {
                              print("Enabling all send queues")
                              Task {
                                await client.enableAllSendQueues(enable: true)
                              }
                            }
                          }
                          .store(in: &cancellables)

                        let listUpdatesSubscriptionResult = roomList.entriesWithDynamicAdapters(pageSize: UInt32(200), listener: RoomListEntriesListenerProxy { updates in
                          diffsPublisher.send(updates)
                        })

                          let stateUpdatesSubscriptionResult = try roomList.loadingState(listener: RoomListStateObserver { state in

                            print("Received state update: \(state)")
                            if state != .notLoaded {
                              print("state loaded")

                              listUpdatesSubscriptionResult.controller().resetToOnePage()
                              _ = listUpdatesSubscriptionResult.controller().setFilter(kind: .all(filters: [.nonLeft]))
                            }

                          })
                          stateUpdatesTaskHandle = stateUpdatesSubscriptionResult.stateStream

                      }
                    } catch {
                        print("Error logging in: \(error)")
                    }
                }
                
        }
    }


  func updateRoomsWithDiffs(_ diffs: [RoomListEntriesUpdate]) {
    rooms = diffs.reduce(rooms) { currentItems, diff in
        processDiff(diff, on: currentItems)
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

        let username = ProcessInfo.processInfo.environment["MUSERNAME"]
        let password = ProcessInfo.processInfo.environment["MPASSWORD"]
        guard let username, let password else {
            fatalError("Username or password is not set in the env variables")
        }
        try await client.login(username: username, password: password, initialDeviceName: nil, deviceId: nil)

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

//#Preview {
//    AppView()
//}
