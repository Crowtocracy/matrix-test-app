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
                
                /// Uncomment this block whe you have set your appservice
                /*
                NavigationLink  {
                    CreateAccountView()
                } label: {
                    Text("Create account")
                        .sivButtonStyle(style: .tertiary)
                }
                */
                
                Text("Set AppConstants to use data from your appservice to be able to register users")
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            }
        }
        
    }
}

#Preview {
    AuthView()
}
