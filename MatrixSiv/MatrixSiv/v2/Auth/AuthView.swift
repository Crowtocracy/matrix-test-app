//
//  AuthView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 4/25/25.
//

import SwiftUI
import MatrixRustSDK

struct AuthView: View {

    var body: some View {
        NavigationStack {
            VStack {
                NavigationLink {
                    SignInView()
                } label: {
                    Text("Sign in manually")
                        .sivButtonStyle()
                }
                
                NavigationLink  {
                    CreateAccountView()
                } label: {
                    Text("Create account")
                        .sivButtonStyle(style: .tertiary)
                }
            }
        }
        
    }
}

#Preview {
    AuthView()
}
