import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:regie_data/models/plan_limits.dart';
import 'package:regie_data/services/subscription_service.dart';

const _bg = Color(0xFF0A0F0A);
const _surface = Color(0xFF111811);
const _green = Color(0xFF22C55E);
const _greenDark = Color(0xFF16A34A);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _currentPlan = 'free';
  bool _isLoading = false;
  String? _processingPlan;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final plan = await SubscriptionService.getUserPlan(uid);
    if (mounted) setState(() => _currentPlan = plan);
  }

  Future<void> _subscribe(String plan) async {
    if (plan == _currentPlan) return;

    // Downgrade to free
    if (plan == 'free') {
      final confirm = await _confirmDowngrade();
      if (confirm != true) return;
      setState(() => _isLoading = true);
      await SubscriptionService.cancelSubscription(
          FirebaseAuth.instance.currentUser!.uid);
      if (mounted) {
        setState(() {
          _currentPlan = 'free';
          _isLoading = false;
        });
        _snack('Downgraded to free plan');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _processingPlan = plan;
    });
    final success = await SubscriptionService.subscribe(
      context: context,
      targetPlan: plan,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _processingPlan = null;
      });
      if (success) {
        setState(() => _currentPlan = plan);
        _snack('Upgraded to ${PlanLimits.planName(plan)}!');
      } else {
        _snack('Payment was not completed.', error: true);
      }
    }
  }

  Future<bool?> _confirmDowngrade() => showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: _surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Downgrade to Free',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ]),
                const SizedBox(height: 14),
                Text(
                  'You will lose access to paid features at the end of your current billing period. Your data will be retained.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.6),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.4)),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Downgrade',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ),
      );

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade800 : _greenDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(0.7)),
        title: const Text('Subscription',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
        ),
      ),
      body: SingleChildScrollView(
        padding:
            EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current plan badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded,
                        color: _green, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Plan',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12)),
                      Text(PlanLimits.planName(_currentPlan),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800))
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _green.withOpacity(0.3)),
                    ),
                    child: Text(PlanLimits.price(_currentPlan),
                        style: const TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),

            Text('Choose Your Plan',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('Upgrade or downgrade at any time.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 13)),
            const SizedBox(height: 20),

            // Plan cards - stacked on mobile row on wide
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _planCard('free')),
                  const SizedBox(width: 16),
                  Expanded(child: _planCard('pro')),
                  const SizedBox(width: 16),
                  Expanded(child: _planCard('business')),
                ],
              )
            else
              Column(
                children: [
                  _planCard('free'),
                  const SizedBox(height: 16),
                  _planCard('pro'),
                  const SizedBox(height: 16),
                  _planCard('business'),
                ],
              ),

            const SizedBox(height: 32),

            // FAQ / note
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                children: [
                  _faqRow(Icons.security_rounded, 'Secure payments',
                      'All payments are processed securely via Paystack.'),
                  const SizedBox(height: 12),
                  _faqRow(Icons.refresh_rounded, 'Cancel anytime',
                      'Downgrade back to free whenever you want.'),
                  const SizedBox(height: 12),
                  _faqRow(Icons.storage_rounded, 'Your data is safe',
                      'Downgrading does not delete yoour records.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _planCard(String plan) {
    final isCurrent = plan == _currentPlan;
    final isHighlighted = plan == 'pro';
    final isProcessing = _processingPlan == plan && _isLoading;
    final features = PlanLimits.features(plan);

    Color accentColor = _green;
    if (plan == 'business') accentColor = const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isHighlighted ? _green.withOpacity(0.06) : _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent
              ? _green.withOpacity(0.5)
              : isHighlighted
                  ? _green.withOpacity(0.3)
                  : Colors.white.withOpacity(0.07),
          width: isCurrent || isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(PlanLimits.planName(plan),
                  style: TextStyle(
                      color: isCurrent || isHighlighted
                          ? accentColor
                          : Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const SizedBox(width: 8),
              if (isHighlighted && !isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Popular',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
              if (isCurrent) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.3)),
                  ),
                  child: const Text('Current',
                      style: TextStyle(
                          color: _green,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                )
              ]
            ],
          ),
          const SizedBox(height: 12),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(PlanLimits.price(plan),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1)),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  plan == 'free' ? '/ forever' : '/ month',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withOpacity(0.07), height: 1),
          const SizedBox(height: 14),

          // Features
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 15,
                        color: isCurrent || isHighlighted
                            ? accentColor
                            : Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(f,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                              fontSize: 13)),
                    )
                  ],
                ),
              )),
          const SizedBox(height: 18),

          // CTA
          GestureDetector(
            onTap: (_isLoading || isCurrent) ? null : () => _subscribe(plan),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                gradient: isCurrent || _isLoading
                    ? null
                    : isHighlighted
                        ? const LinearGradient(colors: [_green, _greenDark])
                        : null,
                color: isCurrent
                    ? Colors.white.withOpacity(0.04)
                    : _isLoading && _processingPlan == plan
                        ? _green.withOpacity(0.3)
                        : isHighlighted
                            ? null
                            : Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: isCurrent
                    ? Border.all(color: Colors.white.withOpacity(0.08))
                    : isHighlighted
                        ? null
                        : Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Center(
                child: isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        isCurrent
                            ? 'Current Plan'
                            : plan == 'free'
                                ? 'Downgrade to Free'
                                : 'Upgrade to ${PlanLimits.planName(plan)}',
                        style: TextStyle(
                          color: isCurrent
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _faqRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.3), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Text(desc,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}
