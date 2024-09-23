//
//  InboxView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//

import SwiftUI

struct InboxView: View {
    @ObservedObject var matrixManager: MatrixManager
    @State var displayName = ""
    var body: some View {
        VStack {
            Text("Hello \(displayName)")
            Text("Inbox View: \(matrixManager.rooms.count)")
            ScrollView {
                VStack {
                    ForEach(matrixManager.rooms, id: \.id) { room in
                        VStack {
                            Text(room.displayName ?? room.id).bold()
                            Text(room.lastMessage?.body ?? "No Message")
                            Text("\(room.lastMessage?.timestamp.description ?? "no timestamp")")
                            Divider()
                        }
                        
                    }
                }
            }
            
        }
        .task {
            displayName = await matrixManager.getClientDisplayName() ?? "no display name"
            print(displayName)
        }
    }
}
