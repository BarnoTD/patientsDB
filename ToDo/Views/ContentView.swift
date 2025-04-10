//
//  ContentView.swift
//  ToDo
//
//  Created by Hold Apps on 24/3/2025.
//

import SwiftUI
import GoogleSignInSwift

struct ContentView: View {
    
    @StateObject var googleSignInHelper = GoogleSignInHelper.shared

        var body: some View {
            VStack {
                if let user = googleSignInHelper.user {
                    PatientListView()
                    
                } else {
                    GoogleSignInButton(action: googleSignInHelper.SignIn)
                        .frame(width:200 ,height: 50)
                        .padding()
                }
            }
        }
    
//    var body: some View {
//        PatientListView()
//    }
}

#Preview {
    ContentView()
}
