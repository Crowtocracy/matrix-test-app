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
    var body: some View {
        NavigationStack {
            Text("Rooms")
            Button("Refresh") {
                refreshRooms()
            }
            VStack {
                membershipViewSelector
                ScrollView {
                    if membership == .joined {
                        roomsView
                    } else {
                        invites
                    }
                    
                }
            }
        }
        
        
    }
    var membershipViewSelector: some View {
        HStack {
            Button("Messages"){
                membership = .joined
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                if membership == .joined {
                    Rectangle().fill(.sivPrimary).frame(height: 4)
                }
                
            }
            Button("Invites"){
                membership = .invited
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                if membership == .invited {
                    Rectangle().fill(.sivPrimary).frame(height: 4)
                }
                
            }
        }
    }
    var invites: some View {
        VStack {
            ForEach(MatrixManager.shared.rawRooms.compactMap({ $0.membership() == .invited ? $0.convertToBasicSivRoom() : nil }), id: \.id) { room in
                RoomListCell(basicRoom: room)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    var roomsView: some View {
        VStack {
            ForEach(MatrixManager.shared.rawRooms.compactMap({ $0.membership() == .joined ? $0.convertToBasicSivRoom() : nil }), id: \.id) { room in
                NavigationLink {
                    ChatView(basicRoom: room)
                } label: {
                    RoomListCell(basicRoom: room)
                }

                
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
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
