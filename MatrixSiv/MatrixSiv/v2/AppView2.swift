//
//  AppView2.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK

struct AppView2: View {
    @State var isAuthenticated: Bool = false
    @State var matrixClient: Client? = nil
    var body: some View {
        Group {
            if MatrixManager.shared.isLoggedIn() {
                RoomListView()
            } else {
                AuthView()
            }
        }
        .onAppear {
            if let existingSession = Session.loadFromUserDefaults() {
                print("Session found. attempting to restore")
                Task {
                    await MatrixManager.restoreSession(session: existingSession)
                }
            }
            if !MatrixManager.shared.isLoggedIn() {
                print("We need to login")
            } else {
                print("Logged in")
            }
        }
        
        
    }
}

#Preview {
    AppView2()
}
