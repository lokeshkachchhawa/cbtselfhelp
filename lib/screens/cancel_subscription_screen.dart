import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CancelSubscriptionScreen extends StatefulWidget {
  const CancelSubscriptionScreen({super.key});

  @override
  State<CancelSubscriptionScreen> createState() =>
      _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState extends State<CancelSubscriptionScreen> {
  bool _loading = false;
  String? _status;
  String? _plan;
  String? _subscriptionId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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
    });
  }

  Future<void> _cancel() async {
    if (_subscriptionId == null) {
      setState(() => _error = 'No active subscription found.');
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final fn = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('subsCancel');

      final res = await fn.call({
        'subscriptionId': _subscriptionId!,
        'cancelAtCycleEnd': true,
      });

      // Refresh subscription info
      await _load();

      if (!mounted) return;

      final status = (res.data["status"] ?? "").toString();

      final snack = (status == "cancel_scheduled")
          ? "Cancellation scheduled — You’ll have access until the current cycle ends."
          : "Subscription cancelled.";

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snack)));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teal = Colors.teal;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Cancel Subscription"),
        backgroundColor: teal,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _subscriptionId == null
              ? _noSubscriptionUI()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ STATUS BANNER
                    if ((_status ?? '') == "cancel_scheduled") ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Text(
                          'Your cancellation is scheduled. '
                          'You will retain access until your current billing cycle ends.',
                          style: TextStyle(color: Colors.black87, height: 1.25),
                        ),
                      ),
                    ],

                    Text(
                      "Your Subscription",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: teal.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _info("Plan", _plan ?? "--"),
                    _info("Status", _status ?? "--"),
                    _info("Subscription ID", _subscriptionId ?? "--"),

                    const SizedBox(height: 24),

                    Text(
                      "If you cancel, you’ll still have access until the end of your current billing cycle.",
                      style: TextStyle(color: Colors.grey.shade700),
                    ),

                    const SizedBox(height: 24),

                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),

                    const Spacer(),

                    // ✅ DISABLE BUTTON when cancellation already scheduled
                    ElevatedButton(
                      onPressed: (_status == "cancel_scheduled" || _loading)
                          ? null
                          : _cancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              (_status == "cancel_scheduled")
                                  ? "Cancellation Scheduled"
                                  : "Cancel Subscription",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// empty state UI
  Widget _noSubscriptionUI() {
    return Center(
      child: Text(
        "No active subscription found.",
        style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
