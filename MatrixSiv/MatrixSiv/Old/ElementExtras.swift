//
//  ElementExtras.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/30/24.
//

import Foundation
import MatrixRustSDK

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

class RoomListEntriesListenerProxy: RoomListEntriesListener {
    private let onUpdateClosure: ([RoomListEntriesUpdate]) -> Void

    init(_ onUpdateClosure: @escaping ([RoomListEntriesUpdate]) -> Void) {
        self.onUpdateClosure = onUpdateClosure
    }

    func onUpdate(roomEntriesUpdate: [RoomListEntriesUpdate]) {
        onUpdateClosure(roomEntriesUpdate)
    }
}

class RoomListStateObserver: RoomListLoadingStateListener {
    private let onUpdateClosure: (RoomListLoadingState) -> Void

    init(_ onUpdateClosure: @escaping (RoomListLoadingState) -> Void) {
        self.onUpdateClosure = onUpdateClosure
    }

    func onUpdate(state: RoomListLoadingState) {
        onUpdateClosure(state)
    }
}

class SendQueueRoomErrorListenerProxy: SendQueueRoomErrorListener {
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

class ClientDelegateWrapper: ClientDelegate {
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
