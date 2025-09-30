//
//  BrewNetApp.swift
//  BrewNet
//
//  Created by Justin_Yuan11 on 9/28/25.
//

import SwiftUI

@main
struct BrewNetApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = AuthManager()
    @StateObject private var databaseManager = DatabaseManager.shared
    
    init() {
        print("🚀 BrewNetApp initialized")
        // Initialize database with sample data
        databaseManager.createSampleData()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(authManager)
                .environmentObject(databaseManager)
        }
    }
}
