//
//  Home.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/9/24.
//

import SwiftUI
import MatrixRustSDK

struct Home: View {
    @State var clientName: String? = nil
    @State var client: Client?
    @Binding var rooms: [RoomSummary]

    var body: some View {
        VStack {
            Text("Hello, \(clientName == nil ? "World" : clientName ?? "")!" )
          Text("room count: \(rooms.count)")
            roomListView
                .frame(maxWidth: .infinity)
        }
        
        
    }
    
    @ViewBuilder
    var roomListView: some View {
        ScrollView {
            VStack {
                ForEach(rooms, id: \.id) { room in
//              if let room = rooms.first {
                    HStack {
                        Image(systemName: "shared.with.you.circle")
                        .size(30)
                      Text(room.name)

                    }
              } 
//          else {
//                Text("no")
//              }

                Spacer()
            }
        }
        
    }

 
}





extension View {
    func size(_ size: CGFloat) -> some View {
        return self.frame(width: size, height: size)
    }
}
//extension Room: Hashable, Identifiable {
//    var identifier: String {
//        self.id()
//    }
//    public func hash(into hasher: inout Hasher) {
//        return hasher.combine(identifier)
//    }
//    public static func == (lhs: MatrixRustSDK.Room, rhs: MatrixRustSDK.Room) -> Bool {
//        lhs.id() == rhs.id()
//    }
//}
//
//extension RoomListItem: Hashable, Identifiable {
//    var identifier: String {
//        self.id()
//    }
//    public func hash(into hasher: inout Hasher) {
//        return hasher.combine(identifier)
//    }
//    public static func == (lhs: MatrixRustSDK.RoomListItem, rhs: MatrixRustSDK.RoomListItem) -> Bool {
//        lhs.id() == rhs.id()
//    }
//}




