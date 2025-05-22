//
//  ChatView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/23/25.
//

import SwiftUI
import Kingfisher
import MatrixRustSDK


struct ChatView: View {
    let basicRoom: SivRoom
    @State var room: SivRoom?
    @State var draft: String = ""
    @State var roomListItem: RoomListItem?
    @State var roomInfo: RoomInfo?
    @State var roomManager: RoomManager?
    var body: some View {
        VStack {
            header
            messagesView
            inputView
        }
        .task {
            await loadData()
        }
    }
    
    var header: some View {
        HStack(spacing: 10) {
            if let avatarURL = basicRoom.avatarUrl {
                KFImage( URL(string: avatarURL)!)
                    .resizable()
                    .sivAvatar()
            } else {
                Image(systemName: room?.isDirect ?? basicRoom.isDirect ? "person.circle" : "person.2.circle")
                    .sivAvatarImage()
            }
            
            Text(basicRoom.displayName.nullableTrimmed ?? basicRoom.id)
                .sivTypography(.titleMedium)
                .foregroundStyle(.sivPrimary)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button {
                infoAction()
            } label: {
                Image(systemName: "info.circle")
                    .resizable()
                    .squareSize(24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
    }
    
    var messagesView: some View {
        ScrollView {
            VStack {
                
                if let roomManager {
                    Text("We havee \(roomManager.reversedSivMessages.count)")
                    ForEach(roomManager.reversedSivMessages, id: \.id) { message in
                        MessageCell(message: message)
                    }
                }
                Spacer()
            }
        }
    }
    
    var inputView: some View {
        TextField("Enter message", text: $draft)
    }
    func infoAction() {
        print("Info button tapped")
    }
    
    func loadData() async {
        do {
            self.roomListItem = await MatrixManager.shared.getRoomListItem(roomId: basicRoom.id)
            self.room = await roomListItem?.convertToSivRoom()
            self.roomInfo = try await roomListItem?.roomInfo()
            if let room, let roomInfo, let roomListItem {
                roomManager = await MatrixManager.shared.getRoomManager(roomId: basicRoom.id)
                try await roomManager?.setup()
                try await roomManager?.paginateBackwards()
            }
        } catch {
            print("Error loading data \(error)")
        }
        
    }
}


extension String {
    var nullableTrimmed: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


struct MessageCell: View {
    let message: SivMessage
    var body: some View {
        VStack {
            senderView
            messageContentView
        }
    }
    
    var senderView: some View {
        HStack {
            Image(systemName: "person.circle")
                .sivAvatarImage(30)
            
            Text("Sender")
        }
    }
    
    
    var messageContentView: some View {
        Text(message.message)
    }
}
