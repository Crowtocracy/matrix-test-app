//
//  RoomListView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK
struct RoomListView: View {

    @State var membership: Membership = .joined
    @State var rooms: [SivRoom] = []
    @State var showMenu: Bool = false
    var body: some View {
        NavigationStack {
            header
            VStack (spacing: 0) {
                membershipViewSelector
                customDivider
                ScrollView {
                    if membership == .joined {
                        roomsView
                    } else {
                        invites
                    }
                    
                }
            }
            .fullScreenCover(isPresented: $showMenu) {
                MenuView()
            }
        }
        
        
    }
    
    var header: some View {
        HStack {
            Button {
                refreshRooms()
            } label: {
                Text("sivchats")
                    .sivTypography(.titleLarge)
                    .foregroundStyle(.sivPrimary)
                    .sivGradientMask()
            }
            
            Spacer()
            
            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .fontWeight(.semibold)
                    .squareSize(20)
                    .padding(2)
                    .foregroundStyle(.sivPrimary)
            }
            
            
        }
        .padding(.horizontal, 16)
    }
    var membershipViewSelector: some View {
        HStack {
            Button {
                membership = .joined
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .squareSize(20)
                        .padding(2)
                    Text("Chats")
                        
                    
                }
                .sivTypography(.labelMedium)
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .foregroundStyle(membership == .joined ? .sivPrimary : .sivGray2)
            .overlay(alignment: .bottom) {
                if membership == .joined {
                    Rectangle().fill(.sivPrimary).frame(height: 4)
                }
                
            }
            Button{
                membership = .invited
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.badge")
                        .squareSize(20)
                        .padding(2)
                    Text("Invites")
                        
                    
                }
                .sivTypography(.labelMedium)
            }
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .foregroundStyle(membership == .invited ? .sivPrimary : .sivGray2)
            .overlay(alignment: .bottom) {
                if membership == .invited {
                    Rectangle().fill(.sivPrimary).frame(height: 4)
                }
                
            }
        }
        .frame(height: 64)
    }
    var invites: some View {
        VStack {
            ForEach(MatrixManager.shared.rawRooms.compactMap({ $0.membership() == .invited ? $0.convertToBasicSivRoom() : nil }), id: \.id) { room in
                RoomListCell(basicRoom: room)
                customDivider
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    var roomsView: some View {
        VStack (spacing: 0) {
            ForEach(MatrixManager.shared.rawRooms.compactMap({ $0.membership() == .joined ? $0.convertToBasicSivRoom() : nil }), id: \.id) { room in
                NavigationLink {
                    ChatView(basicRoom: room)
                } label: {
                    RoomListCell(basicRoom: room)
                }
                customDivider

                
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    
    var customDivider: some View {
        SivDivider()
    }
    
    func refreshRooms() {
        Task {
            rooms = await MatrixManager.shared.refreshRooms()
        }
            
    }
    
}

#Preview {
    RoomListView()
}


extension View {
    func sivGradientMask() -> some View {
        /*
         Color(red: 255, green: 192, blue: 124),
         Color(red: 212, green: 108, blue: 118),
         Color(red: 62, green: 25, blue: 110)
         */
        self.overlay {
            LinearGradient(colors: [
                Color(red: 255/255, green: 192/255, blue: 124/255),
                Color(red: 212/255, green: 108/255, blue: 118/255),
                Color(red: 62/255, green: 25/255, blue: 110/255)
            ], startPoint: .topLeading, endPoint: .bottomTrailing).mask(self)
        }
    }
}

struct SivDivider: View {
    var body: some View {
        Rectangle()
            .fill(.sivGray4)
            .frame(height: 1)
    }
}

struct MenuView: View {
    var body: some View {
        VStack (alignment: .leading) {
            Button {
                Task {
                    await logout()
                }
            } label: {
                Text("Logout")
            }
            Spacer()
        }
    }
    
    func logout() async {
        await MatrixManager.shared.logout()
    }
}
