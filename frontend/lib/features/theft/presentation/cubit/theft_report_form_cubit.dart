import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../../motorcycles/domain/entities/motorcycle.dart';
import '../../../motorcycles/domain/usecases/get_motorcycles.dart';
import '../../domain/entities/theft_report.dart';
import '../../domain/usecases/theft_report_usecases.dart';

class TheftReportFormState {
  const TheftReportFormState({this.motorcycles = const [], this.loadingMotorcycles = false, this.submitting = false, this.error, this.success = false});
  final List<Motorcycle> motorcycles;
  final bool loadingMotorcycles;
  final bool submitting;
  final String? error;
  final bool success;

  TheftReportFormState copyWith({List<Motorcycle>? motorcycles, bool? loadingMotorcycles, bool? submitting, String? error, bool clearError = false, bool? success}) => TheftReportFormState(
        motorcycles: motorcycles ?? this.motorcycles,
        loadingMotorcycles: loadingMotorcycles ?? this.loadingMotorcycles,
        submitting: submitting ?? this.submitting,
        error: clearError ? null : error ?? this.error,
        success: success ?? this.success,
      );
}

class TheftReportFormCubit extends Cubit<TheftReportFormState> {
  TheftReportFormCubit(this._getMotorcycles, this._createReport) : super(const TheftReportFormState());
  final GetMotorcycles _getMotorcycles;
  final CreateTheftReport _createReport;
  bool _submitting = false;

  Future<void> loadMotorcycles() async {
    emit(state.copyWith(loadingMotorcycles: true, clearError: true));
    try {
      emit(state.copyWith(motorcycles: await _getMotorcycles(), loadingMotorcycles: false));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(loadingMotorcycles: false, error: ErrorMapper.from(error).message));
    }
  }

  Future<bool> submit(CreateTheftReportInput input) async {
    if (_submitting) return false;
    _submitting = true;
    emit(state.copyWith(submitting: true, clearError: true, success: false));
    try {
      await _createReport(input);
      if (!isClosed) emit(state.copyWith(submitting: false, success: true));
      return true;
    } catch (error) {
      if (!isClosed) emit(state.copyWith(submitting: false, error: ErrorMapper.from(error).message));
      return false;
    } finally {
      _submitting = false;
    }
  }
}