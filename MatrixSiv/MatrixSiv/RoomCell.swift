//
//  RoomCell.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/20/24.
//

import SwiftUI
import MatrixRustSDK

struct RoomCell: View {
    let roomSummary: RoomSummary
    @State var lastMessage: String?
    var body: some View {
        HStack {
            Avatar(avatarURL: roomSummary.avatarURL)
            VStack(alignment: .leading) {
                Text(roomSummary.name)
                    .bold()
                if let lastMessage {
                    Text(lastMessage)
                }
                
            }
            .frame(maxWidth: .infinity)
            .task {
                lastMessage = roomSummary.lastMessage?.description
                
            }
            Spacer()
            if roomSummary.hasUnreadMessages {
                Circle()
                    .fill(.green)
                    .size(15)
                    .overlay {
                        Text("\(roomSummary.unreadMessagesCount)")
                            .foregroundStyle(.white)
                    }
                    
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct Avatar: View {
    var avatarURL: URL?
    
    var body: some View {
        avatar
            .size(44)
            .clipShape(Circle())
    }
    
    @ViewBuilder var avatar: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { result in
                result.image?
                    .resizable()
                    .scaledToFill()
            }
        } else {
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFill()
                .foregroundStyle(.black)
                .padding(5)
                .background(.gray)
        }
    }
}

#Preview {
    RoomCell(roomSummary: RoomSummary(roomListItem: RoomListItem(noPointer: .init()), id: UUID().uuidString, hasUnreadMessages: false, hasUnreadMentions: false, hasUnreadNotifications: false))
}
