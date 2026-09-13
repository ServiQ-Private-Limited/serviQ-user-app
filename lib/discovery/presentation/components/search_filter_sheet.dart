import 'package:flutter/material.dart';

import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';

/// What the search filter sheet came back with.
///
/// A class rather than a pair of nullables because "no trade" and "any
/// rating" are real answers, and returning null for the whole thing is how
/// the sheet says it was dismissed without choosing.
class SearchFilters {
  const SearchFilters({this.trade, this.minRating, this.changeArea = false});

  /// The trade to narrow to, or null for all of them.
  final String? trade;

  /// The rating floor, or null for any.
  final double? minRating;

  /// The seeker asked for a different area. Changing it is the area picker's
  /// job, so this hands the screen back rather than filtering in place — the
  /// same thing the locality chip used to do.
  final bool changeArea;

  bool get isEmpty => trade == null && minRating == null;
}

/// Search's filters, as a sheet.
///
/// The screen used to carry two rails of chips — every trade in the area,
/// then the scope ones. That is a lot of horizontal scrolling to see what is
/// even on offer, so the trades live here now and the header keeps a single
/// icon, the way the services catalogue does.
class SearchFilterSheet extends StatefulWidget {
  const SearchFilterSheet({
    super.key,
    required this.trades,
    required this.ratings,
    required this.localityName,
    this.trade,
    this.minRating,
  });

  /// The area being searched. Shown so the scope is never a mystery once the
  /// chips that used to name it are gone.
  final String localityName;

  /// The trades present in this area — never a filter that returns nothing.
  final List<String> trades;

  /// The rating floors on offer, null first for "Any rating".
  final List<double?> ratings;

  final String? trade;
  final double? minRating;

  static Future<SearchFilters?> show(
    BuildContext context, {
    required List<String> trades,
    required List<double?> ratings,
    required String localityName,
    String? trade,
    double? minRating,
  }) {
    return showModalBottomSheet<SearchFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      // An area can carry a dozen trades, and a sheet that cannot reach its
      // own last row is worse than no sheet at all.
      isScrollControlled: true,
      builder: (_) => SearchFilterSheet(
        trades: trades,
        ratings: ratings,
        localityName: localityName,
        trade: trade,
        minRating: minRating,
      ),
    );
  }

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  /// Held while the sheet is open so the seeker can set both before anything
  /// is applied — unlike the chips, which reran the search on every tap.
  late String? _trade = widget.trade;
  late double? _minRating = widget.minRating;

  static String _ratingLabel(double? rating) =>
      rating == null ? 'Any rating' : '${rating.toStringAsFixed(1)} and above';

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColor.discoveryBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Filters', style: DiscoveryText.sheetTitle),
                  ),
                  // Only offered once something is on, so it is never a
                  // button that does nothing.
                  if (_trade != null || _minRating != null)
                    GestureDetector(
                      onTap: () => setState(() {
                        _trade = null;
                        _minRating = null;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text('Clear all', style: DiscoveryText.link),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                children: [
                  const _Heading('TRADE'),
                  _Row(
                    label: 'All trades',
                    isSelected: _trade == null,
                    onTap: () => setState(() => _trade = null),
                  ),
                  for (final trade in widget.trades) ...[
                    const SizedBox(height: 10),
                    _Row(
                      label: trade,
                      isSelected: _trade == trade,
                      onTap: () => setState(() => _trade = trade),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const _Heading('AREA'),
                  _Row(
                    label: widget.localityName,
                    isSelected: false,
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColor.discoveryTextTertiary,
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(const SearchFilters(changeArea: true)),
                  ),
                  const SizedBox(height: 24),
                  const _Heading('RATING'),
                  for (final (index, rating) in widget.ratings.indexed) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _Row(
                      label: _ratingLabel(rating),
                      isSelected: _minRating == rating,
                      onTap: () => setState(() => _minRating = rating),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: _Apply(
                onTap: () => Navigator.of(
                  context,
                ).pop(SearchFilters(trade: _trade, minRating: _minRating)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "TRADE" / "RATING".
class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(label, style: DiscoveryText.fieldLabel),
  );
}

/// One choice, marked when it is the one in force.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Replaces the tick on a row that leads somewhere rather than choosing.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColor.discoveryTint
              : AppColor.providerNoteFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColor.discoveryAccent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DiscoveryText.rowTitle,
              ),
            ),
            if (trailing != null)
              trailing!
            else if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 20,
                color: AppColor.discoveryAccent,
              ),
          ],
        ),
      ),
    );
  }
}

/// Applies both choices at once, which is why the sheet holds them rather
/// than narrowing the list behind it on every tap.
class _Apply extends StatelessWidget {
  const _Apply({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              AppColor.discoveryGradientStart,
              AppColor.discoveryGradientEnd,
            ],
          ),
        ),
        child: Text(
          'Show results',
          style: DiscoveryText.onAccent(16, letterSpacing: -0.16),
        ),
      ),
    );
  }
}
