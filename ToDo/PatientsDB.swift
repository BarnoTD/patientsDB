//
//  ToDoApp.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//

import SwiftUI
import GoogleSignIn
import GoogleDriveClient

@main
struct PatientsDB: App {
    
    init(){
        if let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String {
                print("Client ID from Info.plist: \(clientID)")
            } else {
                print("Client ID not found in Info.plist")
            }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
}
