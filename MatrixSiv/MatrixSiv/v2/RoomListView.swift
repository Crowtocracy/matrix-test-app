//
//  RoomListView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK
struct RoomListView: View {

    var body: some View {
        ScrollView {
            roomsView
        }
    }
    
    var roomsView: some View {
        VStack {
            ForEach(MatrixManager.shared.rooms, id: \.id) { room in
                RoomListCell(room: room)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RoomListView()
}
