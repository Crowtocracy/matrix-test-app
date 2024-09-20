//
//  LoginView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//

import SwiftUI
@preconcurrency import MatrixRustSDK

struct LoginView: View {
    @ObservedObject var appState: AppState
    let sivTeam: [String : String] = [
        "Ray": "0f2e33b4-e19f-423b-aa6b-9c87f3253e1f",
        "Test": "8a51bf95-6f27-4182-8848-bc54d01d5984"
    ]
    @State var isLoading: Bool = false
    var body: some View {
        VStack {
            Text("Pick a user")
            
            ForEach(Array(sivTeam.keys), id: \.self) { user in
                Button {
                    isLoading = true
                    if let username = sivTeam[user] {
                        Task {
                            if let client = await MatrixManager.loginUser(username: username) {
                                appState.matrixManager = MatrixManager(client: client)
                                appState.matrixAuthState = .loggedIn
                            }
                            isLoading = false
                        }
                    }
                } label: {
                    Text(user)
                }
            }
        }
        .overlay {
            if isLoading {
                Color.gray.opacity(0.5)
                    .overlay {
                        ProgressView()
                    }
            }
            
        }
    }
}

#Preview {
    LoginView(appState: AppState())
}
