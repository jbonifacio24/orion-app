import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/workshop.dart';
import '../../domain/entities/workshop_filters.dart';
import '../../domain/usecases/delete_workshop.dart';
import '../../domain/usecases/get_workshops.dart';

class WorkshopsState {
  const WorkshopsState({this.items = const [], this.filters = const WorkshopFilters(), this.page = 0, this.totalPages = 0, this.totalCount = 0, this.isInitialLoading = false, this.isLoadingMore = false, this.isRefreshing = false, this.deletingId, this.failure, this.loadingMoreFailure});

  final List<Workshop> items;
  final WorkshopFilters filters;
  final int page;
  final int totalPages;
  final int totalCount;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final String? deletingId;
  final String? failure;
  final String? loadingMoreFailure;

  WorkshopsState copyWith({List<Workshop>? items, WorkshopFilters? filters, int? page, int? totalPages, int? totalCount, bool? isInitialLoading, bool? isLoadingMore, bool? isRefreshing, String? deletingId, bool clearDeletingId = false, String? failure, bool clearFailure = false, String? loadingMoreFailure, bool clearLoadingMoreFailure = false}) => WorkshopsState(
        items: items ?? this.items,
        filters: filters ?? this.filters,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        totalCount: totalCount ?? this.totalCount,
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        deletingId: clearDeletingId ? null : deletingId ?? this.deletingId,
        failure: clearFailure ? null : failure ?? this.failure,
        loadingMoreFailure: clearLoadingMoreFailure ? null : loadingMoreFailure ?? this.loadingMoreFailure,
      );
}

class WorkshopsCubit extends Cubit<WorkshopsState> {
  WorkshopsCubit(this._getWorkshops, this._deleteWorkshop) : super(const WorkshopsState());

  final GetWorkshops _getWorkshops;
  final DeleteWorkshop _deleteWorkshop;
  Timer? _searchTimer;
  Timer? _cityTimer;
  int _generation = 0;

  Future<bool> delete(String id) async {
    if (state.deletingId != null) return false;
    emit(state.copyWith(deletingId: id, clearFailure: true));
    try {
      await _deleteWorkshop(id);
      emit(state.copyWith(items: state.items.where((workshop) => workshop.id != id).toList(growable: false), totalCount: state.totalCount > 0 ? state.totalCount - 1 : 0, clearDeletingId: true));
      return true;
    } catch (error) {
      emit(state.copyWith(deletingId: id, failure: ErrorMapper.from(error).message));
      emit(state.copyWith(clearDeletingId: true));
      return false;
    }
  }

  Future<void> load() => _loadPage(1, reset: true);

  void searchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) _loadPage(1, reset: true, filters: state.filters.copyWith(search: value));
    });
  }

  void cityChanged(String value) {
    _cityTimer?.cancel();
    _cityTimer = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) _loadPage(1, reset: true, filters: state.filters.copyWith(city: value));
    });
  }

  Future<void> refresh() async {
    if (state.isRefreshing) return;
    await _loadPage(1, reset: true, refreshing: true);
  }

  Future<void> retry() => _loadPage(1, reset: true, filters: state.filters);

  Future<void> retryLoadMore() {
    if (state.page >= state.totalPages) return Future.value();
    return _loadPage(state.page + 1, reset: false);
  }

  Future<void> loadMore() {
    if (state.isInitialLoading || state.isLoadingMore || state.isRefreshing || state.page >= state.totalPages) return Future.value();
    return _loadPage(state.page + 1, reset: false);
  }

  Future<void> _loadPage(int page, {required bool reset, bool refreshing = false, WorkshopFilters? filters}) async {
    final requestId = ++_generation;
    final activeFilters = filters ?? state.filters;
    if (reset) {
      emit(state.copyWith(filters: activeFilters, isInitialLoading: !refreshing, isRefreshing: refreshing, isLoadingMore: false, clearFailure: true, clearLoadingMoreFailure: true));
    } else {
      emit(state.copyWith(isLoadingMore: true, clearLoadingMoreFailure: true));
    }
    try {
      final result = await _getWorkshops(activeFilters, page: page);
      if (isClosed || requestId != _generation) return;
      final items = reset ? result.items : _merge(state.items, result.items);
      emit(state.copyWith(items: items, filters: activeFilters, page: result.page, totalPages: result.totalPages, totalCount: result.totalCount, isInitialLoading: false, isLoadingMore: false, isRefreshing: false, clearFailure: true, clearLoadingMoreFailure: true));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      final message = ErrorMapper.from(error).message;
      if (reset) {
        emit(state.copyWith(isInitialLoading: false, isRefreshing: false, failure: message));
      } else {
        emit(state.copyWith(isLoadingMore: false, loadingMoreFailure: message));
      }
    }
  }

  List<Workshop> _merge(List<Workshop> current, List<Workshop> incoming) {
    final byId = {for (final item in current) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    return byId.values.toList(growable: false);
  }

  @override
  Future<void> close() {
    _searchTimer?.cancel();
    _cityTimer?.cancel();
    return super.close();
  }
}