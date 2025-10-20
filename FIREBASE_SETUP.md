# Firebase Authentication Setup Guide

This guide walks you through setting up Apple Sign In, Google Sign In, and Email authentication for your Dhikr app.

---

## ✅ ALREADY COMPLETED

- Firebase SDK installed via SPM
- Firebase configured in `DhikrApp.swift`
- Auth service and UI created
- Email authentication works out of the box

---

## 📱 APPLE SIGN IN SETUP

### 1. Enable Sign in with Apple Capability in Xcode

1. Open your project in Xcode
2. Select the **Dhikr** target (main app target)
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign in with Apple**
6. Repeat for these extension targets if needed:
   - DhikrtrackerExtension
   - PrayerBlockerMonitor
   - DhikrShieldAction

### 2. Enable Apple Sign In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Authentication** → **Sign-in method**
4. Click **Apple**
5. Toggle **Enable**
6. **IMPORTANT**: Copy the callback URL shown (looks like `https://khushoo-ddcf6.firebaseapp.com/__/auth/handler`)
7. Click **Save**

### 3. Configure Apple Developer Console

**You'll see a message about adding a callback URL to Apple Developer Console.**

Follow the detailed guide: **`APPLE_SIGNIN_SETUP.md`** in your project root.

**Quick steps:**
1. Go to [Apple Developer Console](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select your App ID (`fm.mrc.Dhikr`)
4. Enable **Sign in with Apple**
5. Click **Edit** and add the Firebase callback URL:
   ```
   https://khushoo-ddcf6.firebaseapp.com/__/auth/handler
   ```
6. Save changes

**That's it! Apple Sign In is ready to use.**

---

## 🔵 GOOGLE SIGN IN SETUP

### 1. Add GoogleSignIn SDK via SPM

1. In Xcode, go to **File** → **Add Package Dependencies**
2. Enter URL: `https://github.com/google/GoogleSignIn-iOS`
3. Select **Up to Next Major Version**: `8.0.0` (or latest)
4. Add to your **Dhikr** target only
5. Select these products:
   - **GoogleSignIn**
   - **GoogleSignInSwift**

### 2. Enable Google Sign In in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Authentication** → **Sign-in method**
4. Click **Google**
5. Toggle **Enable**
6. Set your support email
7. Click **Save**
8. **IMPORTANT**: Copy the **iOS client ID** shown on this page

### 3. Configure Google Sign In in Xcode

#### A. Add URL Scheme

1. In Xcode, select **Dhikr** target
2. Go to **Info** tab
3. Expand **URL Types**
4. Click **+** to add a new URL Type
5. Set **Identifier**: `com.google.sign-in`
6. Set **URL Schemes**: Your **reversed client ID** (looks like `com.googleusercontent.apps.123456789-abcdefg`)
   - Find this in your `GoogleService-Info.plist` file under `REVERSED_CLIENT_ID`

#### B. Update GoogleSignInHelper.swift

Replace the placeholder code in `/Users/abduljabarnur/IOS/Dhikr/Dhikr/Backend/Services/GoogleSignInHelper.swift` with:

```swift
import Foundation
import SwiftUI
import GoogleSignIn
import FirebaseCore

class GoogleSignInHelper: ObservableObject {
    @Published var isSigningIn = false

    func signIn(completion: @escaping (String, String) -> Void, onError: @escaping (Error) -> Void) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            let error = NSError(domain: "GoogleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get Firebase client ID"])
            onError(error)
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let presentingViewController = getRootViewController() else {
            let error = NSError(domain: "GoogleSignIn", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"])
            onError(error)
            return
        }

        isSigningIn = true

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            self?.isSigningIn = false

            if let error = error {
                onError(error)
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                let error = NSError(domain: "GoogleSignIn", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get tokens"])
                onError(error)
                return
            }

            let accessToken = user.accessToken.tokenString
            completion(idToken, accessToken)
        }
    }

    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = scene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}
```

#### C. Handle Google Sign In URL in DhikrApp.swift

Add this to your `DhikrApp.swift` inside the `WindowGroup`:

```swift
.onOpenURL { url in
    GIDSignIn.sharedInstance.handle(url)
}
```

Full example:
```swift
var body: some Scene {
    WindowGroup {
        MainTabView()
            .environmentObject(authService)
            // ... other environment objects
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
    }
}
```

---

## 📧 EMAIL AUTHENTICATION SETUP

### Enable Email/Password in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to **Authentication** → **Sign-in method**
4. Click **Email/Password**
5. Toggle **Enable** (both options)
6. Click **Save**

**Email auth is now ready!**

---

## 🔥 FIRESTORE SECURITY RULES

Set up security rules for your user data:

1. Go to **Firestore Database** in Firebase Console
2. Click **Rules** tab
3. Replace with these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User profiles - users can only read/write their own data
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }

    // Prayer times cache - read-only for authenticated users
    match /prayerTimes/{city} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }

    // User preferences
    match /userPreferences/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

4. Click **Publish**

---

## 🧪 TESTING

### Test Each Auth Method:

1. **Email**: Should work immediately
   - Try creating a new account
   - Try signing in with existing account
   - App auto-detects if account exists

2. **Apple Sign In**: Should work after enabling capability
   - Use a real device or simulator with Apple ID signed in
   - Test on iOS 13+ device

3. **Google Sign In**: Requires SDK installation
   - Will show setup error until SDK is added
   - After adding SDK, test with Google account

---

## 📝 OPTIONAL: Google Sign In SDK Installation Steps

If you want to enable Google Sign In now:

### 1. Add Package in Xcode
```
File → Add Package Dependencies
URL: https://github.com/google/GoogleSignIn-iOS
Version: Up to Next Major 8.0.0
Target: Dhikr (main app only)
Products: GoogleSignIn, GoogleSignInSwift
```

### 2. Import in Files
Add to top of `GoogleSignInHelper.swift`:
```swift
import GoogleSignIn
import FirebaseCore
```

Add to top of `DhikrApp.swift`:
```swift
import GoogleSignIn
```

### 3. Done!
Rebuild and test Google Sign In button.

---

## 🎉 YOU'RE ALL SET!

Your app now supports:
- ✅ Email/Password (works now)
- ✅ Apple Sign In (works after enabling capability)
- 🔵 Google Sign In (works after adding SDK)

All with a modern, unified authentication UI!
