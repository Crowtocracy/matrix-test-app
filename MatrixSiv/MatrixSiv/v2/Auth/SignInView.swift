//
//  SignInView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK


struct SignInView: View {
    @State var homeserver: String = AppConstants.homeserver
    @State var username: String = ""
    @State var password: String = ""
    @State var errorMessage: String? = nil
    var body: some View {
        VStack {
            TextField("Homeserver", text: $homeserver)
                .keyboardType(.URL)
                .autocapitalization(.none)
            TextField("Username", text: $username)
                .autocapitalization(.none)
            SecureField("Password", text: $password)
                .autocapitalization(.none)
            Button {
                login()
            } label: {
                Text("Sign In")
                    .sivButtonStyle()
            }
        }
    }
    
    func login() {
        Task {
            _ = await MatrixManager.login(homeserver: homeserver, email: username, password: password)
        }
    }
}

#Preview {
    SignInView()
}
