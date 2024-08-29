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
    @State var roomInfo: RoomInfo?
    var body: some View {
        HStack {
            Avatar(avatarURL: roomSummary.avatarURL)
            VStack(alignment: .leading) {
                Text(roomSummary.name)
                    .bold()
                if let lastMessage {
                    Text(roomSummary.roomListItem.roomInfo())
                }
                
            }
            .frame(maxWidth: .infinity)
            .task {
                lastMessage = roomSummary.lastMessage?.description
                
            }
            Spacer()
            if let unread = roomInfo?.notificationCount, unread > 0 {
                Circle()
                    .fill(.green)
                    .size(15)
                    .overlay {
                        Text("\(unread)")
                            .foregroundStyle(.white)
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .task {
            await getRoomInfo()
        }
        .task(id: "\(roomSummary.unreadNotificationsCount)\(roomSummary.unreadMessagesCount)\(roomSummary.hasUnreadNotifications)") {
            await getRoomInfo()
        }
    }
    func getRoomInfo() async {
        print("fetching room info")
        do {
            roomInfo = try await roomSummary.roomListItem.roomInfo()
            print("got roominfo")
        } catch {
            print("ERROR: failed to get roomInfo \(error)")
        }
        
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
