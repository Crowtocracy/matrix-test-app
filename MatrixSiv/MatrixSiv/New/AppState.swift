//
//  AppState.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//

import Foundation

enum MatrixAuthState {
    case loggedIn, loggedOut
}

@MainActor class AppState: ObservableObject {
    @Published var matrixAuthState: MatrixAuthState = .loggedOut
    @Published var matrixManager: MatrixManager?
}
