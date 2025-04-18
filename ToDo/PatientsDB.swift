//
//  ToDoApp.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//

import SwiftUI
import GoogleSignIn
//import GoogleDriveClient

@main
struct PatientsDB: App {
    @StateObject private var cloudSyncManager = CloudSyncManager.shared
    
    init() {
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
            print("Client ID from Info.plist: \(clientID)")
        } else {
            print("Client ID not found in Info.plist")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onDisappear {
                    cloudSyncManager.stopAutoSync()
                }
        }
    }
}

extension GIDSignIn {
    func getAccessToken() async throws -> String {
        guard let currentUser = GIDSignIn.sharedInstance.currentUser else {
            throw NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not signed in"])
        }
        // Ensure the access token is refreshed if necessary
        try await currentUser.refreshTokensIfNeeded()
        return currentUser.accessToken.tokenString
    }
}
