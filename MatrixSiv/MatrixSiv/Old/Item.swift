//
//  Item.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/9/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
