//
//  CreateAccountView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI

struct CreateAccountView: View {
    @State var homeserver: String = AppConstants.homeserver
    @State var username: String = ""
    @State var password: String = ""
    @State var confirmPass: String = ""
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
            SecureField("Confirm Password", text: $confirmPass)
                .autocapitalization(.none)
            Button {
                signUp()
            } label: {
                Text("Sign In")
                    .sivButtonStyle()
            }
        }
        .alert(Text("Error"), isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    func signUp() {
        if confirmPass != password {
            errorMessage = "Passwords do not match"
        }
        Task {
            await MatrixManager.registerUser(homeserver: homeserver, username: username, password: password)
        }
        
    }
}

