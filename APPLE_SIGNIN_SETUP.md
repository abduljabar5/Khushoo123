# Apple Sign In Configuration Guide

Complete these steps to finish Apple Sign In setup for Firebase.

---

## 📋 WHAT YOU NEED

From Firebase Console, you received this callback URL:
```
https://khushoo-ddcf6.firebaseapp.com/__/auth/handler
```

You'll add this to your Apple Developer Console.

---

## 🍎 STEP 1: APPLE DEVELOPER CONSOLE SETUP

### A. Log in to Apple Developer

1. Go to [Apple Developer Console](https://developer.apple.com/account)
2. Sign in with your Apple Developer account
3. Navigate to **Certificates, Identifiers & Profiles**

### B. Find Your App Identifier

1. Click **Identifiers** in the left sidebar
2. Find your app's Bundle ID: `fm.mrc.Dhikr`
3. Click on it to open settings

### C. Enable Sign in with Apple

1. Scroll down to **Capabilities** section
2. Find **Sign in with Apple**
3. Check the box to enable it
4. Click **Edit** button next to "Sign in with Apple"

### D. Add Firebase Callback URL

1. In the Sign in with Apple configuration:
   - You'll see **Website URLs** or **Return URLs** section
   - Click **+** or **Add** button
   - Paste this URL:
     ```
     https://khushoo-ddcf6.firebaseapp.com/__/auth/handler
     ```
   - Add another domain if prompted:
     ```
     khushoo-ddcf6.firebaseapp.com
     ```

2. Click **Save**
3. Click **Continue** at the top right
4. Click **Save** again to save your App ID changes

---

## 🌐 STEP 2: DOMAIN VERIFICATION (If Required)

Apple may ask you to verify domain ownership. Here's how:

### Option A: Firebase Handles This Automatically

Firebase should handle domain verification automatically. If you see a verification pending message, wait 5-10 minutes and refresh.

### Option B: Manual Verification (If Needed)

If Apple requires manual verification:

1. Apple will provide you with a verification file or code
2. Go to Firebase Console → **Authentication** → **Settings** → **Authorized Domains**
3. Verify that `khushoo-ddcf6.firebaseapp.com` is listed
4. Firebase automatically serves the Apple verification file

**Most of the time, you don't need to do anything - Firebase handles it!**

---

## ✅ STEP 3: VERIFY SETUP IN XCODE

### A. Check App Configuration

1. Open your project in Xcode
2. Select **Dhikr** target
3. Go to **Signing & Capabilities**
4. Verify **Sign in with Apple** capability is added
5. Check that **Team** is set correctly
6. Verify **Bundle Identifier** matches: `fm.mrc.Dhikr`

### B. Verify Entitlements File

Your entitlements file should include:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

This is added automatically when you add the capability.

---

## 🔥 STEP 4: COMPLETE FIREBASE CONFIGURATION

### A. Enable Apple Sign In Provider

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **khushoo-ddcf6**
3. Go to **Authentication** → **Sign-in method**
4. Click **Apple** provider
5. Toggle **Enable**
6. You should see the callback URL displayed
7. Click **Save**

### B. Add Service ID (Optional - For Web)

If you plan to use Apple Sign In on web:

1. Back in Apple Developer Console
2. Go to **Identifiers**
3. Click **+** to create new identifier
4. Select **Services IDs**
5. Follow the wizard and add the same Firebase callback URL

**For iOS-only apps, you can skip this!**

---

## 🧪 STEP 5: TEST APPLE SIGN IN

### Prerequisites

- Physical iOS device **OR** iOS Simulator with Apple ID signed in
- iOS 13 or later
- Internet connection

### Testing Steps

1. Run your app on device/simulator
2. Go to **Profile** tab
3. Tap **Sign In**
4. Select **Continue with Apple**
5. Native Apple Sign In sheet should appear
6. Choose to use Apple ID or create account
7. Authenticate with Face ID/Touch ID/Password
8. Review the information Apple shares
9. Click **Continue**

### Expected Behavior

✅ Success:
- User is signed in
- Profile shows user's name (if they shared it)
- "Member since [date]" appears
- Sign In button changes to Sign Out

❌ If it fails:
- Check error message
- Verify callback URL in Apple Developer Console
- Ensure capability is enabled in Xcode
- Check Firebase Console has Apple provider enabled

---

## 🔍 TROUBLESHOOTING

### Error: "Invalid Client"

**Fix:** Check that:
- Bundle ID matches in Xcode and Apple Developer Console
- Sign in with Apple capability is enabled in Xcode
- You saved changes in Apple Developer Console

### Error: "Invalid Redirect URI"

**Fix:**
- Verify callback URL is exactly:
  ```
  https://khushoo-ddcf6.firebaseapp.com/__/auth/handler
  ```
- No trailing slashes or extra characters
- Domain is verified in Apple Developer Console

### Error: "The operation couldn't be completed"

**Fix:**
- Make sure device/simulator has Apple ID signed in
- Check internet connection
- Try signing out and back in to iCloud on device

### Sign In Sheet Doesn't Appear

**Fix:**
- Verify iOS 13 or later
- Check that Sign in with Apple capability is added
- Rebuild the app after adding capability
- Test on a real device if simulator fails

---

## 📝 QUICK CHECKLIST

Use this checklist to verify everything is set up:

### Xcode Setup
- [ ] Sign in with Apple capability added to Dhikr target
- [ ] Bundle ID is `fm.mrc.Dhikr`
- [ ] Team is selected in Signing & Capabilities
- [ ] App builds without errors

### Apple Developer Console
- [ ] App ID has Sign in with Apple enabled
- [ ] Firebase callback URL added: `https://khushoo-ddcf6.firebaseapp.com/__/auth/handler`
- [ ] Changes saved

### Firebase Console
- [ ] Apple provider is enabled in Authentication
- [ ] Callback URL is displayed correctly

### Testing
- [ ] App runs on device/simulator
- [ ] Apple Sign In button appears in auth screen
- [ ] Can tap and see native Apple Sign In sheet
- [ ] Successfully signs in and shows user data

---

## 🎉 YOU'RE DONE!

Once all checkboxes are complete, Apple Sign In is fully configured and ready to use!

### What Happens When User Signs In:

1. User taps "Continue with Apple"
2. Native iOS sheet appears
3. User authenticates with Face ID/Touch ID
4. Apple shares name and email (user can hide email)
5. Firebase creates user account
6. Your app saves user to Firestore
7. Profile page updates with user info

---

## 📚 ADDITIONAL RESOURCES

- [Apple Sign In Documentation](https://developer.apple.com/sign-in-with-apple/)
- [Firebase Apple Sign In Guide](https://firebase.google.com/docs/auth/ios/apple)
- [Apple Developer Console](https://developer.apple.com/account)
- [Firebase Console](https://console.firebase.google.com)

---

## 💡 PRO TIPS

1. **Privacy**: Apple lets users hide their email. Your app will receive a private relay email like `abc123@privaterelay.appleid.com`

2. **Name**: Users can edit their name before sharing. It's only provided on first sign-in.

3. **Testing**: Use different Apple IDs to test new vs returning users

4. **Production**: Apple Sign In works in both debug and release builds, no additional setup needed

5. **Revoke**: Users can revoke access in Settings → Apple ID → Password & Security → Apps Using Your Apple ID

---

Need help? Check the troubleshooting section or refer to the main `FIREBASE_SETUP.md` guide!
