import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_svg/flutter_svg.dart';

import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/bloc/search_bloc.dart';
import 'package:local_markerplace/discovery/model/provider_summary.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_assets.dart';
import 'package:local_markerplace/discovery/presentation/components/filter_button.dart';
import 'package:local_markerplace/discovery/presentation/components/search_filter_sheet.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_search_field.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/components/provider_row.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';

/// 06 · Search — typing, filters and results, all on one screen.
///
/// The trade chips are built from the trades actually present in the current
/// locality, so the row never offers a filter that would return nothing.
class SearchPage extends StatelessWidget {
  const SearchPage({
    super.key,
    required this.localityName,
    this.initialQuery = '',
    this.onProviderTap,
    this.onTabSelected,
    this.onPost,
    this.repository = const DiscoveryRepository(),
  });

  final String localityName;
  final String initialQuery;
  final ValueChanged<ProviderSummary>? onProviderTap;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;
  final DiscoveryRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SearchBloc(discoveryRepository: repository)
        ..add(SearchOpened(localityName: localityName, query: initialQuery)),
      child: _SearchView(
        initialQuery: initialQuery,
        repository: repository,
        onProviderTap: onProviderTap,
        onTabSelected: onTabSelected,
        onPost: onPost,
      ),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView({
    required this.initialQuery,
    required this.repository,
    required this.onProviderTap,
    required this.onTabSelected,
    required this.onPost,
  });

  final String initialQuery;
  final DiscoveryRepository repository;
  final ValueChanged<ProviderSummary>? onProviderTap;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  /// The controller belongs to the field; what was typed belongs to the
  /// bloc, which is told on every change.
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Runs the same query against another area, on a screen of its own so
  /// the seeker can come back to this one.
  void _searchIn(String localityName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPage(
          localityName: localityName,
          initialQuery: _controller.text,
          repository: widget.repository,
          onProviderTap: widget.onProviderTap,
          onTabSelected: widget.onTabSelected,
          onPost: widget.onPost,
        ),
      ),
    );
  }

  void _query(String value) =>
      context.read<SearchBloc>().add(SearchQueryChanged(value));

  /// True while the sheet is up, so a second tap cannot stack another on it.
  bool _filterIsOpen = false;

  Future<void> _openFilters(BuildContext context, SearchState state) async {
    if (_filterIsOpen) return;
    _filterIsOpen = true;
    final bloc = context.read<SearchBloc>();
    final chosen = await SearchFilterSheet.show(
      context,
      trades: state.trades,
      ratings: SearchBloc.ratingSteps,
      localityName: state.localityName,
      trade: state.trade,
      minRating: state.minRating,
    );
    _filterIsOpen = false;
    // Dismissing changes nothing, which is why a null answer is not read as
    // "clear everything".
    if (chosen == null || !context.mounted) return;

    if (chosen.changeArea) {
      // Changing the area is the area picker's job, so this hands the screen
      // back rather than filtering in place.
      await Navigator.of(context).maybePop();
      return;
    }
    bloc.add(
      SearchFiltersApplied(trade: chosen.trade, minRating: chosen.minRating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchBloc>().state;
    final results = state.results;

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const AppBackButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: DiscoverySearchField(
                      controller: _controller,
                      onChanged: _query,
                      onClear: () {
                        _controller.clear();
                        _query('');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterButton(
                    isFiltered: state.isFiltered,
                    onTap: () => _openFilters(context, state),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColor.discoveryBorder,
            ),
            if (state.hasNoMatches)
              Expanded(
                child: _NothingHere(
                  query: state.query.trim(),
                  localityName: state.localityName,
                  repository: widget.repository,
                  onPost: widget.onPost,
                  onSearchElsewhere: _searchIn,
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Text(
                  [
                    '${results.length} '
                        '${results.length == 1 ? 'result' : 'results'} '
                        'in ${state.localityName}',
                    // Says which filters produced that count, since the
                    // chips that used to show them are gone.
                    ?state.trade,
                    if (state.minRating != null) state.ratingLabel,
                  ].join(' · '),
                  style: DiscoveryText.footnoteStrong,
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(left: 58),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColor.discoveryBorder,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final provider = results[index];
                    return ProviderRow(
                      provider: provider,
                      index: index,
                      showReviewCount: false,
                      subtitle:
                          '${provider.localityName} · '
                          '${provider.isOpen ? 'Open now' : 'Closed'}',
                      onTap: () => widget.onProviderTap?.call(provider),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        current: DiscoveryTab.explore,
        onSelect: (tab) => widget.onTabSelected?.call(tab),
        onPost: widget.onPost,
      ),
    );
  }
}

/// 09 · 05 — the search that found nothing.
///
/// A dead end is the one moment the app knows exactly what somebody wants and
/// cannot supply it, so it asks them to post it instead, and points at the
/// nearby areas that do have someone.
class _NothingHere extends StatelessWidget {
  const _NothingHere({
    required this.query,
    required this.localityName,
    required this.repository,
    required this.onPost,
    required this.onSearchElsewhere,
  });

  final String query;
  final String localityName;
  final DiscoveryRepository repository;
  final VoidCallback? onPost;
  final ValueChanged<String> onSearchElsewhere;

  /// "electrician" -> "electricians", so the headline reads as English.
  String get _plural =>
      query.endsWith('s') ? query.toLowerCase() : '${query.toLowerCase()}s';

  @override
  Widget build(BuildContext context) {
    final zone = repository.zoneOfLocality(localityName);
    final elsewhere = <(String, int)>[
      for (final locality in zone?.localities ?? const [])
        if (locality.name != localityName)
          (
            locality.name,
            repository.search(query, localityName: locality.name).length,
          ),
    ].where((entry) => entry.$2 > 0).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColor.discoveryTint,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  DiscoveryAssets.search,
                  width: 30,
                  height: 30,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'No $_plural in $localityName yet',
              textAlign: TextAlign.center,
              style: DiscoveryText.headline.copyWith(
                fontSize: 20,
                letterSpacing: -0.4,
                height: 26 / 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You are the first to look for this here. Post it and providers '
              'nearby will be notified.',
              textAlign: TextAlign.center,
              style: DiscoveryText.subtitle.copyWith(height: 19 / 13),
            ),
            const SizedBox(height: 28),
            _PostThisButton(onTap: onPost),
            if (elsewhere.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Search nearby localities',
                  style: DiscoveryText.outlinedAction.copyWith(fontSize: 14),
                ),
              ),
              const SizedBox(height: 26),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColor.discoveryBorder,
              ),
              const SizedBox(height: 18),
              Text(
                'ELSEWHERE IN ${(zone?.name ?? '').toUpperCase()}',
                style: DiscoveryText.fieldLabel,
              ),
              for (final (name, count) in elsewhere)
                _ElsewhereRow(
                  name: name,
                  label: '$count ${count == 1 ? query : _plural}',
                  onTap: () => onSearchElsewhere(name),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The gradient call to action that turns a dead end into a requirement.
class _PostThisButton extends StatelessWidget {
  const _PostThisButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.97,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              AppColor.discoveryGradientStart,
              AppColor.discoveryGradientEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColor.discoveryGradientEnd.withValues(alpha: 0.32),
              blurRadius: 11,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(DiscoveryAssets.plus, width: 16, height: 16),
            const SizedBox(width: 10),
            Text(
              'Post this requirement',
              style: DiscoveryText.onAccent(16, letterSpacing: -0.16),
            ),
          ],
        ),
      ),
    );
  }
}

/// One nearby area that does have somebody.
class _ElsewhereRow extends StatelessWidget {
  const _ElsewhereRow({
    required this.name,
    required this.label,
    required this.onTap,
  });

  final String name;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColor.discoveryBorder)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(name, style: DiscoveryText.rowTitle)),
            const SizedBox(width: 12),
            Text(label, style: DiscoveryText.footnoteStrong),
            const SizedBox(width: 12),
            SvgPicture.asset(
              DiscoveryAssets.chevronRight,
              width: 5,
              height: 11,
            ),
          ],
        ),
      ),
    );
  }
}
