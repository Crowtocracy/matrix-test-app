//
//  InboxView.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 9/20/24.
//

import SwiftUI

struct InboxView: View {
    @ObservedObject var matrixManager: MatrixManager
    var body: some View {
        Text("Inbox View: \(matrixManager.rooms.count)")
    }
}
