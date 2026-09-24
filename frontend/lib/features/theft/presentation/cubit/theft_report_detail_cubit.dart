import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/theft_report.dart';
import '../../domain/usecases/theft_report_usecases.dart';

sealed class TheftReportDetailState {
  const TheftReportDetailState();
}

class TheftReportDetailInitial extends TheftReportDetailState {
  const TheftReportDetailInitial();
}

class TheftReportDetailLoading extends TheftReportDetailState {
  const TheftReportDetailLoading();
}

class TheftReportDetailLoaded extends TheftReportDetailState {
  const TheftReportDetailLoaded(this.report);
  final TheftReport report;
}

class TheftReportDetailFailure extends TheftReportDetailState {
  const TheftReportDetailFailure(this.message);
  final String message;
}

class TheftReportDetailCubit extends Cubit<TheftReportDetailState> {
  TheftReportDetailCubit(this._getDetail) : super(const TheftReportDetailInitial());
  final GetTheftReportDetail _getDetail;
  String? _id;
  int _generation = 0;

  Future<void> load(String id) async {
    _id = id;
    final requestId = ++_generation;
    emit(const TheftReportDetailLoading());
    try {
      final report = await _getDetail(id);
      if (isClosed || requestId != _generation) return;
      emit(TheftReportDetailLoaded(report));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      emit(TheftReportDetailFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> retry() => _id == null ? Future.value() : load(_id!);
}