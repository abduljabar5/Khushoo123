//
//  GoogleSignInHelper.swift
//  Dhikr
//
//  Google Sign In helper (placeholder until GoogleSignIn SDK is added)
//

import Foundation
import SwiftUI

class GoogleSignInHelper: ObservableObject {
    @Published var isSigningIn = false

    func signIn(completion: @escaping (String, String) -> Void, onError: @escaping (Error) -> Void) {
        // This is a placeholder
        // Once you add GoogleSignIn SDK, implement:
        /*
        guard let presentingViewController = getRootViewController() else { return }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { result, error in
            if let error = error {
                onError(error)
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                onError(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get tokens"]))
                return
            }

            let accessToken = user.accessToken.tokenString
            completion(idToken, accessToken)
        }
        */

        // For now, show error that Google Sign In needs setup
        let error = NSError(
            domain: "GoogleSignIn",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Google Sign In requires additional setup. Check documentation."]
        )
        onError(error)
    }

    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}
