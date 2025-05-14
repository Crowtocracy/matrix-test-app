//
//  SignInView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK


struct SignInView: View {
    @State var homeserver: String = "matrix.org"
    @State var username: String = ""
    @State var password: String = ""
    var body: some View {
        VStack {
            TextField("Homeserver", text: $homeserver)
            TextField("Username", text: $username)
            SecureField("Password", text: $password)
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
