// lib/screens/paywall_screen.dart
import 'dart:async';

import 'package:cbt_drktv/widgets/help_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _razorpay = Razorpay();
  bool _busy = false;
  String? _err;

  // Fallback if SDK doesn't return subscription_id in success payload
  String? _lastSubscriptionId;

  // Track which plan was tapped to show inline spinner on that button.
  String? _pendingKind;

  // 🔔 Live gate: send home if status is active or cancel_scheduled
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _checkingGate = true;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});

    // Start a snapshot listener to bypass paywall when allowed
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
      _sub = _userStream!.listen(
        (snap) {
          final data = snap.data() ?? {};
          final sub = Map<String, dynamic>.from(data['subscription'] ?? {});
          final status = (sub['status'] ?? '').toString();
          final allowed = status == 'active' || status == 'cancel_scheduled';
          if (allowed && mounted) {
            // Avoid double navigations
            _sub?.cancel();
            _sub = null;
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            if (mounted && _checkingGate) setState(() => _checkingGate = false);
          }
        },
        onError: (_) {
          if (mounted && _checkingGate) setState(() => _checkingGate = false);
        },
      );
    } else {
      _checkingGate = false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _razorpay.clear();
    super.dispose();
  }

  Future<String> _userName(String uid) async {
    final s = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return (s.data()?['name'] ?? 'User').toString();
  }

  Future<void> _start({required String kind}) async {
    setState(() {
      _busy = true;
      _pendingKind = kind;
      _err = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final subsCreate = functions.httpsCallable('subsCreate');

      final res = await subsCreate.call({'kind': kind});
      final data = Map<String, dynamic>.from(res.data);
      final subscriptionId = data['subscriptionId'] as String;
      final keyId = data['keyId'] as String;
      _lastSubscriptionId = subscriptionId;

      final options = {
        'key': keyId,
        'subscription_id': subscriptionId,
        'name': 'CBT Self-Guided',
        'description': kind == 'yearly' ? '₹5499/year' : '₹499/month',
        'prefill': {
          'email': user.email ?? '',
          'name': await _userName(user.uid),
        },
        'theme': {'color': '#016C6C'},
      };

      _razorpay.open(options);
    } catch (e) {
      setState(() => _err = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_err ?? 'Something went wrong')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingKind = null;
        });
      }
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    try {
      final subscriptionId = (r.orderId?.isNotEmpty ?? false)
          ? r.orderId!
          : (_lastSubscriptionId ?? '');
      if (subscriptionId.isEmpty) throw Exception('Missing subscriptionId');

      final functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
      final subsVerify = functions.httpsCallable('subsVerify');

      await subsVerify.call({
        'razorpay_payment_id': r.paymentId,
        'razorpay_subscription_id': subscriptionId,
        'razorpay_signature': r.signature,
      });

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      setState(() => _err = 'Verification failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_err!)));
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse r) {
    setState(() => _err = 'Payment failed: ${r.message ?? r.code}');
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_err!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgTop = const Color(0xFFE6F4F3);
    final bgBottom = Colors.teal.shade50;

    // ⏳ First paint: wait for subscription gate once
    if (_checkingGate) {
      return Scaffold(
        backgroundColor: bgBottom,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.teal,
          title: const Text('Subscribe for Access'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      floatingActionButton: const WhatsAppButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      backgroundColor: bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: const Text('Subscribe for Access'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/signin',
                (route) => false,
              );
            }
          },
        ),
        actions: [
          IconButton(
            tooltip: "Help",
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () => showHelpSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [bgTop, bgBottom],
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Card
                        Card(
                          elevation: 0,
                          color: Colors.white.withOpacity(0.9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.lock_outline,
                                      color: Colors.teal,
                                      size: 22,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Choose your plan',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      color: Colors.teal.shade900,
                                    ),
                                    children: const [
                                      TextSpan(text: 'Full access to '),
                                      TextSpan(
                                        text:
                                            'CBT tools, worksheets, guided relaxations',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: ', and '),
                                      TextSpan(
                                        text: 'approved chats',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: ' — monitored by '),
                                      TextSpan(
                                        text: 'Dr. Kanhaiya’s team.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),

                        // --- add this right after the Header Card (before _PlanCard calls) ---
                        const SizedBox(height: 8),

                        // Plans
                        _PlanCard(
                          title: 'Monthly',
                          price: '₹499',
                          cadence: '/month',
                          bullets: const [
                            'All CBT tools & exercises',
                            'Doctor-reviewed guidance',
                            'Cancel anytime',
                          ],
                          ctaLabel: 'Choose Monthly',
                          busy: _busy && _pendingKind == 'monthly',
                          onPressed: _busy
                              ? null
                              : () => _start(kind: 'monthly'),
                        ),
                        const SizedBox(height: 12),
                        _PlanCard(
                          title: 'Yearly',
                          price: '₹5499',
                          cadence: '/year',
                          bullets: const [
                            'Everything in Monthly',
                            'Save vs ₹5988/yr',
                            'Priority support',
                          ],
                          ribbon: 'Best value',
                          highlight: true,
                          ctaLabel: 'Choose Yearly',
                          busy: _busy && _pendingKind == 'yearly',
                          onPressed: _busy
                              ? null
                              : () => _start(kind: 'yearly'),
                        ),
                        const SizedBox(height: 12),
                        ScreenshotCarousel(
                          imagePaths: [
                            'images/s1.png',
                            'images/s2.png',
                            'images/s3.png',
                            'images/s4.png',
                            'images/s5.png',
                            'images/s6.png',
                          ],
                          autoPlay:
                              true, // change to false if you don't want autoplay
                          height:
                              420, // tweak to fit your layout (on narrow screens it scales)
                        ),
                        const SizedBox(height: 12),
                        // FAQ section below plans
                        const FaqSection(),

                        const SizedBox(height: 12),
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            'By subscribing you agree to our Terms & Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.teal.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay (blocks taps and shows a subtle dialog)
            if (_busy)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.25),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.teal.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.8),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Setting up your secure checkout…',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                  color: Colors.teal,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Please don’t close the app.',
                                style: TextStyle(fontSize: 12.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String cadence; // '/month' or '/year'
  final List<String> bullets;
  final String ctaLabel;
  final String? ribbon;
  final bool highlight;
  final bool busy; // <-- new
  final VoidCallback? onPressed;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.bullets,
    required this.ctaLabel,
    this.ribbon,
    this.highlight = false,
    this.busy = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final base = highlight ? Colors.teal : Colors.teal.shade100;
    final border = highlight ? Colors.teal : Colors.teal.shade200;
    final titleColor = highlight ? Colors.teal : Colors.teal.shade800;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              if (highlight)
                BoxShadow(
                  color: Colors.teal.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading icon circle
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [base.withOpacity(0.25), base.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: border),
                  ),
                  child: Icon(
                    highlight ? Icons.star_rate_rounded : Icons.calendar_today,
                    color: titleColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + price row
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: base.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                                children: [
                                  const TextSpan(
                                    text: '', // price added below
                                  ),
                                  TextSpan(
                                    text: price,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' $cadence',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Bullets
                      ...bullets.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: Colors.teal.shade600,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // CTA
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: busy ? null : onPressed, // lock while busy
                          style: ElevatedButton.styleFrom(
                            backgroundColor: highlight
                                ? Colors.green
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: highlight ? 2 : 0,
                          ),
                          child: busy
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Please wait…',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  ctaLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Ribbon (Best value)
        if (ribbon != null)
          Positioned(
            top: -10,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.emoji_events, size: 14, color: Colors.black),
                  SizedBox(width: 6),
                  Text(
                    'Best value',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class FaqItem {
  final String question;
  final String answer;
  FaqItem(this.question, this.answer);
}

final List<FaqItem> faqs = [
  FaqItem(
    "What do I get in the subscription?",
    "You get full access to CBT tools, worksheets, guided relaxations, approved chat responses, and ongoing monitoring by Dr. Kanhaiya’s team.",
  ),
  FaqItem(
    "Can I chat with Dr. Kanhaiya?",
    "Yes — you can send messages anytime. Responses are reviewed and approved by Dr. Kanhaiya & his team.",
  ),
  FaqItem(
    "Is this subscription refundable?",
    "Subscription fees are non-refundable, but you may cancel anytime to stop future renewals.",
  ),
  FaqItem(
    "How do I cancel my subscription?",
    "You can cancel anytime from within the app. Access continues until the current billing cycle ends.",
  ),
  FaqItem(
    "What happens after I cancel?",
    "You can continue using your plan until the end of the billing cycle. After that, you’ll need to re-subscribe to continue.",
  ),
  FaqItem(
    "Is payment secure?",
    "Yes. All payments are securely processed using Razorpay.",
  ),
  FaqItem(
    "Can I switch between monthly & yearly plans?",
    "Yes — you can change plans anytime.",
  ),
  FaqItem(
    "Is my data safe?",
    "Absolutely. Your sensitive information is encrypted and never shared with third parties.",
  ),
  FaqItem(
    "Can I use this alongside therapy or medication?",
    "Yes. This app can complement therapy or medication. For emergencies, please contact a medical professional.",
  ),
];

class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Frequently Asked Questions",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 16),
          ...faqs.map(
            (f) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal.shade200),
                color: Colors.white,
              ),
              child: ExpansionTile(
                iconColor: Colors.teal,
                collapsedIconColor: Colors.teal,
                title: Text(
                  f.question,
                  style: TextStyle(
                    color: Colors.teal.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      f.answer,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScreenshotCarousel extends StatefulWidget {
  final List<String> imagePaths;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final double height;

  const ScreenshotCarousel({
    super.key,
    required this.imagePaths,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.height = 420,
  });

  @override
  State<ScreenshotCarousel> createState() => _ScreenshotCarouselState();
}

class _ScreenshotCarouselState extends State<ScreenshotCarousel> {
  late final PageController _pageController;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.72, initialPage: 0);

    if (widget.autoPlay && widget.imagePaths.length > 1) {
      _timer = Timer.periodic(widget.autoPlayInterval, (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.imagePaths.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen(BuildContext context, String path, int index) {
    showDialog(
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            child: Center(
              child: Hero(
                tag: 'screenshot_$index',
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 24.0,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        child: Image.asset(
                          path,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => Container(
                            width: 300,
                            height: 600,
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.imagePaths;
    final height = widget.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            'See inside the app',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.teal.shade800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) {
              final path = images[index];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 0;
                  try {
                    if (_pageController.position.haveDimensions) {
                      value = _pageController.page! - index;
                    } else {
                      value = (_pageController.initialPage - index).toDouble();
                    }
                  } catch (_) {
                    value = 0;
                  }
                  // clamp and invert
                  value = (1 - (value.abs() * 0.15)).clamp(0.85, 1.0);
                  final scale = Curves.easeOut.transform(value);
                  final angle = (_pageController.hasClients)
                      ? (_pageController.page ?? _pageController.initialPage) -
                            index
                      : 0.0;
                  final tilt = (angle * 0.02).clamp(-0.03, 0.03);

                  return Center(
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(0.0, (1 - scale) * 24)
                        ..scale(scale, scale)
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(tilt),
                      alignment: Alignment.center,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () => _openFullscreen(context, path, index),
                  child: Hero(
                    tag: 'screenshot_$index',
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 9 / 18,
                          child: Image.asset(
                            path,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (i) {
            final active = i == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: active ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? Colors.teal : Colors.teal.shade100,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  if (active)
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

class WhatsAppButton extends StatelessWidget {
  const WhatsAppButton({super.key});

  final String phone = "+917976171908";
  final String message =
      "Hello, I need help with my CBT Self-Guided subscription.";

  Future<void> _openWhatsApp() async {
    final url =
        "https://wa.me/917976171908?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp");
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _openWhatsApp,
      backgroundColor: Colors.green.shade600,
      child: Padding(
        padding: const EdgeInsets.all(6.0), // to avoid clipping
        child: Image.asset(
          'images/whatsapp.png',
          width: 28,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
