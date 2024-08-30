//
//  AuthView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/29/24.
//

import SwiftUI
import MatrixRustSDK

enum Homeserver: String {
    case matrix
    case siv
    
    var url: String {
        switch self {
        case .matrix:
            return "matrix.org"
        case .siv:
            return "crowtocracy.etke.host"
        }
    }
}

enum TestUser: String {
    case test1, rmcastor, paul, ray, other
    var password: String {
        switch self {
        case .test1:
            ProcessInfo.processInfo.environment["MPASSWORD"] ?? ""
        case .rmcastor:
            ""
        case .paul, .ray:
            ProcessInfo.processInfo.environment["SPASSWORD"] ?? ""
        case .other:
            ""
        }
    }
    var username: String {
        switch self {
        case .test1:
            ProcessInfo.processInfo.environment["MUSERNAME"] ?? ""
        case .other:
            ""
        default:
            self.rawValue
        }
    }
}
struct AuthView: View {
    @Binding var client: Client?
    @State var server: String = Homeserver.matrix.url
    @State var user: TestUser = .other
    @State var username: String = ""
    @State var password: String = ""
    var body: some View {
        VStack {
            Text("Please Login")
            VStack {
                Picker("Pick a server", selection: $server) {
                    Text(Homeserver.matrix.rawValue).tag(Homeserver.matrix.url)
                    Text(Homeserver.siv.rawValue).tag(Homeserver.siv.url)
                }
                .pickerStyle(.segmented)
                Text(server)
                Picker("Pick a user", selection: $user) {
                    if server == Homeserver.matrix.url {
                        Text(TestUser.test1.rawValue).tag(TestUser.test1)
                        Text(TestUser.rmcastor.rawValue).tag(TestUser.rmcastor)
                    } else {
                        Text(TestUser.ray.rawValue).tag(TestUser.ray)
                        Text(TestUser.paul.rawValue).tag(TestUser.paul)
                    }
                    
                }
                .pickerStyle(.segmented)
                .task(id: user) {
                    username = user.username
                    password = user.password
                }
                TextField("username", text: $username)
                SecureField("password", text: $password)
                
                Button("Login") {
                    Task {
                        do {
                            print("building client")
                            let newClient = try await ClientBuilder()
                                .sessionPath(path: URL.applicationSupportDirectory.path() + Date.now.description)
                                .serverNameOrHomeserverUrl(serverNameOrUrl: server)
                                .build()
                            print("logging in user")
                            guard !username.isEmpty, !password.isEmpty else {
                                fatalError("Username or password is not set in the env variables")
                            }
                            try await newClient.login(username: username, password: password, initialDeviceName: nil, deviceId: nil)
                            let session = try newClient.session()
                            session.setToUserDefaults()
                            client = newClient
                        } catch {
                            print("ERROR: cannot login \(error)")
                        }
                    }
                    
                }
            }
            
            
        }
        .padding(20)
        
        
    }
}

//#Preview {
//    AuthView()
//}
