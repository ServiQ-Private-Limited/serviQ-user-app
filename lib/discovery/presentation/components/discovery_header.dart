import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_assets.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';

/// The back affordance at the start of a drill-down screen's header.
class DiscoveryBackButton extends StatelessWidget {
  const DiscoveryBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppBackButton(onTap: onTap);
}

/// A screen header: an optional back button, the title, an optional caption
/// under it, and an optional trailing widget such as a LIVE pill.
class DiscoveryHeader extends StatelessWidget {
  const DiscoveryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBack) ...[
            const DiscoveryBackButton(),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Padding(
              // Centres the title against the 42pt back button beside it.
              padding: const EdgeInsets.only(top: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DiscoveryText.appBarTitle,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: DiscoveryText.caption),
                  ],
                ],
              ),
            ),
          ),
          if (trailing != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: trailing),
        ],
      ),
    );
  }
}

/// Home's own header: the chosen area, which reopens the area picker, and the
/// chat and notification buttons with their unread counts.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.localityName,
    this.onChangeLocality,
    this.onChat,
    this.onNotifications,
    this.unreadChats = 0,
    this.unreadNotifications = 0,
  });

  final String localityName;
  final VoidCallback? onChangeLocality;
  final VoidCallback? onChat;
  final VoidCallback? onNotifications;
  final int unreadChats;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onChangeLocality,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      DiscoveryAssets.pinHeader,
                      width: 14,
                      height: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        localityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DiscoveryText.rowTitle.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      DiscoveryAssets.caretDown,
                      width: 9.7,
                      height: 5.7,
                    ),
                  ],
                ),
              ),
            ),
            _HeaderAction(
              asset: DiscoveryAssets.chat,
              badgeCount: unreadChats,
              onTap: onChat,
            ),
            const SizedBox(width: 10),
            _HeaderAction(
              asset: DiscoveryAssets.bell,
              badgeCount: unreadNotifications,
              onTap: onNotifications,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.asset,
    required this.badgeCount,
    this.onTap,
  });

  final String asset;
  final int badgeCount;
  final VoidCallback? onTap;

  /// Stops at 99: past that the exact number is no longer information, and
  /// the badge would be wider than the icon it sits on.
  String get _badgeLabel => badgeCount > 99 ? '99+' : '$badgeCount';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 3,
              child: SvgPicture.asset(asset, width: 34, height: 34),
            ),
            if (badgeCount > 0)
              Positioned(
                right: 3,
                top: 0,
                child: Container(
                  // A disc at one or two digits, as the design draws it, and
                  // a stadium past that — a hundred unread is real, and a
                  // fixed 16pt circle would have spilled the number over its
                  // own edge rather than telling the seeker anything.
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColor.authError,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _badgeLabel,
                    style: const TextStyle(
                      fontFamily: DiscoveryText.family,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColor.white,
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
