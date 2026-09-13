part of 'search_bloc.dart';

class SearchState extends Equatable {
  final String localityName;
  final String query;

  /// The trades present in this area — what the chips offer.
  final List<String> trades;

  /// Null means the "All" chip is on.
  final String? trade;

  /// The rating floor the scope chip applies. Null until one is set.
  final double? minRating;

  final List<ProviderSummary> results;
  final bool isLoading;

  const SearchState({
    required this.localityName,
    required this.query,
    required this.trades,
    required this.trade,
    required this.minRating,
    required this.results,
    required this.isLoading,
  });

  const SearchState.initial({
    this.localityName = '',
    this.query = '',
    this.trades = const [],
    this.trade,
    this.minRating,
    this.results = const [],
    this.isLoading = true,
  });

  SearchState copyWith({
    String? localityName,
    String? query,
    List<String>? trades,
    String? trade,

    /// Lets "All" clear the trade rather than keeping the last one.
    bool clearTradeWhenAll = false,
    double? minRating,

    /// Lets "Any rating" clear the floor.
    bool clearRatingWhenAny = false,
    List<ProviderSummary>? results,
    bool? isLoading,
  }) {
    return SearchState(
      localityName: localityName ?? this.localityName,
      query: query ?? this.query,
      trades: trades ?? this.trades,
      trade: trade ?? (clearTradeWhenAll ? null : this.trade),
      minRating: minRating ?? (clearRatingWhenAny ? null : this.minRating),
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Whether anything is narrowing the list. The icon fills on this, since
  /// there are no chips left to say so.
  bool get isFiltered => trade != null || minRating != null;

  /// Nothing matched something that was actually asked for — an empty query
  /// returning nothing is not a dead end, it is a screen waiting to be used.
  bool get hasNoMatches => results.isEmpty && query.trim().isNotEmpty;

  String get ratingLabel =>
      minRating == null ? 'Any rating' : '${minRating!.toStringAsFixed(1)}+';

  @override
  List<Object?> get props => [
    localityName,
    query,
    trades,
    trade,
    minRating,
    results,
    isLoading,
  ];
}
