import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:local_markerplace/components/art/art_palette.dart';
import 'package:local_markerplace/components/art/bezier_wash.dart';
import 'package:local_markerplace/components/motion/app_motion.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_assets.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/components/provider_avatar.dart';
import 'package:local_markerplace/discovery/presentation/components/trade_glyph.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/model/provider_display.dart';

/// The head of a provider's page: their avatar, name, what vouches for them,
/// and the two actions.
///
/// The backdrop is painted in the provider's own colour — the same one their
/// card carries in the "Near you" rail — so arriving here reads as opening
/// the card rather than as landing on a new, unrelated screen. The avatar
/// scales in and the rest of the head follows it, one line after the next.
///
/// The actions read differently for a signed-out visitor — the page is public
/// but connecting and messaging are not — which is the only difference
/// between the design's anonymous and signed-in frames.
class ProviderHero extends StatelessWidget {
  const ProviderHero({
    super.key,
    required this.profile,
    required this.isSignedIn,
    this.onConnect,
    this.onChat,
    this.onBack,
    this.onMore,
  });

  final ProviderDetail profile;
  final bool isSignedIn;
  final VoidCallback? onConnect;
  final VoidCallback? onChat;
  final VoidCallback? onBack;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = ArtPalette.forSeed(profile.name);
    // The trade the watermark is drawn from. The endpoint names it outright
    // in `categories`, so the glyph no longer has to be guessed at from
    // whichever service happened to be listed first.
    final trade = profile.categories.isEmpty
        ? profile.name
        : profile.categories.first.tradeName;

    return ClipRect(
      child: BezierWash(
        accent: palette.deep,
        colors: const [
          AppColor.discoveryHeroTop,
          AppColor.providerHeroMid,
          AppColor.white,
        ],
        child: Stack(
          children: [
            // The trade, drawn oversized and pale behind the head — the same
            // watermark the provider's card carries, at hero scale.
            Positioned(
              left: -30,
              top: 30,
              child: Opacity(
                opacity: 0.10,
                child: SvgPicture.asset(
                  TradeGlyph.forTrade(trade),
                  width: 150,
                  height: 150,
                  colorFilter: ColorFilter.mode(palette.deep, BlendMode.srcIn),
                ),
              ),
            ),
            Column(
              children: [
                _HeaderRow(onBack: onBack, onMore: onMore),
                const SizedBox(height: 8),
                _Avatar(profile: profile),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      profile.name,
                      textAlign: TextAlign.center,
                      style: DiscoveryText.providerName,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlideIn(index: 2, child: _TrustRow(profile: profile)),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      profile.heroLine,
                      textAlign: TextAlign.center,
                      style: DiscoveryText.caption,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Action(
                            label: isSignedIn
                                ? 'Connect'
                                : 'Sign in to connect',
                            isPrimary: true,
                            onTap: onConnect,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Action(
                            label: isSignedIn ? 'Chat' : 'Sign in to chat',
                            isPrimary: false,
                            onTap: onChat,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({this.onBack, this.onMore});

  final VoidCallback? onBack;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBackButton(onTap: onBack),
            const Spacer(),
            GestureDetector(
              onTap: onMore,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: SvgPicture.asset(
                  DiscoveryAssets.more,
                  width: 4,
                  height: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The provider's square, which scales up into place when the page opens.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final ProviderDetail profile;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1),
      duration: AppMotion.entrance,
      curve: AppMotion.overshoot,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: ProviderAvatar(
        initials: profile.initials,
        seed: profile.name,
        size: 88,
        isVerified: profile.verified,
        hasRing: true,
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.profile});

  final ProviderDetail profile;

  @override
  Widget build(BuildContext context) {
    final isVerified = profile.verified;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.only(left: 9, right: 10, top: 4, bottom: 4),
          decoration: BoxDecoration(
            color: isVerified
                ? AppColor.discoveryLiveTint
                : AppColor.discoveryPillMuted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isVerified ? 'VERIFIED' : 'PROVIDER',
            style: isVerified ? DiscoveryText.pill : DiscoveryText.pillMuted,
          ),
        ),
        // The endpoint reports no date a provider joined, so nothing is
        // said about one. What it does report is whether they are open, and
        // that is worth more to somebody deciding whether to call.
        if (profile.homeService) ...[
          const SizedBox(width: 8),
          Text('Comes to you', style: DiscoveryText.footnoteStrong),
        ],
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.isPrimary, this.onTap});

  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isPrimary ? null : AppColor.white,
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    AppColor.discoveryGradientStart,
                    AppColor.discoveryGradientEnd,
                  ],
                )
              : null,
          border: isPrimary
              ? null
              : Border.all(
                  color: AppColor.discoveryAccent.withValues(alpha: 0.35),
                  width: 1.6,
                ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColor.discoveryGradientEnd.withValues(
                      alpha: 0.30,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isPrimary
                ? DiscoveryText.actionOnAccent
                : DiscoveryText.actionOutlined,
          ),
        ),
      ),
    );
  }
}
