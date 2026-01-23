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
// Comprehensive tracking for referral/influencer commission system
// Tracks: trials, first payment, renewals, cancellations, refunds
// Payment logic can be changed server-side without app updates
// =================================================================
exports.appStoreWebhook = functions.https.onRequest(async (req, res) => {
  console.log('📥 Received App Store Server Notification');

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const notification = req.body;

    if (!notification.signedPayload) {
      console.log('⚠️ No signedPayload');
      return res.status(200).send('OK');
    }

    // Decode the JWT payload
    const parts = notification.signedPayload.split('.');
    if (parts.length !== 3) return res.status(200).send('OK');

    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
    const notificationType = payload.notificationType;
    const subtype = payload.subtype || null;

    console.log('📋 Type:', notificationType, '| Subtype:', subtype);

    // Extract transaction info
    const signedTransactionInfo = payload.data?.signedTransactionInfo;
    if (!signedTransactionInfo) return res.status(200).send('OK');

    const txParts = signedTransactionInfo.split('.');
    if (txParts.length !== 3) return res.status(200).send('OK');

    const transactionInfo = JSON.parse(Buffer.from(txParts[1], 'base64').toString('utf8'));

    // Also extract renewal info if available
    let renewalInfo = null;
    const signedRenewalInfo = payload.data?.signedRenewalInfo;
    if (signedRenewalInfo) {
      const renewalParts = signedRenewalInfo.split('.');
      if (renewalParts.length === 3) {
        renewalInfo = JSON.parse(Buffer.from(renewalParts[1], 'base64').toString('utf8'));
      }
    }

    const productId = transactionInfo.productId;
    const appAccountToken = transactionInfo.appAccountToken;
    const originalTransactionId = transactionInfo.originalTransactionId;
    const transactionId = transactionInfo.transactionId;
    const priceInMillis = transactionInfo.price || 0;
    const priceInCents = Math.round(priceInMillis / 10); // Convert millicents to cents
    const currency = transactionInfo.currency || 'USD';
    const environment = transactionInfo.environment || 'Production';
    const offerType = transactionInfo.offerType; // 1=intro/trial, 2=promo, 3=offer code

    // Determine if monthly or annual subscription
    const isMonthly = productId?.includes('.monthly');
    const isAnnual = productId?.includes('.yearly');

    console.log('💳 Product:', productId, '| Price:', priceInCents, 'cents', currency);
    console.log('🔑 Token:', appAccountToken);

    // Normalize token to uppercase (iOS stores uppercase, Apple sends lowercase)
    const normalizedToken = appAccountToken ? appAccountToken.toUpperCase() : null;
    console.log('🔑 Normalized Token:', normalizedToken);

    // Check if referral product
    const isReferralProduct = productId?.includes('.referral');
    if (!isReferralProduct) {
      console.log('ℹ️ Not a referral product, skipping');
      return res.status(200).send('OK');
    }

    if (!normalizedToken) {
      console.log('⚠️ No appAccountToken');
      return res.status(200).send('OK');
    }

    // Look up pending commission
    const pendingDoc = await admin.firestore()
      .collection('pendingCommissions')
      .doc(normalizedToken)
      .get();

    if (!pendingDoc.exists) {
      console.log('⚠️ No pending commission for token');
      return res.status(200).send('OK');
    }

    const pendingData = pendingDoc.data();
    const referralCode = pendingData.referralCode;
    const influencerId = pendingData.influencerId;

    console.log('🎯 Referral:', referralCode, '| Influencer:', influencerId);

    // =========================================================
    // COMPREHENSIVE EVENT TRACKING
    // =========================================================

    const eventData = {
      referralCode,
      influencerId,
      productId,
      transactionId,
      originalTransactionId,
      appAccountToken,
      notificationType,
      subtype,
      offerType: offerType || null,
      priceInMillis,
      currency,
      environment,
      purchaseDate: transactionInfo.purchaseDate ? new Date(transactionInfo.purchaseDate) : null,
      expiresDate: transactionInfo.expiresDate ? new Date(transactionInfo.expiresDate) : null,
      autoRenewStatus: renewalInfo?.autoRenewStatus || null,
      autoRenewProductId: renewalInfo?.autoRenewProductId || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Log EVERY event for complete history
    await admin.firestore()
      .collection('subscriptionEvents')
      .add(eventData);

    // =========================================================
    // HANDLE SPECIFIC EVENT TYPES
    // =========================================================

    const codeRef = admin.firestore().collection('referralCodes').doc(referralCode);
    const pendingRef = admin.firestore().collection('pendingCommissions').doc(normalizedToken);

    // Check if this is the FIRST payment for this subscription
    const existingPayments = await admin.firestore()
      .collection('payments')
      .where('originalTransactionId', '==', originalTransactionId)
      .where('referralCode', '==', referralCode)
      .get();

    const isFirstPayment = existingPayments.empty;
    const isTrialStart = notificationType === 'SUBSCRIBED' && offerType === 1;
    const isPaidEvent = notificationType === 'DID_RENEW' ||
                        (notificationType === 'SUBSCRIBED' && offerType !== 1);

    // ---------------------------------------------------------
    // TRIAL STARTED
    // ---------------------------------------------------------
    if (isTrialStart) {
      console.log('🆓 TRIAL STARTED');

      const trialUpdate = {
        trialCount: admin.firestore.FieldValue.increment(1),
        lastTrialAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Increment active subscriber count
      if (isMonthly) {
        trialUpdate.activeMonthlySubscribers = admin.firestore.FieldValue.increment(1);
        console.log('📈 +1 active monthly subscriber');
      } else if (isAnnual) {
        trialUpdate.activeAnnualSubscribers = admin.firestore.FieldValue.increment(1);
        console.log('📈 +1 active annual subscriber');
      }

      await codeRef.update(trialUpdate);

      await pendingRef.update({
        status: 'trial_started',
        trialStartedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // ---------------------------------------------------------
    // PAID EVENT (First payment or renewal)
    // ---------------------------------------------------------
    else if (isPaidEvent) {
      console.log('💰 PAID EVENT | First payment:', isFirstPayment);

      // Record payment
      const paymentData = {
        referralCode,
        influencerId,
        productId,
        transactionId,
        originalTransactionId,
        appAccountToken,
        priceInMillis,
        currency,
        environment,
        isFirstPayment,
        isRenewal: !isFirstPayment,
        renewalNumber: existingPayments.size + 1,
        notificationType,
        subtype,
        purchaseDate: transactionInfo.purchaseDate ? new Date(transactionInfo.purchaseDate) : null,
        // Commission tracking
        commissionStatus: 'pending', // pending, approved, paid, cancelled
        commissionAmount: null, // Set this when you calculate commission
        commissionPaidAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      };

      await admin.firestore().collection('payments').add(paymentData);

      // Update referral code stats (revenue in cents)
      const updateData = {
        totalRevenue: admin.firestore.FieldValue.increment(priceInCents),
        totalPayments: admin.firestore.FieldValue.increment(1),
        lastPaymentAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // If direct purchase (SUBSCRIBED without trial), increment active subscriber count
      if (notificationType === 'SUBSCRIBED') {
        if (isMonthly) {
          updateData.activeMonthlySubscribers = admin.firestore.FieldValue.increment(1);
          console.log('📈 +1 active monthly subscriber (direct purchase)');
        } else if (isAnnual) {
          updateData.activeAnnualSubscribers = admin.firestore.FieldValue.increment(1);
          console.log('📈 +1 active annual subscriber (direct purchase)');
        }
      }

      if (isFirstPayment) {
        // First payment = conversion (always 499 cents / $4.99 regardless of plan)
        const FIRST_PAYMENT_CREDIT = 499;
        updateData.paidConversions = admin.firestore.FieldValue.increment(1);
        updateData.firstPaymentRevenue = admin.firestore.FieldValue.increment(FIRST_PAYMENT_CREDIT);
      } else {
        // Renewal
        updateData.renewalCount = admin.firestore.FieldValue.increment(1);
        updateData.renewalRevenue = admin.firestore.FieldValue.increment(priceInCents);
      }

      await codeRef.update(updateData);

      // Update pending commission
      await pendingRef.update({
        status: isFirstPayment ? 'first_payment' : 'renewed',
        lastPaymentAt: admin.firestore.FieldValue.serverTimestamp(),
        totalPaid: admin.firestore.FieldValue.increment(priceInCents)
      });
    }

    // ---------------------------------------------------------
    // CANCELLATION (user turned off auto-renew)
    // ---------------------------------------------------------
    else if (notificationType === 'DID_CHANGE_RENEWAL_STATUS' && subtype === 'AUTO_RENEW_DISABLED') {
      console.log('⏸️ AUTO-RENEW DISABLED');

      await codeRef.update({
        cancellationCount: admin.firestore.FieldValue.increment(1),
        lastCancellationAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await pendingRef.update({
        status: 'cancelled_auto_renew',
        cancelledAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // ---------------------------------------------------------
    // REACTIVATION (user turned auto-renew back on)
    // ---------------------------------------------------------
    else if (notificationType === 'DID_CHANGE_RENEWAL_STATUS' && subtype === 'AUTO_RENEW_ENABLED') {
      console.log('▶️ AUTO-RENEW RE-ENABLED');

      await codeRef.update({
        reactivationCount: admin.firestore.FieldValue.increment(1),
        lastReactivationAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await pendingRef.update({
        status: 'reactivated',
        reactivatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // ---------------------------------------------------------
    // REFUND
    // ---------------------------------------------------------
    else if (notificationType === 'REFUND') {
      console.log('💸 REFUND');

      // Check if this was a first payment refund
      const paymentsToRefund = await admin.firestore()
        .collection('payments')
        .where('transactionId', '==', transactionId)
        .get();

      const wasFirstPayment = paymentsToRefund.docs.some(doc => doc.data().isFirstPayment === true);

      const refundUpdate = {
        refundCount: admin.firestore.FieldValue.increment(1),
        refundedRevenue: admin.firestore.FieldValue.increment(priceInCents),
        lastRefundAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // If first payment was refunded, subtract from commission
      if (wasFirstPayment) {
        const FIRST_PAYMENT_CREDIT = 499;
        refundUpdate.firstPaymentRevenue = admin.firestore.FieldValue.increment(-FIRST_PAYMENT_CREDIT);
        refundUpdate.paidConversions = admin.firestore.FieldValue.increment(-1);
        console.log('💸 First payment refunded - subtracting 499 cents from commission');
      }

      // Decrement active subscriber count
      if (isMonthly) {
        refundUpdate.activeMonthlySubscribers = admin.firestore.FieldValue.increment(-1);
        console.log('📉 -1 active monthly subscriber (refund)');
      } else if (isAnnual) {
        refundUpdate.activeAnnualSubscribers = admin.firestore.FieldValue.increment(-1);
        console.log('📉 -1 active annual subscriber (refund)');
      }

      await codeRef.update(refundUpdate);

      for (const doc of paymentsToRefund.docs) {
        await doc.ref.update({
          commissionStatus: 'refunded',
          refundedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      await pendingRef.update({
        status: 'refunded',
        refundedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // ---------------------------------------------------------
    // EXPIRED (subscription ended)
    // ---------------------------------------------------------
    else if (notificationType === 'EXPIRED') {
      console.log('⏰ EXPIRED | Subtype:', subtype);

      const expiredUpdate = {
        expiredCount: admin.firestore.FieldValue.increment(1),
        lastExpiredAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Decrement active subscriber count
      if (isMonthly) {
        expiredUpdate.activeMonthlySubscribers = admin.firestore.FieldValue.increment(-1);
        console.log('📉 -1 active monthly subscriber (expired)');
      } else if (isAnnual) {
        expiredUpdate.activeAnnualSubscribers = admin.firestore.FieldValue.increment(-1);
        console.log('📉 -1 active annual subscriber (expired)');
      }

      await codeRef.update(expiredUpdate);

      await pendingRef.update({
        status: 'expired',
        expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        expiredReason: subtype
      });
    }

    // ---------------------------------------------------------
    // GRACE PERIOD / BILLING RETRY
    // ---------------------------------------------------------
    else if (notificationType === 'DID_FAIL_TO_RENEW') {
      console.log('⚠️ BILLING FAILED');

      await codeRef.update({
        billingFailureCount: admin.firestore.FieldValue.increment(1),
        lastBillingFailureAt: admin.firestore.FieldValue.serverTimestamp()
      });

      await pendingRef.update({
        status: 'billing_failed',
        billingFailedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    console.log('✅ Event processed successfully');
    return res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Webhook error:', error);
    return res.status(200).send('OK'); // Always 200 to Apple
  }
});
