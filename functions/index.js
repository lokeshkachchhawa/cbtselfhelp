// functions/index.js

// ---------- Core & Admin ----------
const { setGlobalOptions } = require('firebase-functions/v2');
const { onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { onSchedule } = require('firebase-functions/v2/scheduler');

const admin = require('firebase-admin');
// ---------- Gemini (Google Generative AI) ----------
const { GoogleGenerativeAI } = require('@google/generative-ai');

// If you like, you can also import defineString; using env fallback is fine too.

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
// Optional: keep model in env, default to a quick model you listed:
const GEMINI_MODEL = () => process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';


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
      const total_count = (kind === 'yearly') ? 10 : 120; // long running

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
// Improved subsVerify - paste into your functions file (replace existing)
// Deploy-ready improved subsVerify
exports.subsVerify = onCall(
  { region: 'asia-south1', secrets: [RZP_KEY_SECRET, RZP_KEY_ID], timeoutSeconds: 60, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');

      const { razorpay_payment_id, razorpay_subscription_id, razorpay_signature } = req.data || {};
      if (!razorpay_payment_id || !razorpay_subscription_id || !razorpay_signature) {
        throw new HttpsError('invalid-argument', 'Missing verification fields');
      }

      // Get secrets
      const keySecret = RZP_KEY_SECRET.value();
      const keyId = RZP_KEY_ID.value();

      // 1) Verify signature (client -> server)
      const expected = crypto.createHmac('sha256', keySecret)
        .update(`${razorpay_payment_id}|${razorpay_subscription_id}`)
        .digest('hex');

      if (expected !== razorpay_signature) {
        console.warn('subsVerify: signature mismatch', { razorpay_payment_id, razorpay_subscription_id });
        throw new HttpsError('permission-denied', 'Invalid signature');
      }

      // 2) Init Razorpay client and fetch payment entity to ensure capture
      const rzp = rzpClient(keyId, keySecret);
      const payment = await rzp.payments.fetch(razorpay_payment_id).catch((e) => {
        console.error('subsVerify: payments.fetch failed', e?.message || e);
        return null;
      });

      if (!payment) {
        throw new HttpsError('not-found', 'Payment not found');
      }

      // Normalize status
      const paymentStatus = (payment.status || '').toString().toLowerCase();
      console.log('subsVerify: payment fetched', { paymentId: razorpay_payment_id, paymentStatus, payment });

      // 2a) Ensure payment is captured (or captured-equivalent)
      if (paymentStatus !== 'captured') {
        // If you support 'authorized' then change logic accordingly, but typical flow expects 'captured'
        console.warn('subsVerify: payment not captured yet', { paymentId: razorpay_payment_id, status: paymentStatus });
        throw new HttpsError('failed-precondition', `Payment not captured (status=${paymentStatus})`);
      }

      // 2b) Optional: ensure payment is linked to same subscription on Razorpay side (if field present)
      const linkedSubId = payment.subscription_id || payment?.entity?.subscription_id || null;
      if (linkedSubId && linkedSubId !== razorpay_subscription_id) {
        console.warn('subsVerify: payment.subscription_id mismatch', { paymentId: razorpay_payment_id, linkedSubId, razorpay_subscription_id });
        // we don't auto-fail here, but log and surface to ops
      }

      // 3) Persist activation in Firestore (same pattern as your earlier implementation)
      const uid = req.auth.uid;
      const userRef = admin.firestore().collection('users').doc(uid);
      const subRef = userRef.collection('subscriptions').doc(razorpay_subscription_id);

      // Try to read stored sub doc to derive 'kind' if available
      let kind = 'monthly';
      try {
        const snap = await subRef.get();
        if (snap && snap.exists) kind = (snap.data().kind || kind);
      } catch (e) {
        console.warn('subsVerify: could not read sub doc', e?.message || e);
      }

      // Update top-level user subscription snapshot
      await userRef.set({
        subscription: {
          status: 'active',
          subscriptionId: razorpay_subscription_id,
          plan: (kind === 'yearly') ? 'yearly_5499' : 'monthly_499',
          activatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastPaymentId: razorpay_payment_id,
        }
      }, { merge: true });

      // Update sub-collection doc as verified
      await subRef.set({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastPaymentId: razorpay_payment_id,
        status: 'active',
        rawPayment: {
          id: razorpay_payment_id,
          status: paymentStatus,
        }
      }, { merge: true });

      console.log('subsVerify: subscription activated', { uid, razorpay_subscription_id, paymentId: razorpay_payment_id });
      return { ok: true, paymentStatus };

    } catch (err) {
      console.error('subsVerify error:', err?.message || err);

      // If it's already an HttpsError, rethrow so client gets proper code/message
      if (err instanceof HttpsError) throw err;

      // Generic fallback
      throw new HttpsError('internal', err?.message || 'Unknown server error during subscription verification');
    }
  }
);



// Cancel subscription (optional)
// Cancel subscription (updates both sub-collection AND top-level users/{uid}.subscription)
exports.subsCancel = onCall(
  { region: 'asia-south1', secrets: [RZP_KEY_ID, RZP_KEY_SECRET], timeoutSeconds: 30, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');
      const { subscriptionId, cancelAtCycleEnd = true } = req.data || {};
      if (!subscriptionId) throw new HttpsError('invalid-argument', 'subscriptionId required');

      const uid = req.auth.uid;
      const keyId = RZP_KEY_ID.value();
      const keySecret = RZP_KEY_SECRET.value();
      const rzp = rzpClient(keyId, keySecret);

      // Cancel at Razorpay
      // When cancelAtCycleEnd=true, Razorpay schedules cancellation for the end of the current cycle.
      const res = await rzp.subscriptions.cancel(subscriptionId, !!cancelAtCycleEnd);

      // Fetch the latest subscription entity to pick dates like current_end
      const sub = await rzp.subscriptions.fetch(subscriptionId).catch(() => null);

      // Timestamps (secs) -> Firestore Timestamp later via JS Date
      const currentEndSec = sub?.current_end || res?.current_end || null;
      const currentEndDate = currentEndSec ? new Date(currentEndSec * 1000) : null;

      // Decide a user-friendly status to show in app immediately
      // Razorpay may keep status as 'active' until cycle end if scheduled.
      const derivedStatus = cancelAtCycleEnd
        ? 'cancel_scheduled' // custom app label
        : (res?.status || 'inactive');

      const userRef = admin.firestore().collection('users').doc(uid);

      // Update sub-collection doc (history)
      await userRef.collection('subscriptions').doc(subscriptionId).set({
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
        status: res?.status || derivedStatus,
        cancelAtCycleEnd: !!cancelAtCycleEnd,
        currentEndAt: currentEndDate ? admin.firestore.Timestamp.fromDate(currentEndDate) : null,
        raw: {
          status: res?.status || null,
          has_scheduled_changes: sub?.has_scheduled_changes ?? null,
        },
      }, { merge: true });

      // Update top-level snapshot used by UI
      const topLevel = {
        status: derivedStatus,               // 'cancel_scheduled' or 'inactive'
        subscriptionId,
        cancelAtCycleEnd: !!cancelAtCycleEnd,
        canceledAt: admin.firestore.FieldValue.serverTimestamp(),
        nextRenewalEndsAt: currentEndDate ? admin.firestore.Timestamp.fromDate(currentEndDate) : null,
        lastWebhookAt: admin.firestore.FieldValue.serverTimestamp(), // optional heartbeat
      };
      await userRef.set({ subscription: topLevel }, { merge: true });

      return {
        ok: true,
        status: derivedStatus,
        nextRenewalEndsAt: currentEndSec || null,
        rawStatus: res?.status || null,
      };
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


// Generate with Gemini (callable)
// req.data: { prompt: string, system?: string, temperature?: number, maxOutputTokens?: number, mimeType?: 'text'|'json' }
exports.geminiGenerate = onCall(
  { region: 'asia-south1', secrets: [GEMINI_API_KEY], timeoutSeconds: 30, memory: '256MiB' },
  async (req) => {
    try {
      if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in required');

      const {
        prompt = '',
        system = '',
        temperature = 0.7,
        maxOutputTokens = 1024,
        mimeType = 'text',
      } = req.data || {};

      if (!prompt || typeof prompt !== 'string') {
        throw new HttpsError('invalid-argument', 'Provide a non-empty "prompt" string');
      }

      const apiKey = GEMINI_API_KEY.value();
      const modelName = GEMINI_MODEL();

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({
        model: modelName,
        // System instruction is optional; you can omit if not needed
        ...(system ? { systemInstruction: system } : {}),
      });

      // You can pass contents or simple text. Using the structured format:
      const generationConfig = {
        temperature,
        maxOutputTokens,
        // If you expect JSON, hint with response_mime_type
        ...(mimeType === 'json' ? { responseMimeType: 'application/json' } : {}),
      };

      const result = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }]}],
        generationConfig,
      });

      const response = result?.response;
      if (!response) throw new HttpsError('internal', 'No response from model');

      // Prefer .text(), but if mimeType=json you might want raw candidates
      const text = response.text();
      return {
        ok: true,
        model: modelName,
        mimeType,
        text,                  // main text output
        // raw: response,      // avoid returning the whole raw object (can be huge); uncomment only for debugging
      };
    } catch (err) {
      console.error('geminiGenerate error:', err?.message || err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError('internal', err?.message || 'Unknown server error');
    }
  }
);


// ---------- Daily CBT Tip Scheduler (40-day loop) ----------
exports.sendDailyCbtTip = onSchedule(
  {
    schedule: '0 9 * * *', // रोज़ सुबह 9 बजे
    timeZone: 'Asia/Kolkata',
    region: 'asia-south1',
    retry: true,
  },
  async () => {
    try {
      const TOTAL_DAYS = 40;

      // 🔹 Reference doc to track current day
      const stateRef = admin
        .firestore()
        .collection('system')
        .doc('cbt_tip_state');

      // 🔹 Transaction to safely increment day
      const currentDay = await admin.firestore().runTransaction(async (tx) => {
        const snap = await tx.get(stateRef);

        let day = 1;
        if (snap.exists) {
          day = snap.data().day || 1;
          day = day >= TOTAL_DAYS ? 1 : day + 1; // loop back to 1
        }

        tx.set(
          stateRef,
          {
            day,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        return day;
      });

      // 🔹 Fetch today’s CBT tip
      const tipSnap = await admin
        .firestore()
        .collection('cbt_daily_tips')
        .doc(currentDay.toString())
        .get();

      if (!tipSnap.exists) {
        console.warn('CBT tip missing for day', currentDay);
        return;
      }

      const tip = tipSnap.data();

      // 🔹 Send notification to ALL users
      await admin.messaging().send({
        topic: 'all_users',
        notification: {
          title: tip.title,
          body: tip.message,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'chat_channel', // 👈 MATCH APP
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });
      

      console.log(`✅ CBT tip sent | Day ${currentDay}`);
    } catch (err) {
      console.error('❌ Daily CBT scheduler error', err);
    }
  }
);
