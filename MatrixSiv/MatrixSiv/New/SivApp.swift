//
//  SivApp.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//

import SwiftUI
@preconcurrency import MatrixRustSDK

@MainActor struct SivApp: View {
    @State var isReady = false
    @StateObject var appState = AppState()
    var body: some View {
        VStack {
            if appState.matrixAuthState == .loggedIn {
                Button("Log Out") {
                    Task {
                        do {
                            try await appState.matrixManager?.logout()
                        } catch {
                            print("Can't log out: \(error)")
                        }
                    }
                    
                }
            }
            if isReady {
                if let matrixManager = appState.matrixManager, appState.matrixAuthState == .loggedIn {
                    InboxView(matrixManager: matrixManager)
//                    Home(clientName: "yo", client: matrixManager.client, rooms: .constant(matrixManager.rooms))
                } else {
                    LoginView(appState: appState)
                }
            } else {
                Text("Loading...")
            }
        }
        .task {
            if let client = await MatrixManager.restoreSession() {
                appState.matrixManager = MatrixManager(client: client)
                appState.matrixAuthState = .loggedIn
            }
            if appState.matrixAuthState == .loggedIn, nil != appState.matrixManager {
                
            } else {
                appState.matrixManager = nil
                appState.matrixAuthState = .loggedOut
            }
            isReady = true
        }
        
    }
    
    
}



#Preview {
    SivApp()
}
