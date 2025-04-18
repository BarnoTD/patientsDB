//
//  GoogleSignInHelper.swift
//  ToDo
//
//  Created by Hold Apps on 2/4/2025.
//

import GoogleSignIn
import GoogleSignInSwift
import Dependencies
import GoogleAPIClientForREST_Drive

class GoogleSignInHelper: ObservableObject{
    @Published var user : GIDGoogleUser?
    
    static let shared = GoogleSignInHelper()
    
    
    
    
    func SignIn() {
#if os(iOS)
        guard let rootViewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            self.handleSignIn(result: result, error: error)
        }
        
#elseif os(macOS)
        guard let window = NSApplication.shared.windows.first else {
            print("No window found")
            return
        }
        print("Window found, calling GIDSignIn.sharedInstance.signIn")
        GIDSignIn.sharedInstance.signIn(withPresenting: window) { result, error in
            self.handleSignIn(result: result, error: error)
        }
#endif
    }
    
    func handleSignIn(result: GIDSignInResult?, error: Error?) {
        print("Sign-in completion handler called")
        if let error = error {
            print("Sign-in error: \(error.localizedDescription)")
            return
        }
        DispatchQueue.main.async {
            self.user = result?.user
            
            // Initialize CloudSyncManager after successful sign-in
            if let user = result?.user {
                let cloudSyncManager = CloudSyncManager.shared
                cloudSyncManager.initializeWithUser(user)
                cloudSyncManager.startAutoSync()
                print("✅ Cloud sync initialized and started after sign-in")
            }
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        user = nil
    }
}

