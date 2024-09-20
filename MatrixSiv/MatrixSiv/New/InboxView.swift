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
                        Text(room.name)
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
