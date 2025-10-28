// functions/index.js
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');

try { admin.app(); } catch { admin.initializeApp(); }

// Optional: reduce noisy logs
setGlobalOptions({ region: 'asia-south1', memory: '256MiB', timeoutSeconds: 30 });

/**
 * Fires when an assistant message flips from approved:false -> approved:true.
 * Path must match your app writes: chats/{chatId}/messages/{messageId}
 */
exports.notifyOnAssistantApproval = onDocumentUpdated(
  {
    document: 'chats/{chatId}/messages/{messageId}',
    region: 'asia-south1',
    retry: true, // retry transient FCM failures
  },
  async (event) => {
    const before = event?.data?.before?.data();
    const after  = event?.data?.after?.data();
    const { chatId, messageId } = event.params || {};

    // Defensive guards
    if (!before || !after) return;
    // Only assistant messages
    if ((after.sender || '') !== 'assistant') return;

    // We only care about the transition false/undefined -> true
    const wasApproved = Boolean(before.approved === true);
    const isApproved  = Boolean(after.approved === true);
    if (wasApproved || !isApproved) return;

    // Log what we saw (helps in debugging)
    console.log('Approval detected', { chatId, messageId, parentId: after.parentId });

    // Fetch tokens from users/{chatId}.fcmTokens
    const userDoc = await admin.firestore().collection('users').doc(chatId).get();
    const tokensObj = userDoc.exists ? (userDoc.get('fcmTokens') || {}) : {};
    const tokens = Object.keys(tokensObj).filter(Boolean);

    if (!tokens.length) {
      console.warn('No FCM tokens for user', { chatId });
      return;
    }

    // Compose notification shown to the user
    const notificationTitle = '✅ Reply by Dr.Kanhaiya for you';
    // Keep the body short; Android/iOS can truncate long text in the tray
    const preview = (after.text || '').toString().replace(/\s+/g, ' ').trim();
    const body = preview.length > 160 ? preview.slice(0, 157) + '…' : preview;

    // You can deep link the app using "data"
    const dataPayload = {
      route: '/chat',                 // your app can read this and navigate
      chatId: chatId || '',
      messageId: messageId || '',
      // you can add parentId to jump to the thread:
      parentId: (after.parentId || ''),
    };

    const message = {
      tokens,
      notification: {
        title: notificationTitle,
        body,
      },
      android: {
        notification: {
          channelId: 'chat_channel',  // must exist in app
          sound: 'default',
          priority: 'HIGH',
        },
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: false,
          },
        },
      },
      data: dataPayload,
    };

    const resp = await admin.messaging().sendEachForMulticast(message);
    console.log('FCM summary', { successCount: resp.successCount, failureCount: resp.failureCount, tokens: tokens.length });

    // Print per-token failures for fast diagnosis
    resp.responses.forEach((r, i) => {
      if (!r.success) {
        console.error('FCM error', {
          token: tokens[i],
          code: r.error?.code,
          msg: r.error?.message,
        });
      }
    });

    // Optional: clean up invalid tokens on NotRegistered
    const invalid = [];
    resp.responses.forEach((r, i) => {
      if (!r.success && (r.error?.code === 'messaging/registration-token-not-registered')) {
        invalid.push(tokens[i]);
      }
    });
    if (invalid.length) {
      const updates = {};
      invalid.forEach(t => updates[`fcmTokens.${t}`] = admin.firestore.FieldValue.delete());
      await admin.firestore().collection('users').doc(chatId).set(updates, { merge: true });
      console.log('Pruned invalid tokens', { count: invalid.length });
    }
  }
);
