part of 'search_bloc.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();
}

/// Open the screen on an area, possibly carrying a query over from the one
/// the seeker came from.
final class SearchOpened extends SearchEvent {
  final String localityName;
  final String query;

  const SearchOpened({required this.localityName, this.query = ''});

  @override
  List<Object> get props => [localityName, query];
}

final class SearchQueryChanged extends SearchEvent {
  final String query;

  const SearchQueryChanged(this.query);

  @override
  List<Object> get props => [query];
}

/// A trade chip, or null for "All".
final class SearchTradeSelected extends SearchEvent {
  final String? trade;

  const SearchTradeSelected(this.trade);

  @override
  List<Object?> get props => [trade];
}

/// Steps the rating chip on to the next floor.
final class SearchRatingCycled extends SearchEvent {
  const SearchRatingCycled();

  @override
  List<Object> get props => [];
}

/// The trade and the rating floor together, as the filter sheet returns them.
final class SearchFiltersApplied extends SearchEvent {
  final String? trade;
  final double? minRating;

  const SearchFiltersApplied({this.trade, this.minRating});

  @override
  List<Object?> get props => [trade, minRating];
}
