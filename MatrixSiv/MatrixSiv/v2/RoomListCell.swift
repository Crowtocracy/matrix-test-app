//
//  RoomListCell.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 5/14/25.
//

import SwiftUI

struct RoomListCell: View {
    let room: SivRoom
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "person.circle")
                .sivAvatarImage()
            VStack(alignment: .leading) {
                Text(room.displayName)
                    .sivTypography(.titleMedium)
                Text("message stuff")
                    .sivTypography(.bodyMedium)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

