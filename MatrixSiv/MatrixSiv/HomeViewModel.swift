//
//  HomeViewModel.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/13/24.
//

import Foundation
import MatrixRustSDK
import CryptoKit
import Combine

class HomeViewModel: ClientDelegate, ObservableObject, RoomListServiceStateListener, RoomListEntriesListener, SyncServiceStateObserver, RoomListLoadingStateListener {
    
    
    
    
    let client: Client
    @Published var rooms: [Room] = []
    @Published var sivRooms = [SivRoom]()
    @Published var roomListItems = [RoomListItem]()
    var syncService: SyncService?
    var roomListService: RoomListService?
    var cancellables = Set<AnyCancellable>()
    
    // MARK: TaskHandles
    var roomListLoadingStateUpdateTaskHandle: TaskHandle?
    var roomListStateUpdateTaskHandle: TaskHandle?
    var syncServiceStateUpdateTaskHandle: TaskHandle?
    
    private let diffsPublisher = PassthroughSubject<[RoomListEntriesUpdate], Never>()
    
        init(client: Client) {
        self.client = client
        diffsPublisher
            .receive(on: DispatchQueue.main)
            .sink { 
                self.updateRoomsWithDiffs(diffs: $0)
                self.sivRooms = client.rooms().map({ $0.convertToSendable() })
                print("sivRooms updated: \(self.sivRooms)")
            }
            .store(in: &cancellables)
    }
    
    func updateRoomsWithDiffs(diffs: [RoomListEntriesUpdate]) {
        for diff in diffs {
            switch diff {
            case .append(let values):
                roomListItems.append(contentsOf: values)
            case .reset(let values):
                roomListItems = values
            default:
                break
            }
        }
        print("roomListItems updated: \(roomListItems)")
    }
    
    func setClientDelegate() async throws {
        print("setup")
        _ = client.setDelegate(delegate: self)
        
        syncService = try await client.syncService().finish()
        await syncService?.start()
        roomListService = syncService?.roomListService()
        roomListStateUpdateTaskHandle = roomListService?.state(listener: self)
        syncServiceStateUpdateTaskHandle = syncService?.state(listener: self)
    }
    
    func updateRooms() async throws {
        print("getting roomlist")
        let roomList = try await roomListService?.allRooms()
        let loadingstateResult = try roomList?.loadingState(listener: self )
        roomListLoadingStateUpdateTaskHandle = loadingstateResult?.stateStream
        loadingstateResult.publisher.sink { result in
            print("done getting loading state")
        }.store(in: &cancellables)
        print(loadingstateResult)
        let result = roomList?.entries(listener: self)
        result.publisher.sink { completion in
            print("done getting result")
        } receiveValue: { wee in
            print("done")
        }
        .store(in: &cancellables)
    }
    func onUpdate(state: MatrixRustSDK.SyncServiceState) {
        print("onUpdate(state: MatrixRustSDK.SyncServiceState)")
        print(state)
        print(client.rooms().count)
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
        let sendable = client.rooms().map({ $0.convertToSendable() })
        await MainActor.run {
            sivRooms = sendable
        }
        
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


    func onUpdate(state: MatrixRustSDK.RoomListLoadingState) {
        print("update: RoomListLoadingState \(state)")
    }
    func onUpdate(roomEntriesUpdate: [MatrixRustSDK.RoomListEntriesUpdate]) {
        print("roomEntriesUpdate")
        print(roomEntriesUpdate)
        diffsPublisher.send(roomEntriesUpdate)
        /*
        for update in roomEntriesUpdate {
            switch update {
            case .append(let values):
                print("appended")
                print(values)
                print(client.rooms().count)
                
                let sendable = client.rooms().map({ $0.convertToSendable() })
                Task { @MainActor in
                    sivRooms = sendable
                }
//                client.rooms().publisher.receive(on: DispatchQueue.main).sink { result in
//                    result.id()
//                }
                
                //print(rooms)
                
                
                
            case .reset(let values):
                print("reset")
                print(values)
            default:
                print(self)
            }
        }
        */
        
//        Task {
//            let roomList = try await roomListService?.allRooms()
//            let result = roomList?.entries(listener: self)
//            
//            result.publisher.map { output in
//                output.
//            }
//            print(roomList)
//        }
    }
    func onUpdate(state: MatrixRustSDK.RoomListServiceState) {
        print("state: MatrixRustSDK.RoomListServiceState")
        print(state)
    }



}

struct SivRoom: Identifiable, Hashable {
    let id: String
}
extension Room {
    func convertToSendable() -> SivRoom {
        SivRoom(id: self.id())
    }
}
