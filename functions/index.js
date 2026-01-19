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

// =================================================================
// App Store Server Notifications Webhook
// Handles subscription events for referral commission tracking
// =================================================================
exports.appStoreWebhook = functions.https.onRequest(async (req, res) => {
  console.log('📥 Received App Store Server Notification');

  // Only accept POST requests
  if (req.method !== 'POST') {
    console.log('❌ Invalid method:', req.method);
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const notification = req.body;

    // Apple sends a signed JWT - for production, you should verify the signature
    // For now, we'll parse the payload directly
    // The signedPayload contains a JWT with the transaction info

    if (!notification.signedPayload) {
      console.log('⚠️ No signedPayload in notification');
      return res.status(200).send('OK'); // Always return 200 to Apple
    }

    // Decode the JWT payload (middle part)
    // In production, verify the signature using Apple's public key
    const parts = notification.signedPayload.split('.');
    if (parts.length !== 3) {
      console.log('⚠️ Invalid JWT format');
      return res.status(200).send('OK');
    }

    const payloadBase64 = parts[1];
    const payloadJson = Buffer.from(payloadBase64, 'base64').toString('utf8');
    const payload = JSON.parse(payloadJson);

    console.log('📋 Notification type:', payload.notificationType);
    console.log('📋 Subtype:', payload.subtype);

    // Extract transaction info
    const signedTransactionInfo = payload.data?.signedTransactionInfo;
    if (!signedTransactionInfo) {
      console.log('⚠️ No signedTransactionInfo');
      return res.status(200).send('OK');
    }

    // Decode transaction info
    const txParts = signedTransactionInfo.split('.');
    if (txParts.length !== 3) {
      console.log('⚠️ Invalid transaction JWT');
      return res.status(200).send('OK');
    }

    const txPayloadJson = Buffer.from(txParts[1], 'base64').toString('utf8');
    const transactionInfo = JSON.parse(txPayloadJson);

    console.log('💳 Product ID:', transactionInfo.productId);
    console.log('🔑 App Account Token:', transactionInfo.appAccountToken);
    console.log('📝 Original Transaction ID:', transactionInfo.originalTransactionId);

    // Check if this is a referral product
    const isReferralProduct = transactionInfo.productId?.includes('.referral');

    if (!isReferralProduct) {
      console.log('ℹ️ Not a referral product, skipping commission tracking');
      return res.status(200).send('OK');
    }

    // Get the appAccountToken (UUID we attached during purchase)
    const appAccountToken = transactionInfo.appAccountToken;

    if (!appAccountToken) {
      console.log('⚠️ No appAccountToken for referral product');
      return res.status(200).send('OK');
    }

    // Look up the pending commission by appAccountToken
    const pendingDoc = await admin.firestore()
      .collection('pendingCommissions')
      .doc(appAccountToken)
      .get();

    if (!pendingDoc.exists) {
      console.log('⚠️ No pending commission found for token:', appAccountToken);
      return res.status(200).send('OK');
    }

    const pendingData = pendingDoc.data();
    const referralCode = pendingData.referralCode;
    const influencerId = pendingData.influencerId;

    console.log('🎯 Found referral code:', referralCode);
    console.log('👤 Influencer ID:', influencerId);

    // Handle different notification types
    const notificationType = payload.notificationType;

    if (notificationType === 'SUBSCRIBED' || notificationType === 'DID_RENEW') {
      // New subscription or renewal - record commission
      const commissionData = {
        referralCode: referralCode,
        influencerId: influencerId,
        productId: transactionInfo.productId,
        transactionId: transactionInfo.transactionId,
        originalTransactionId: transactionInfo.originalTransactionId,
        appAccountToken: appAccountToken,
        notificationType: notificationType,
        priceInMillis: transactionInfo.price || 0,
        currency: transactionInfo.currency || 'USD',
        purchaseDate: new Date(transactionInfo.purchaseDate),
        environment: transactionInfo.environment || 'Production',
        status: 'pending_payout', // You'll update this when you pay the influencer
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Save to commissions collection
      await admin.firestore()
        .collection('commissions')
        .add(commissionData);

      console.log('✅ Commission recorded for:', referralCode);

      // Update the pending commission status
      await admin.firestore()
        .collection('pendingCommissions')
        .doc(appAccountToken)
        .update({
          status: 'converted',
          convertedAt: admin.firestore.FieldValue.serverTimestamp(),
          transactionId: transactionInfo.transactionId
        });

      // Also update the referral code usage stats
      await admin.firestore()
        .collection('referralCodes')
        .doc(referralCode)
        .update({
          totalRevenue: admin.firestore.FieldValue.increment(transactionInfo.price || 0),
          lastConversionAt: admin.firestore.FieldValue.serverTimestamp()
        });

    } else if (notificationType === 'REFUND' || notificationType === 'REVOKE') {
      // Refund or revoke - mark commission as cancelled
      console.log('💸 Refund/Revoke detected for:', referralCode);

      // Find and update the commission
      const commissionsSnapshot = await admin.firestore()
        .collection('commissions')
        .where('originalTransactionId', '==', transactionInfo.originalTransactionId)
        .get();

      commissionsSnapshot.forEach(async (doc) => {
        await doc.ref.update({
          status: 'cancelled',
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelReason: notificationType
        });
      });
    }

    return res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    // Always return 200 to Apple, even on error
    // Otherwise Apple will keep retrying
    return res.status(200).send('OK');
  }
});
