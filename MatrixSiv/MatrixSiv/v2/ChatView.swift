//
//  ChatView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/23/25.
//

import SwiftUI
import Kingfisher
import MatrixRustSDK
import Foundation


struct ChatView: View {
    @Environment(\.dismiss) private var dismiss
    let basicRoom: SivRoom
    @State var room: SivRoom?
    @State var draft: String = ""
    @State var roomListItem: RoomListItem?
    @State var roomInfo: RoomInfo?
    @State var roomManager: RoomManager?
    @State var actionMessage: SivMessage? = nil
    @State var parentMessage: SivMessage? = nil
    var body: some View {
        VStack {
            header
            messagesView
            inputView
        }
        .navigationBarBackButtonHidden()
        .sheet(item: $actionMessage) { _ in
            MessageMenu(replyAction: replyAction)
                .presentationDetents([.medium])
        }
        .task {
            await loadData()
        }
    }
    @ViewBuilder
    
    var header: some View {
        HStack(spacing: 21) {
            SivBackButton {
                if parentMessage == nil {
                    dismiss()
                } else {
                    parentMessage = nil
                }
                
            }
            HStack(spacing: 10) {
                if parentMessage == nil {
                    SivAvatar(avatarURL: basicRoom.avatarUrl?.nullableTrimmed, displayName: basicRoom.displayName.nullableTrimmed ?? basicRoom.id, avatarSize: .large)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(parentMessage != nil ? "Replies" : basicRoom.displayName.nullableTrimmed ?? basicRoom.id)
                        .sivTypography(room == nil ? .titleMedium : .titleSmall)
                       .foregroundStyle(.sivPrimary)
                       .multilineTextAlignment(.leading)
                    if let room {
                        Text(room.isDirect ? "Direct Message" : "Room")
                            .sivTypography(.labelSmall)
                            .fontWeight(.semibold)
                            .foregroundStyle(.sivGray2)
                    }
                }
                
            }
             
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
    
    func replyAction() {
        print("reply to message")
        guard let actionMessage else {
            fatalError("Error: trying to assign reply message without actionMessage")
        }
        let message = actionMessage
        self.actionMessage = nil
        self.parentMessage = message
        
    }
    var messagesView: some View {
        ScrollView {
            VStack (alignment: .leading) {
                
                if let roomManager {
                    if let parentMessage {
                        MessageCell(message: parentMessage)
                        if let replies = roomManager.replyDict[parentMessage.id], !replies.isEmpty {
                            Text("\(replies.count) Replies")
                                .sivTypography(.labelMedium)
                                .fontWeight(.bold)
                                .foregroundStyle(.sivGray2)
                                .padding(.top, 21)
                                .padding(.horizontal, 25)
                            SivDivider()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 20)
                            ForEach(replies, id: \.id) { message in
                                MessageCell(message: message)
                                    .onLongPressGesture {
                                        messageLongPressAction(message: message)
                                    }
                            }
                        }
                        
                    } else {
                        ForEach(roomManager.sivMessages, id: \.id) { message in
                            MessageCell(message: message)
                                .onLongPressGesture {
                                    messageLongPressAction(message: message)
                                }
                            if let replies = roomManager.replyDict[message.id], !replies.isEmpty {
                                Button {
                                    parentMessage = message
                                } label: {
                                    Text("\(replies.count) Replies")
                                        .sivTypography(.labelMedium)
                                        .foregroundStyle(.sivPrimary)
                                }
                                .padding(.leading, 61)
                            }
                            
                        }
                    }
                    
                }
                Spacer()
            }
        }
        .defaultScrollAnchor(parentMessage == nil ? .bottom : .top)
    }
    
    var inputView: some View {
        HStack {
            TextField("Enter message", text: $draft)
                .sivTypography(.bodyLarge)
                .padding(12)
                .background(.sivGray4)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
            if !draft.isEmpty {
                Button {
                    Task {
                        await sendMessage()
                    }
                    
                } label: {
                    Image(systemName: "paperplane")
                        .resizable()
                        .squareSize(20)
                        .padding(2)
                        .foregroundStyle(.sivOrange)
                    
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 34)
        
    }
    
    func messageLongPressAction(message: SivMessage) {
        print("message cell long press")
        actionMessage = message
    }
    func sendMessage() async {
        let message = draft
        draft = ""
        await roomManager?.sendPlainMessage(message: message, parentMessage: parentMessage)
        
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
        VStack(alignment: .leading, spacing: 10) {
            senderView
            messageContentView
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 20)
    }
    
    var senderView: some View {
        HStack(spacing: 10) {
            SivAvatar(avatarURL: message.avatarURL, displayName: message.senderName)
            
            Text(message.senderName)
                .sivTypography(.titleMedium)
            Text("9:32 am")
                .sivTypography(.labelSmall)
                .foregroundStyle(.sivGray3)
            Spacer()
        }
    }
    
    
    var messageContentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(.clear)
                    .squareSize(30)
                Text(message.message)
                    .multilineTextAlignment(.leading)
                    .sivTypography(.bodyLarge)
                Spacer()
            }
        }
        
        
    }
}


struct SivBackButton: View {
    let action: () -> Void
    var body: some View {
        Button {
            action()
        } label: {
            Circle()
                .fill(.sivGray4)
                .squareSize(40)
                .overlay {
                    Image(systemName: "arrow.backward")
                        .squareSize(12)
                }
                    
            
        }
    }
}


struct SivAvatar: View {
    let avatarURL: String?
    let displayName: String
    var avatarSize: AvatarSize = .regular
    var isRoom: Bool = false
    @State var showPlaceholder: Bool = false
    var body: some View {
        if showPlaceholder || avatarURL == nil {
            Circle()
                .fill(.teal)
                .squareSize(avatarSize.rawValue)
                .overlay {
                    Text(generateInitials())
                        .sivTypography(avatarSize.typography)
                        .foregroundStyle(.white)
                }
        } else if let avatarURL {
            KFImage(URL(string: avatarURL))
                .onFailure { _ in
                    showPlaceholder = true
                }
                .resizable()
                .squareSize(avatarSize.rawValue)
        }
        
        
    }
    
    
    
    func generateInitials() -> String {
        guard displayName.nullableTrimmed != nil else {
            fatalError("Error: displayName must not be empty")
        }

        let firsts = Array(displayName.split(separator: " ").compactMap({ String($0.first ?? Character(""))}).prefix(2))
        let initials = firsts.joined().uppercased()
        return initials
            

    }
    
    enum AvatarSize: CGFloat {
        case regular = 30
        case large = 40
        
        var typography: Typography {
            switch self {
            case .regular:
                return .labelMedium
            case .large:
                return .labelLarge
            }
        }
    }
}

struct MessageMenu: View {
    let replyAction: () -> Void
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Spacer()
                Capsule()
                    .fill(.sivGray3)
                    .frame(width: 40, height: 6)
                    .padding(.top, 10)
                Spacer()
            }
            MessageMenuButton(label: "Reply", iconImage: Image(systemName: "message")) {
                replyAction()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct MessageMenuButton: View {
    
    let label: String
    let iconImage: Image?
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack (spacing: 20) {
                if let iconImage = iconImage {
                    iconImage
                        .resizable()
                        .squareSize(20)
                        .padding(2)
                }
                Text(label)
            }
            .sivTypography(.labelLarge)
            .foregroundStyle(.sivGray2)
            .padding(.vertical, 10)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .padding(.horizontal, 20)
        
    }
}
