const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {google} = require('googleapis');

admin.initializeApp();

/**
 * Cloud Function to handle Google Play Real-Time Developer Notifications
 * 
 * This function receives notifications from Google Play when subscription events occur:
 * - Purchase, renewal, cancellation, expiration, etc.
 * 
 * URL to configure in Play Console:
 * https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net/handlePlayStoreNotification
 */
exports.handlePlayStoreNotification = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Received Play Store notification');
    
    // Verify the notification is from Google (Pub/Sub format)
    const message = req.body.message;
    if (!message) {
      console.error('No message in request body');
      res.status(400).send('No message');
      return;
    }

    // Decode the base64-encoded notification data
    const data = JSON.parse(
      Buffer.from(message.data, 'base64').toString('utf-8')
    );

    console.log('Decoded notification:', JSON.stringify(data, null, 2));

    // Handle subscription notifications
    if (data.subscriptionNotification) {
      await handleSubscriptionNotification(data.subscriptionNotification);
    } else if (data.testNotification) {
      console.log('Test notification received - setup successful!');
    } else {
      console.log('Unknown notification type:', data);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing notification:', error);
    res.status(500).send('Error: ' + error.message);
  }
});

/**
 * Handle subscription lifecycle notifications
 */
async function handleSubscriptionNotification(notification) {
  const {
    notificationType,
    purchaseToken,
    subscriptionId,
  } = notification;

  console.log(`Processing notification type ${notificationType} for subscription ${subscriptionId}`);

  // Get purchase details from Google Play API
  const purchaseDetails = await verifySubscription(subscriptionId, purchaseToken);

  if (!purchaseDetails) {
    console.error('Could not verify purchase with Google Play API');
    return;
  }

  // Extract user ID from obfuscatedExternalAccountId
  // This should be the Firebase UID that was passed during purchase
  const userId = purchaseDetails.obfuscatedExternalAccountId;
  
  if (!userId) {
    console.error('No user ID found in purchase details');
    return;
  }

  console.log(`User ID: ${userId}`);

  // Handle different notification types
  switch (notificationType) {
    case 1: // SUBSCRIPTION_RECOVERED
      console.log('Subscription recovered from account hold');
      await grantPremium(userId, purchaseDetails);
      break;

    case 2: // SUBSCRIPTION_RENEWED
      console.log('Subscription renewed');
      await grantPremium(userId, purchaseDetails);
      break;

    case 3: // SUBSCRIPTION_CANCELED
      console.log('Subscription cancelled by user');
      // User cancelled but still has access until expiry
      await markSubscriptionCancelled(userId, purchaseDetails);
      break;

    case 4: // SUBSCRIPTION_PURCHASED
      console.log('New subscription purchased');
      await grantPremium(userId, purchaseDetails);
      break;

    case 5: // SUBSCRIPTION_ON_HOLD
      console.log('Subscription on hold (payment issue)');
      await markSubscriptionAtRisk(userId, purchaseDetails, 'on_hold');
      break;

    case 6: // SUBSCRIPTION_IN_GRACE_PERIOD
      console.log('Subscription in grace period (payment issue)');
      await markSubscriptionAtRisk(userId, purchaseDetails, 'grace_period');
      break;

    case 7: // SUBSCRIPTION_RESTARTED
      console.log('Subscription restarted');
      await grantPremium(userId, purchaseDetails);
      break;

    case 10: // SUBSCRIPTION_PAUSED
      console.log('Subscription paused');
      await pauseSubscription(userId);
      break;

    case 12: // SUBSCRIPTION_REVOKED
      console.log('Subscription revoked (refund issued)');
      // Refund issued, revoke immediately
      await revokePremium(userId);
      break;

    case 13: // SUBSCRIPTION_EXPIRED
      console.log('Subscription expired');
      // Subscription has expired, revoke access
      await revokePremium(userId);
      break;

    default:
      console.log(`Unhandled notification type: ${notificationType}`);
  }
}

/**
 * Verify subscription with Google Play Developer API
 */
async function verifySubscription(subscriptionId, purchaseToken) {
  try {
    // Use Application Default Credentials (automatically available in Cloud Functions)
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const androidPublisher = google.androidpublisher({
      version: 'v3',
      auth: auth,
    });

    const response = await androidPublisher.purchases.subscriptions.get({
      packageName: 'com.heatbubble.app',
      subscriptionId: subscriptionId,
      token: purchaseToken,
    });

    console.log('Purchase verified successfully');
    return response.data;
  } catch (error) {
    console.error('Error verifying subscription:', error.message);
    return null;
  }
}

/**
 * Grant premium access to user
 */
async function grantPremium(userId, purchaseDetails) {
  try {
    const expiryDate = new Date(parseInt(purchaseDetails.expiryTimeMillis));
    
    await admin.firestore().collection('subscriptions').doc(userId).set({
      isPremium: true,
      productId: purchaseDetails.productId || purchaseDetails.subscriptionId,
      purchaseToken: purchaseDetails.purchaseToken,
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      status: 'active',
      autoRenewing: purchaseDetails.autoRenewing || false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`✅ Granted premium to user ${userId} until ${expiryDate.toISOString()}`);
  } catch (error) {
    console.error('Error granting premium:', error);
    throw error;
  }
}

/**
 * Revoke premium access from user
 */
async function revokePremium(userId) {
  try {
    await admin.firestore().collection('subscriptions').doc(userId).set({
      isPremium: false,
      status: 'expired',
      autoRenewing: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`❌ Revoked premium from user ${userId}`);
  } catch (error) {
    console.error('Error revoking premium:', error);
    throw error;
  }
}

/**
 * Mark subscription as cancelled (still active until expiry)
 */
async function markSubscriptionCancelled(userId, purchaseDetails) {
  try {
    const expiryDate = new Date(parseInt(purchaseDetails.expiryTimeMillis));
    
    await admin.firestore().collection('subscriptions').doc(userId).set({
      isPremium: true, // Still premium until expiry
      status: 'cancelled',
      expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
      autoRenewing: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`⚠️ Marked subscription as cancelled for user ${userId} (active until ${expiryDate.toISOString()})`);
  } catch (error) {
    console.error('Error marking subscription as cancelled:', error);
    throw error;
  }
}

/**
 * Mark subscription at risk (payment issues)
 */
async function markSubscriptionAtRisk(userId, purchaseDetails, riskType) {
  try {
    await admin.firestore().collection('subscriptions').doc(userId).set({
      isPremium: true, // Keep premium during grace period
      status: riskType,
      autoRenewing: purchaseDetails.autoRenewing || false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`⚠️ Marked subscription at risk (${riskType}) for user ${userId}`);
  } catch (error) {
    console.error('Error marking subscription at risk:', error);
    throw error;
  }
}

/**
 * Pause subscription
 */
async function pauseSubscription(userId) {
  try {
    await admin.firestore().collection('subscriptions').doc(userId).set({
      isPremium: false,
      status: 'paused',
      autoRenewing: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`⏸️ Paused subscription for user ${userId}`);
  } catch (error) {
    console.error('Error pausing subscription:', error);
    throw error;
  }
}
