const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Send silent notification every 6 hours to update rolling window
exports.sendPrayerTimeRefreshNotification = functions.pubsub
  .schedule('every 6 hours')
  .timeZone('America/New_York') // Change to your timezone if needed
  .onRun(async (context) => {
    console.log('🔄 Sending rolling window update notifications');

    try {
      // Get all FCM tokens from Firestore
      const tokensSnapshot = await admin.firestore()
        .collection('fcmTokens')
        .get();

      if (tokensSnapshot.empty) {
        console.log('⚠️ No FCM tokens found');
        return null;
      }

      const tokens = [];
      tokensSnapshot.forEach((doc) => {
        const token = doc.data().token;
        if (token) {
          tokens.push(token);
        }
      });

      console.log(`📱 Sending to ${tokens.length} devices`);

      // Create silent notification for rolling window update (NOT prayer time fetch)
      const message = {
        data: {
          refreshType: 'prayerTimeUpdate',
          timestamp: Date.now().toString(),
          action: 'updateRollingWindow'
        },
        apns: {
          headers: {
            'apns-priority': '5',
            'apns-push-type': 'background'
          },
          payload: {
            aps: {
              'content-available': 1
            }
          }
        },
        tokens: tokens
      };

      // Send to all devices
      const response = await admin.messaging().sendMulticast(message);

      console.log(`✅ Successfully sent: ${response.successCount}`);
      console.log(`❌ Failed: ${response.failureCount}`);

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const tokensToRemove = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.log(`❌ Failed token: ${tokens[idx]}`);
            tokensToRemove.push(tokens[idx]);
          }
        });

        // Remove invalid tokens from Firestore
        await Promise.all(
          tokensToRemove.map(token =>
            admin.firestore()
              .collection('fcmTokens')
              .where('token', '==', token)
              .get()
              .then(snapshot => {
                snapshot.forEach(doc => doc.ref.delete());
              })
          )
        );

        console.log(`🗑️ Removed ${tokensToRemove.length} invalid tokens`);
      }

      return null;
    } catch (error) {
      console.error('❌ Error sending notifications:', error);
      return null;
    }
  });

// Save FCM token when device registers
exports.saveFCMToken = functions.https.onCall(async (data, context) => {
  const { token, userId } = data;

  if (!token) {
    throw new functions.https.HttpsError('invalid-argument', 'Token is required');
  }

  try {
    // Save token to Firestore (using token as doc ID to prevent duplicates)
    await admin.firestore()
      .collection('fcmTokens')
      .doc(token)
      .set({
        token: token,
        userId: userId || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        platform: 'ios',
        appVersion: data.appVersion || 'unknown'
      }, { merge: true });

    console.log('✅ FCM token saved:', token.substring(0, 20) + '...');
    return { success: true };
  } catch (error) {
    console.error('❌ Error saving token:', error);
    throw new functions.https.HttpsError('internal', 'Failed to save token');
  }
});
