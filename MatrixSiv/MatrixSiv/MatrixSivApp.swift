//
//  MatrixSivApp.swift
//  MatrixSiv
//
//  Created by Rachel Castor on 8/9/24.
//

import SwiftUI
import SwiftData

@main
struct MatrixSivApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SivApp()
//            AppView()
        }
        .modelContainer(sharedModelContainer)
    }
}
