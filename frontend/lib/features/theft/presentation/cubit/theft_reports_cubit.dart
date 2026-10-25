import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/theft_report.dart';
import '../../domain/usecases/theft_report_usecases.dart';

class TheftReportsState {
  const TheftReportsState({this.reports = const [], this.page = 0, this.pageSize = 20, this.totalCount = 0, this.totalPages = 0, this.loading = false, this.loadingMore = false, this.deletingReportId, this.error, this.loadingMoreError});
  final List<TheftReport> reports;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool loading;
  final bool loadingMore;
  final String? deletingReportId;
  final String? error;
  final String? loadingMoreError;

  TheftReportsState copyWith({List<TheftReport>? reports, int? page, int? pageSize, int? totalCount, int? totalPages, bool? loading, bool? loadingMore, String? deletingReportId, bool clearDeletingReportId = false, String? error, bool clearError = false, String? loadingMoreError, bool clearLoadingMoreError = false}) => TheftReportsState(
        reports: reports ?? this.reports,
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
        totalCount: totalCount ?? this.totalCount,
        totalPages: totalPages ?? this.totalPages,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        deletingReportId: clearDeletingReportId ? null : deletingReportId ?? this.deletingReportId,
        error: clearError ? null : error ?? this.error,
        loadingMoreError: clearLoadingMoreError ? null : loadingMoreError ?? this.loadingMoreError,
      );
}

class TheftReportsCubit extends Cubit<TheftReportsState> {
  TheftReportsCubit(this._getActiveReports, this._deleteReport) : super(const TheftReportsState());
  final GetActiveTheftReports _getActiveReports;
  final DeleteTheftReport _deleteReport;
  int _generation = 0;

  Future<void> load() => _loadPage(1, reset: true);

  Future<void> loadMore() {
    if (state.loading || state.loadingMore || state.page >= state.totalPages) return Future.value();
    return _loadPage(state.page + 1, reset: false);
  }

  Future<void> retryLoadMore() => _loadPage(state.page + 1, reset: false);

  Future<bool> deleteReport(String id) async {
    if (state.deletingReportId != null) return false;
    emit(state.copyWith(deletingReportId: id, clearError: true));
    try {
      await _deleteReport(id);
      if (isClosed) return false;
      final remainingReports = state.reports.where((report) => report.id != id).toList(growable: false);
      final totalCount = state.totalCount > 0 ? state.totalCount - 1 : 0;
      emit(state.copyWith(
        reports: remainingReports,
        totalCount: totalCount,
        totalPages: totalCount == 0 ? 0 : (totalCount / state.pageSize).ceil(),
        clearDeletingReportId: true,
        clearError: true,
      ));
      if (remainingReports.isEmpty && state.page > 1) {
        await _loadPage(state.page - 1, reset: true);
      }
      return true;
    } catch (error) {
      if (isClosed) return false;
      emit(state.copyWith(clearDeletingReportId: true, error: ErrorMapper.from(error).message));
      return false;
    }
  }

  Future<void> _loadPage(int page, {required bool reset}) async {
    final requestId = ++_generation;
    if (reset) {
      emit(state.copyWith(loading: true, loadingMore: false, clearError: true, clearLoadingMoreError: true));
    } else {
      emit(state.copyWith(loadingMore: true, clearLoadingMoreError: true));
    }
    try {
      final result = await _getActiveReports(page: page, pageSize: state.pageSize);
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

  List<TheftReport> _merge(List<TheftReport> current, List<TheftReport> incoming) {
    final byId = {for (final report in current) report.id: report};
    for (final report in incoming) {
      byId[report.id] = report;
    }
    return byId.values.toList(growable: false);
  }
}