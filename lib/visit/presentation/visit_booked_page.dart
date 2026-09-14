import 'package:flutter/material.dart';

import 'package:local_markerplace/components/art/bezier_wash.dart';
import 'package:local_markerplace/components/motion/app_motion.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/presentation/components/visit_bits.dart';

/// 13 · 06 — the visit is booked.
///
/// The one screen in the flow that is purely reassurance: it says what was
/// agreed, gives it a reference the seeker can quote, and offers the two
/// things they might want next.
class VisitBookedPage extends StatelessWidget {
  const VisitBookedPage({super.key, required this.visit});

  final Visit visit;

  void _notice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: DiscoveryText.heroSubtitle.copyWith(color: AppColor.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      body: BezierWash(
        accent: AppColor.discoveryLiveText,
        colors: const [
          AppColor.onboardingSuccessWashTop,
          AppColor.providerHeroMid,
          AppColor.white,
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                const Center(child: _BookedMark()),
                const SizedBox(height: 34),
                FadeSlideIn(
                  index: 1,
                  child: Text(
                    'Visit booked',
                    textAlign: TextAlign.center,
                    style: DiscoveryText.providerName,
                  ),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  index: 2,
                  child: Text(
                    '${visit.providerName} will come ${_whenPhrase()}',
                    textAlign: TextAlign.center,
                    style: DiscoveryText.heroSubtitle,
                  ),
                ),
                const SizedBox(height: 30),
                FadeSlideIn(index: 3, child: _Summary(visit: visit)),
                const SizedBox(height: 24),
                FadeSlideIn(
                  index: 4,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: VisitCta(
                          label: 'Track visit',
                          onTap: () => _notice(
                            context,
                            'Tracking a visit — coming '
                            'soon.',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SecondaryAction(
                          label: 'Chat',
                          onTap: () => _notice(context, 'Chat — coming soon.'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: PressableScale(
                    // The flow behind this screen was removed when the visit
                    // was booked, so this is a plain pop back to where the
                    // seeker started — and it is the only way off the screen
                    // besides the two actions above, which is why it is here
                    // rather than left to the system back gesture.
                    onTap: () => Navigator.of(
                      context,
                    ).popUntil((route) => route.isFirst),
                    pressedScale: 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        'Done',
                        style: DiscoveryText.footnoteStrong.copyWith(
                          color: AppColor.discoveryTextTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: PressableScale(
                    onTap: () => _notice(
                      context,
                      'Cancelling a visit — '
                      'coming soon.',
                    ),
                    pressedScale: 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text('Cancel visit', style: DiscoveryText.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "tomorrow" / "today" / "as soon as one accepts", or the time the
  /// provider named in an offer the seeker accepted.
  String _whenPhrase() {
    final agreed = visit.agreedWhen;
    if (agreed != null) return agreed.toLowerCase();
    final slot = visit.slot;
    if (slot == null) return 'as soon as one accepts';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      slot.date.year,
      slot.date.month,
      slot.date.day,
    ).difference(today).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'on ${slot.date.day}/${slot.date.month}';
  }
}

/// The check, sitting inside two rings that scale in behind it.
class _BookedMark extends StatelessWidget {
  const _BookedMark();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: AppMotion.entrance,
      curve: AppMotion.overshoot,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: 200,
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColor.discoveryLiveTint.withValues(alpha: 0.55),
        ),
        child: Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColor.authSuccessLight, AppColor.discoveryLiveText],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColor.discoveryLiveText.withValues(alpha: 0.32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 46,
            color: AppColor.white,
          ),
        ),
      ),
    );
  }
}

/// What was booked, with the reference to quote.
class _Summary extends StatelessWidget {
  const _Summary({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.discoveryBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColor.discoveryShadow.withValues(alpha: 0.05),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VISIT ${visit.reference ?? ''}'.trim(),
            style: DiscoveryText.tipsHeading,
          ),
          const SizedBox(height: 10),
          Text(visit.whenLabel, style: DiscoveryText.groupHeading),
          const SizedBox(height: 6),
          Text(
            visit.addressSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiscoveryText.meta,
          ),
          const VisitRule(top: 14, bottom: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${visit.serviceCount} '
                  '${visit.serviceCount == 1 ? 'service' : 'services'}',
                  style: DiscoveryText.caption,
                ),
              ),
              Text(rupees(visit.estimate), style: DiscoveryText.chip),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pay by ${visit.payment.receiptLabel}',
            style: DiscoveryText.smallPrint,
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColor.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColor.discoveryAccent.withValues(alpha: 0.35),
            width: 1.6,
          ),
        ),
        child: Text(label, style: DiscoveryText.actionOutlined),
      ),
    );
  }
}
