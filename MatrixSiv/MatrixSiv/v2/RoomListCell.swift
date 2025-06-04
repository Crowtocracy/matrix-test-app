//
//  RoomListCell.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/14/25.
//

import SwiftUI
import MatrixRustSDK
import Kingfisher

struct RoomListCell: View {
    let basicRoom: SivRoom
    @State var room: SivRoom
    @State var message: String = "Message placeholder"
    @State var time: String = ""
    @State var roomListItem: RoomListItem? = nil
    @State var isEncrypted: Bool = false
//    @State var isMarkedUnread: Bool = true
    init(basicRoom: SivRoom) {
        self.basicRoom = basicRoom
        self.room = basicRoom
    }
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            SivAvatar(avatarURL: basicRoom.avatarUrl, displayName: basicRoom.displayName.nullableTrimmed ?? basicRoom.id, avatarSize: .large)
            
            
            VStack(alignment: .leading, spacing: 0) {
                Text(room.displayName)
                    .multilineTextAlignment(.leading)
                    .sivTypography(.titleMedium)
                    .foregroundStyle(.sivGray)
                Text(room.isDirect ? "Direct Message" : "Room")
                    .sivTypography(.bodyMedium)
                    .foregroundStyle(.sivGray2)
                Spacer()
                    .frame(height: 10)
                if roomListItem?.membership() == .invited {
                    inviteActions
                } else {
                    Text(isEncrypted ? "🔒" : (message + " • " + time))
                        .sivTypography(.bodyMedium)
                        .foregroundStyle(.sivGray2)
                }
                 
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .overlay(alignment: .topTrailing, content: {
            if room.isMarkedUnread {
                Circle()
                    .fill(.orange)
                    .squareSize(8)
                    .padding(.top, 14)
                    .padding(.trailing, 8)
            }
            
        })
        .task {
            await loadData()
        }
        .onAppear {
            print("\(room.id) Avatar url \(room.avatarUrl ?? "none")")
        }
    }
    
    var inviteActions: some View {
        HStack {
            Button ("Accept") {
                Task {
                    await acceptInvite()
                }
            }
            
            Button ("Decline") {
                
            }
        }
    }
    
    func acceptInvite() async {
        let room = await MatrixManager.shared.joinRoom(roomId: basicRoom.id)
        if let room {
            print("successfully joined room")
        }
    }
    
    func declineInvite() async {
        
    }
    func loadData() async {
        let roomListItem = await MatrixManager.shared.getRoomListItem(roomId: basicRoom.id)
        self.roomListItem = roomListItem
        if let roomListItem = roomListItem {
          self.room = await roomListItem.convertToSivRoom()
          if room.membership == .invited {
              message = "You have been invited to join this room"
          }
          let lastEvent = await roomListItem.latestEvent()
            
          message = lastEvent?.getMessage() ?? ""
          time = lastEvent?.timestamp.description ?? ""
            isEncrypted = await roomListItem.isEncrypted()
        }
    }
    func messageAndTime() async -> String {
        let separator = " • "
        let message = await roomListItem?.latestEvent()?.getMessage()
        let timestamp = await roomListItem?.latestEvent()?.timestamp.description
        
        let full: [String] = [message, timestamp].compactMap({ $0 })
        return full.joined(separator: separator)
    }
    
}

