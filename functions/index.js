// functions/index.js

// ---------- Core & Admin ----------
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

try { admin.app(); } catch { admin.initializeApp(); }

setGlobalOptions({ region: 'asia-south1', memory: '256MiB', timeoutSeconds: 30 });

// ---------- Existing: Chat approval → FCM ----------
exports.notifyOnAssistantApproval = onDocumentUpdated(
  {
    document: 'chats/{chatId}/messages/{messageId}',
    region: 'asia-south1',
    retry: true,
  },
  async (event) => {
    const before = event?.data?.before?.data();
    const after  = event?.data?.after?.data();
    const { chatId, messageId } = event.params || {};
    if (!before || !after) return;
    if ((after.sender || '') !== 'assistant') return;

    const wasApproved = Boolean(before.approved === true);
    const isApproved  = Boolean(after.approved === true);
    if (wasApproved || !isApproved) return;

    console.log('Approval detected', { chatId, messageId, parentId: after.parentId });

    const userDoc = await admin.firestore().collection('users').doc(chatId).get();
    const tokensObj = userDoc.exists ? (userDoc.get('fcmTokens') || {}) : {};
    const tokens = Object.keys(tokensObj).filter(Boolean);
    if (!tokens.length) {
      console.warn('No FCM tokens for user', { chatId });
      return;
    }

    const title = '✅ Reply by Dr.Kanhaiya for you';
    const preview = (after.text || '').toString().replace(/\s+/g, ' ').trim();
    const body = preview.length > 160 ? preview.slice(0, 157) + '…' : preview;

    const message = {
      tokens,
      notification: { title, body },
      android: { notification: { channelId: 'chat_channel', sound: 'default', priority: 'HIGH' }, priority: 'high' },
      apns: { payload: { aps: { sound: 'default', contentAvailable: false } } },
      data: {
        route: '/chat',
        chatId: chatId || '',
        messageId: messageId || '',
        parentId: (after.parentId || ''),
      },
    };

    const resp = await admin.messaging().sendEachForMulticast(message);
    console.log('FCM summary', { successCount: resp.successCount, failureCount: resp.failureCount, tokens: tokens.length });

    const invalid = [];
    resp.responses.forEach((r, i) => {
      if (!r.success) {
        console.error('FCM error', { token: tokens[i], code: r.error?.code, msg: r.error?.message });
        if (r.error?.code === 'messaging/registration-token-not-registered') invalid.push(tokens[i]);
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

// ---------- Razorpay Subscriptions ----------
const Razorpay = require('razorpay');
const crypto = require('crypto');

// v2 Secrets (set with `firebase functions:secrets:set ...`)
const RZP_KEY_ID     = defineSecret('RAZORPAY_KEY_ID');
const RZP_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');

// Plans + webhook secret now come from **dotenv env vars** (functions/.env)
const PLAN_MONTHLY    = () => process.env.RAZORPAY_PLAN_MONTHLY;     // e.g. plan_XXXX (test/live as per keys)
const PLAN_YEARLY     = () => process.env.RAZORPAY_PLAN_YEARLY;      // e.g. plan_YYYY
const WEBHOOK_SECRET  = () => process.env.RAZORPAY_WEBHOOK_SECRET;   // same string you type in Razorpay dashboard

function rzpClient(keyId, keySecret) {
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}

// Create subscription
exports.subsCreate = onCall(
  { region: 'asia-south1', secrets: [RZP_KEY_ID, RZP_KEY_SECRET], timeoutSeconds: 30, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');

      const uid  = req.auth.uid;
      const kind = (req.data?.kind || 'monthly').toString(); // 'monthly' | 'yearly'
      const planId = (kind === 'yearly') ? PLAN_YEARLY() : PLAN_MONTHLY();
      if (!planId) throw new HttpsError('failed-precondition', 'Plan ID not configured in env (.env)');

      const keyId     = RZP_KEY_ID.value();
      const keySecret = RZP_KEY_SECRET.value();

      const rzp = rzpClient(keyId, keySecret);
      const total_count = (kind === 'yearly') ? 100 : 1200; // long running

      const sub = await rzp.subscriptions.create({
        plan_id: planId,
        total_count,
        customer_notify: true,
        notes: { uid, kind },
      });

      await admin.firestore().collection('users').doc(uid)
        .collection('subscriptions').doc(sub.id).set({
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: sub.status,
          plan_id: planId,
          kind,
          total_count,
        }, { merge: true });

      return { subscriptionId: sub.id, keyId, kind };
    } catch (err) {
      console.error('subsCreate error:', err?.message || err, err?.error || err?.response || '');
      const msg = err?.error?.description || err?.message || 'Unknown server error';
      const code = err?.statusCode === 404 ? 'not-found'
                  : err?.statusCode === 400 ? 'invalid-argument'
                  : 'internal';
      throw new HttpsError(code, msg);
    }
  }
);

// Verify first payment for subscription
exports.subsVerify = onCall(
  { region: 'asia-south1', secrets: [RZP_KEY_SECRET], timeoutSeconds: 30, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');

      const { razorpay_payment_id, razorpay_subscription_id, razorpay_signature } = req.data || {};
      if (!razorpay_payment_id || !razorpay_subscription_id || !razorpay_signature) {
        throw new HttpsError('invalid-argument', 'Missing verification fields');
      }

      const keySecret = RZP_KEY_SECRET.value();

      const expected = crypto.createHmac('sha256', keySecret)
        .update(`${razorpay_payment_id}|${razorpay_subscription_id}`)
        .digest('hex');

      if (expected !== razorpay_signature) throw new HttpsError('permission-denied', 'Invalid signature');

      const uid = req.auth.uid;
      const userRef = admin.firestore().collection('users').doc(uid);
      const subRef  = userRef.collection('subscriptions').doc(razorpay_subscription_id);

      let kind = 'monthly';
      const snap = await subRef.get();
      if (snap.exists) kind = (snap.data().kind || 'monthly');

      await userRef.set({
        subscription: {
          status: 'active',
          subscriptionId: razorpay_subscription_id,
          plan: (kind === 'yearly') ? 'yearly_5499' : 'monthly_499',
          activatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }, { merge: true });

      await subRef.set({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPaymentId: razorpay_payment_id,
        status: 'active',
      }, { merge: true });

      return { ok: true };
    } catch (err) {
      console.error('subsVerify error:', err?.message || err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', err?.message || 'Unknown server error');
    }
  }
);

// Cancel subscription (optional)
exports.subsCancel = onCall(
  { region: 'asia-south1', secrets: [RZP_KEY_ID, RZP_KEY_SECRET], timeoutSeconds: 30, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
      const { subscriptionId, cancelAtCycleEnd } = req.data || {};
      if (!subscriptionId) throw new HttpsError('invalid-argument', 'subscriptionId required');

      const keyId = RZP_KEY_ID.value();
      const keySecret = RZP_KEY_SECRET.value();

      const rzp = rzpClient(keyId, keySecret);
      const res = await rzp.subscriptions.cancel(subscriptionId, !!cancelAtCycleEnd);

      await admin.firestore().collection('users').doc(req.auth.uid)
        .collection('subscriptions').doc(subscriptionId)
        .set({
          canceledAt: admin.firestore.FieldValue.serverTimestamp(),
          status: res.status,
        }, { merge: true });

      return { ok: true, status: res.status };
    } catch (err) {
      console.error('subsCancel error:', err?.message || err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', err?.message || 'Unknown server error');
    }
  }
);

// Webhook (verify HMAC using your dashboard "Secret")
exports.razorpayWebhook = onRequest(
  { region: 'asia-south1', timeoutSeconds: 30, memory: '256MiB' },
  async (req, res) => {
    try {
      const secret = WEBHOOK_SECRET();
      if (!secret) return res.status(500).send('Webhook secret not set');

      const signature = req.get('X-Razorpay-Signature') || req.get('x-razorpay-signature');
      if (!signature) return res.status(400).send('Missing signature header');

      const expected = crypto.createHmac('sha256', secret)
        .update(req.rawBody) // Buffer
        .digest('hex');

      if (expected !== signature) return res.status(401).send('Invalid signature');

      const body = req.body || {};
      const event = body.event;

      const getSubId = () =>
        body?.payload?.subscription?.entity?.id ||
        body?.payload?.invoice?.entity?.subscription_id ||
        body?.payload?.payment?.entity?.subscription_id || null;

      const getUid = () =>
        body?.payload?.subscription?.entity?.notes?.uid ||
        body?.payload?.invoice?.entity?.notes?.uid ||
        body?.payload?.payment?.entity?.notes?.uid || null;

      const subId = getSubId();
      const uid = getUid();

      if (!subId || !uid) {
        console.warn('Webhook missing uid/subId', { event, subId, uid });
        return res.status(200).send('OK');
      }

      const userRef = admin.firestore().collection('users').doc(uid);
      const updates = {
        lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(),
        subscriptionId: subId,
      };

      if (event === 'subscription.activated' || event === 'subscription.charged' || event === 'invoice.paid') {
        await userRef.set({ subscription: { status: 'active', ...updates } }, { merge: true });
      } else if (event === 'subscription.halted' || event === 'subscription.cancelled') {
        await userRef.set({ subscription: { status: 'inactive', ...updates } }, { merge: true });
      }

      return res.status(200).send('OK');
    } catch (err) {
      console.error('Webhook error', err);
      return res.status(500).send('Error');
    }
  }
);

// Notes:
// - Client must call FirebaseFunctions.instanceFor(region: 'asia-south1').
// - Plans must be same MODE as keys (both Test or both Live).
