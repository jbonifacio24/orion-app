import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/theft_report.dart';
import '../../domain/usecases/theft_report_usecases.dart';

class MyTheftReportsState {
  const MyTheftReportsState({this.reports = const [], this.page = 0, this.pageSize = 20, this.totalCount = 0, this.totalPages = 0, this.loading = false, this.loadingMore = false, this.updatingId, this.error, this.loadingMoreError});
  final List<TheftReport> reports;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool loading;
  final bool loadingMore;
  final String? updatingId;
  final String? error;
  final String? loadingMoreError;

  MyTheftReportsState copyWith({List<TheftReport>? reports, int? page, int? pageSize, int? totalCount, int? totalPages, bool? loading, bool? loadingMore, String? updatingId, bool clearUpdatingId = false, String? error, bool clearError = false, String? loadingMoreError, bool clearLoadingMoreError = false}) => MyTheftReportsState(
        reports: reports ?? this.reports,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        totalCount: totalCount ?? this.totalCount,
        totalPages: totalPages ?? this.totalPages,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        updatingId: clearUpdatingId ? null : updatingId ?? this.updatingId,
        error: clearError ? null : error ?? this.error,
        loadingMoreError: clearLoadingMoreError ? null : loadingMoreError ?? this.loadingMoreError,
      );
}

class MyTheftReportsCubit extends Cubit<MyTheftReportsState> {
  MyTheftReportsCubit(this._getMyReports, this._updateStatus) : super(const MyTheftReportsState());
  final GetMyTheftReports _getMyReports;
  final UpdateTheftReportStatus _updateStatus;
  bool _updating = false;
  int _generation = 0;

  Future<void> load() => _loadPage(1, reset: true);

  Future<void> loadMore() {
    if (state.loading || state.loadingMore || state.page >= state.totalPages) return Future.value();
    return _loadPage(state.page + 1, reset: false);
  }

  Future<void> retryLoadMore() => _loadPage(state.page + 1, reset: false);

  Future<void> _loadPage(int page, {required bool reset}) async {
    final requestId = ++_generation;
    if (reset) {
      emit(state.copyWith(loading: true, loadingMore: false, clearError: true, clearLoadingMoreError: true));
    } else {
      emit(state.copyWith(loadingMore: true, clearLoadingMoreError: true));
    }
    try {
      final result = await _getMyReports(page: page, pageSize: state.pageSize);
      if (isClosed || requestId != _generation) return;
      emit(state.copyWith(reports: reset ? result.items : _merge(state.reports, result.items), page: result.page, pageSize: result.pageSize, totalCount: result.totalCount, totalPages: result.totalPages, loading: false, loadingMore: false, clearError: true, clearLoadingMoreError: true));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      if (reset) {
        emit(state.copyWith(loading: false, error: ErrorMapper.from(error).message));
      } else {
        emit(state.copyWith(loadingMore: false, loadingMoreError: ErrorMapper.from(error).message));
      }
    }
  }

  Future<bool> updateStatus(String id, TheftReportStatus status) async {
    if (_updating || status.isActive) return false;
    _updating = true;
    emit(state.copyWith(updatingId: id, clearError: true));
    try {
      final updated = await _updateStatus(id, status);
      if (isClosed) return false;
      emit(state.copyWith(reports: [for (final report in state.reports) if (report.id == id) updated else report], clearUpdatingId: true));
      return true;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(clearUpdatingId: true, error: ErrorMapper.from(error).message));
      return false;
    } finally {
      _updating = false;
    }
  }

  List<TheftReport> _merge(List<TheftReport> current, List<TheftReport> incoming) {
    final byId = {for (final report in current) report.id: report};
    for (final report in incoming) {
      byId[report.id] = report;
    }
    return byId.values.toList(growable: false);
  }
}