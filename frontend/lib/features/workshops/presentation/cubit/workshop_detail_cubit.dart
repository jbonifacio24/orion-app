import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/workshop_detail.dart';
import '../../domain/usecases/get_workshop_detail.dart';

sealed class WorkshopDetailState {
  const WorkshopDetailState();
}

final class WorkshopDetailInitial extends WorkshopDetailState {
  const WorkshopDetailInitial();
}

final class WorkshopDetailLoading extends WorkshopDetailState {
  const WorkshopDetailLoading();
}

final class WorkshopDetailLoaded extends WorkshopDetailState {
  const WorkshopDetailLoaded(this.workshop);
  final WorkshopDetail workshop;
}

final class WorkshopDetailFailure extends WorkshopDetailState {
  const WorkshopDetailFailure(this.message, {this.workshop});
  final String message;
  final WorkshopDetail? workshop;
}

class WorkshopDetailCubit extends Cubit<WorkshopDetailState> {
  WorkshopDetailCubit(this._getWorkshopDetail) : super(const WorkshopDetailInitial());

  final GetWorkshopDetail _getWorkshopDetail;
  String? _currentId;
  int _generation = 0;

  Future<void> load(String id) async {
    if (isClosed) return;
    final requestId = ++_generation;
    _currentId = id;
    emit(const WorkshopDetailLoading());
    try {
      final workshop = await _getWorkshopDetail(id);
      if (isClosed || requestId != _generation) return;
      emit(WorkshopDetailLoaded(workshop));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      emit(WorkshopDetailFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> refresh() async {
    if (isClosed) return;
    final id = _currentId;
    if (id == null) return;
    final requestId = ++_generation;
    final current = state is WorkshopDetailLoaded ? (state as WorkshopDetailLoaded).workshop : null;
    try {
      final workshop = await _getWorkshopDetail(id);
      if (isClosed || requestId != _generation) return;
      emit(WorkshopDetailLoaded(workshop));
    } catch (error) {
      if (isClosed || requestId != _generation) return;
      final message = ErrorMapper.from(error).message;
      if (current != null) {
        emit(WorkshopDetailFailure(message, workshop: current));
      } else {
        emit(WorkshopDetailFailure(message));
      }
    }
  }

  Future<void> retry() => _currentId == null ? Future.value() : load(_currentId!);
}