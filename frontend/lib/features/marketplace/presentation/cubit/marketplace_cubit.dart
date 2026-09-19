import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/usecases/get_products.dart';

class MarketplaceState {
  const MarketplaceState({this.products = const [], this.filters = const ProductFilters(), this.page = 0, this.totalPages = 0, this.isInitialLoading = false, this.isLoadingMore = false, this.isRefreshing = false, this.error, this.loadingMoreError, this.syncWarning});
  final List<Product> products;
  final ProductFilters filters;
  final int page;
  final int totalPages;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? error;
  final String? loadingMoreError;
  final String? syncWarning;

  MarketplaceState copyWith({List<Product>? products, ProductFilters? filters, int? page, int? totalPages, bool? isInitialLoading, bool? isLoadingMore, bool? isRefreshing, String? error, bool clearError = false, String? loadingMoreError, bool clearLoadingMoreError = false, String? syncWarning, bool clearSyncWarning = false}) => MarketplaceState(
        products: products ?? this.products,
        filters: filters ?? this.filters,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : error ?? this.error,
        loadingMoreError: clearLoadingMoreError ? null : loadingMoreError ?? this.loadingMoreError,
        syncWarning: clearSyncWarning ? null : syncWarning ?? this.syncWarning,
      );
}

class MarketplaceCubit extends Cubit<MarketplaceState> {
  MarketplaceCubit(this._getProducts) : super(const MarketplaceState());
  final GetProducts _getProducts;
  Timer? _searchTimer;
  int _generation = 0;
  bool _closed = false;

  Future<void> load() async => _loadPage(1, reset: true);

  void searchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      if (!_closed) _loadPage(1, reset: true, filters: state.filters.copyWith(search: value));
    });
  }

  Future<void> updateFilters(ProductFilters filters) async => _loadPage(1, reset: true, filters: filters);

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    await _loadPage(1, reset: true, refreshing: true);
  }

  Future<void> loadMore() async {
    if (state.isInitialLoading || state.isLoadingMore || state.page >= state.totalPages) return;
    await _loadPage(state.page + 1, reset: false);
  }

  Future<void> _loadPage(int page, {required bool reset, bool refreshing = false, ProductFilters? filters}) async {
    final requestId = ++_generation;
    final activeFilters = filters ?? state.filters;
    if (reset) {
      emit(state.copyWith(filters: activeFilters, isInitialLoading: !refreshing, isRefreshing: refreshing, isLoadingMore: false, clearError: true, clearLoadingMoreError: true));
    } else {
      emit(state.copyWith(isLoadingMore: true, clearLoadingMoreError: true));
    }
    try {
      final result = await _getProducts(activeFilters, page: page);
      if (_closed || requestId != _generation) return;
      final merged = reset ? result.items : _merge(state.products, result.items);
      emit(state.copyWith(products: merged, filters: activeFilters, page: result.page, totalPages: result.totalPages, isInitialLoading: false, isLoadingMore: false, isRefreshing: false, clearError: true, clearLoadingMoreError: true));
    } catch (error) {
      if (_closed || requestId != _generation) return;
      final message = _message(error);
      if (reset) {
        emit(state.copyWith(isInitialLoading: false, isRefreshing: false, error: message));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreError: message));
      }
    }
  }

  List<Product> _merge(List<Product> current, List<Product> incoming) {
    final byId = {for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  String _message(Object error) {
    final failure = ErrorMapper.from(error);
    return failure.message;
  }

  @override
  Future<void> close() {
    _closed = true;
    _searchTimer?.cancel();
    return super.close();
  }
}
