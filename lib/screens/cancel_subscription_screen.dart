import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ================= THEME =================
const Color teal1 = Color(0xFF016C6C);
const Color teal2 = Color(0xFF79C2BF);
const Color teal3 = Color(0xFF008F89);
const Color teal4 = Color(0xFF007A78);
const Color teal5 = Color(0xFF005E5C);

const Color surfaceDark = Color(0xFF0F1F1E);
const Color cardDark = Color(0xFF142726);

class CancelSubscriptionScreen extends StatefulWidget {
  const CancelSubscriptionScreen({super.key});

  @override
  State<CancelSubscriptionScreen> createState() =>
      _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState extends State<CancelSubscriptionScreen> {
  bool _loading = false;
  bool? _cancelAtCycleEnd;
  DateTime? _nextRenewalEndsAt;

  String? _status;
  String? _plan;
  String? _subscriptionId;
  String? _error;

  String? _cancelReason;
  final TextEditingController _feedbackCtrl = TextEditingController();
  String getPrettyStatus(Map sub) {
    final bool cancelAtCycleEnd = sub['cancelAtCycleEnd'] == true;
    final DateTime? end = sub['nextRenewalEndsAt']?.toDate();

    if (end == null) return "Unknown";

    final stillActive = DateTime.now().isBefore(end);

    if (cancelAtCycleEnd && stillActive) return "Cancels on ${_format(end)}";
    if (stillActive) return "Active";
    return "Ended";
  }

  String _format(DateTime d) {
    return "${d.day} ${_month(d.month)} ${d.year}";
  }

  String _month(int m) {
    const mths = [
      "",
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return mths[m];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  // ================= LOAD SUB =================

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final sub = snap.data()?['subscription'];

    setState(() {
      _status = sub?['status'];
      _plan = sub?['plan'];
      _subscriptionId = sub?['subscriptionId'];
      _cancelAtCycleEnd = sub?['cancelAtCycleEnd'] == true;
      _nextRenewalEndsAt = sub?['nextRenewalEndsAt']?.toDate();
    });
  }

  // ================= ERRORS =================

  String _friendlyError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'permission-denied':
          return 'You are not allowed to perform this action.';
        case 'unauthenticated':
          return 'Session expired. Please login again.';
        case 'invalid-argument':
          return 'Invalid request. Please try again.';
        default:
          return 'Unable to cancel subscription right now.';
      }
    }
    return 'Something went wrong. Please try again.';
  }

  void _showError(String msg) {
    setState(() => _error = msg);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _error = null);
    });
  }

  // ================= CANCEL REASON SHEET =================

  Future<bool> _askCancelReason() async {
    _cancelReason = null;
    _feedbackCtrl.clear();

    return await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (ctx, setModalState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const Text(
                          "Before you cancel",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Your feedback helps us improve 🙏",
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),

                        ...[
                          "Too expensive",
                          "Not using enough",
                          "App is confusing",
                          "Missing features",
                          "Personal reasons",
                          "Other",
                        ].map(
                          (r) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: _cancelReason == r
                                  ? teal3.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _cancelReason == r
                                    ? teal3
                                    : Colors.white12,
                              ),
                            ),
                            child: RadioListTile<String>(
                              value: r,
                              groupValue: _cancelReason,
                              onChanged: (v) =>
                                  setModalState(() => _cancelReason = v),
                              activeColor: teal2,
                              title: Text(
                                r,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _feedbackCtrl,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Optional feedback",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: surfaceDark,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.white12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _cancelReason == null
                              ? null
                              : () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Proceed to Cancel",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),

                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            "Keep Subscription",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ) ??
        false;
  }

  // ================= CANCEL =================

  Future<void> _cancel() async {
    if (_subscriptionId == null) {
      _showError("No active subscription found.");
      return;
    }

    if (_status == "cancel_scheduled" || _status == "cancelled") {
      _showError("Cancellation already scheduled.");
      return;
    }

    final proceed = await _askCancelReason();
    if (!proceed) return;

    try {
      setState(() => _loading = true);

      final fn = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('subsCancel');
      final user = FirebaseAuth.instance.currentUser!;
      final email = user.email;

      await FirebaseFirestore.instance
          .collection("subscription_cancellations")
          .add({
            "uid": user.uid,
            "email": email, // 👈 added
            "subscriptionId": _subscriptionId,
            "plan": _plan,
            "platform": "ios",
            "cancelReason": _cancelReason,
            "cancelFeedback": _feedbackCtrl.text.trim(),
            "createdAt": FieldValue.serverTimestamp(),
          });

      final res = await fn.call({
        'subscriptionId': _subscriptionId!,
        'cancelAtCycleEnd': true,
      });

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res.data["status"] == "cancel_scheduled"
                ? "Cancellation scheduled till cycle end."
                : "Subscription cancelled.",
          ),
          backgroundColor: teal4,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceDark,
      appBar: AppBar(
        title: const Text("Cancel Subscription"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _subscriptionId == null
            ? _noSubscriptionUI()
            : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),

                    _infoCard(),

                    const Spacer(),

                    ElevatedButton(
                      onPressed: _loading ? null : _cancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Cancel Subscription",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _softInfo(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }

  Widget _infoCard() {
    final bool cancelAtCycleEnd = _cancelAtCycleEnd == true;
    final DateTime? end = _nextRenewalEndsAt;

    final bool stillActive = end != null && DateTime.now().isBefore(end);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cancelAtCycleEnd ? Colors.orangeAccent : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Subscription",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 16),
          _row("Plan", _plan ?? "--"),

          if (cancelAtCycleEnd && stillActive) ...[
            _row("Status", "Cancels on ${_format(end)}"),
            const SizedBox(height: 10),
            _softInfo(
              "You will keep full premium access until ${_format(end)}. "
              "No further charges will be made.",
            ),
          ] else if (stillActive) ...[
            _row("Status", "Active"),
          ] else ...[
            _row("Status", "Ended"),
            const SizedBox(height: 10),
            _softInfo(
              "Your premium access has ended. Renew to unlock all features.",
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noSubscriptionUI() {
    return const Center(
      child: Text(
        "No active subscription found",
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
