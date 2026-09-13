import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/discovery/model/provider_summary.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';

part 'search_event.dart';
part 'search_state.dart';

/// Searching one area: what was typed, what it is narrowed by, and who comes
/// back.
///
/// The trade chips are built from the trades actually present in the area,
/// so the row never offers a filter that would return nothing.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final DiscoveryRepository discoveryRepository;

  SearchBloc({required this.discoveryRepository})
    : super(const SearchState.initial()) {
    on<SearchOpened>(_onOpened);
    on<SearchQueryChanged>(_onQueryChanged);
    on<SearchTradeSelected>(_onTradeSelected);
    on<SearchRatingCycled>(_onRatingCycled);
    on<SearchFiltersApplied>(_onFiltersApplied);
  }

  /// The rating floors on offer, and the order the sheet lists them in.
  static const ratingSteps = <double?>[null, 4.0, 4.5];

  void _onOpened(SearchOpened event, Emitter<SearchState> emit) {
    emit(
      state.copyWith(
        localityName: event.localityName,
        query: event.query,
        trades: discoveryRepository.tradesIn(event.localityName),
        isLoading: false,
      ),
    );
    _search(emit);
  }

  void _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) {
    emit(state.copyWith(query: event.query));
    _search(emit);
  }

  void _onTradeSelected(SearchTradeSelected event, Emitter<SearchState> emit) {
    emit(state.copyWith(trade: event.trade, clearTradeWhenAll: true));
    _search(emit);
  }

  /// Both scopes at once, which is what the sheet hands back — a seeker who
  /// sets a trade and a rating together should see one new list, not two.
  void _onFiltersApplied(
    SearchFiltersApplied event,
    Emitter<SearchState> emit,
  ) {
    emit(
      state.copyWith(
        trade: event.trade,
        clearTradeWhenAll: true,
        minRating: event.minRating,
        clearRatingWhenAny: true,
      ),
    );
    _search(emit);
  }

  void _onRatingCycled(SearchRatingCycled event, Emitter<SearchState> emit) {
    final next =
        (ratingSteps.indexOf(state.minRating) + 1) % ratingSteps.length;
    emit(
      state.copyWith(minRating: ratingSteps[next], clearRatingWhenAny: true),
    );
    _search(emit);
  }

  void _search(Emitter<SearchState> emit) {
    emit(
      state.copyWith(
        results: discoveryRepository.search(
          state.query,
          trade: state.trade,
          minRating: state.minRating,
          localityName: state.localityName,
        ),
      ),
    );
  }
}
