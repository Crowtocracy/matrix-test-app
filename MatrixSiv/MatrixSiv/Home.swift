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
                    HStack {
                        Image(systemName: "shared.with.you.circle")
                      Text(room.name)
                    }
              }
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




