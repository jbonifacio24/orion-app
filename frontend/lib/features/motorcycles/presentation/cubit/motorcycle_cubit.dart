import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/motorcycle.dart';
import '../../domain/usecases/create_motorcycle.dart';
import '../../domain/usecases/delete_motorcycle.dart';
import '../../domain/usecases/get_motorcycle_by_id.dart';
import '../../domain/usecases/get_motorcycles.dart';
import '../../domain/usecases/update_motorcycle.dart';

enum MotorcycleOperation { none, loading, creating, updating, deleting }

class MotorcycleState {
  const MotorcycleState({this.motorcycles = const [], this.selected, this.operation = MotorcycleOperation.none, this.message, this.syncWarning});

  final List<Motorcycle> motorcycles;
  final Motorcycle? selected;
  final MotorcycleOperation operation;
  final String? message;
  final String? syncWarning;

  MotorcycleState copyWith({List<Motorcycle>? motorcycles, Motorcycle? selected, bool clearSelected = false, MotorcycleOperation? operation, String? message, bool clearMessage = false, String? syncWarning, bool clearSyncWarning = false}) => MotorcycleState(
        motorcycles: motorcycles ?? this.motorcycles,
        selected: clearSelected ? null : selected ?? this.selected,
        operation: operation ?? this.operation,
        message: clearMessage ? null : message ?? this.message,
        syncWarning: clearSyncWarning ? null : syncWarning ?? this.syncWarning,
      );
}

class MotorcycleCubit extends Cubit<MotorcycleState> {
  MotorcycleCubit(this._getAll, this._getById, this._create, this._update, this._delete) : super(const MotorcycleState());

  final GetMotorcycles _getAll;
  final GetMotorcycleById _getById;
  final CreateMotorcycle _create;
  final UpdateMotorcycle _update;
  final DeleteMotorcycle _delete;
  bool _mutating = false;

  Future<void> loadMotorcycles() async {
    emit(state.copyWith(operation: MotorcycleOperation.loading, clearMessage: true));
    try {
      emit(state.copyWith(motorcycles: await _getAll(), operation: MotorcycleOperation.none));
    } catch (error) {
      emit(state.copyWith(operation: MotorcycleOperation.none, message: _message(error)));
    }
  }

  Future<void> loadMotorcycle(String id) async {
    emit(state.copyWith(operation: MotorcycleOperation.loading, clearMessage: true));
    try {
      emit(state.copyWith(selected: await _getById(id), operation: MotorcycleOperation.none));
    } catch (error) {
      emit(state.copyWith(operation: MotorcycleOperation.none, message: _message(error)));
    }
  }

  Future<Motorcycle?> create({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async {
    if (_mutating) return null;
    _mutating = true;
    emit(state.copyWith(operation: MotorcycleOperation.creating, clearMessage: true));
    try {
      final motorcycle = await _create(brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);
      emit(state.copyWith(selected: motorcycle, operation: MotorcycleOperation.none));
      await _refreshAfterMutation();
      return motorcycle;
    } catch (error) {
      emit(state.copyWith(operation: MotorcycleOperation.none, message: _message(error)));
      return null;
    } finally {
      _mutating = false;
    }
  }

  Future<Motorcycle?> update({required String id, required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) async {
    if (_mutating) return null;
    _mutating = true;
    emit(state.copyWith(operation: MotorcycleOperation.updating, clearMessage: true));
    try {
      final motorcycle = await _update(id: id, brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);
      emit(state.copyWith(selected: motorcycle, operation: MotorcycleOperation.none));
      await _refreshAfterMutation();
      return motorcycle;
    } catch (error) {
      emit(state.copyWith(operation: MotorcycleOperation.none, message: _message(error)));
      return null;
    } finally {
      _mutating = false;
    }
  }

  Future<bool> delete(String id) async {
    if (_mutating) return false;
    _mutating = true;
    emit(state.copyWith(operation: MotorcycleOperation.deleting, clearMessage: true));
    try {
      await _delete(id);
      emit(state.copyWith(clearSelected: true, operation: MotorcycleOperation.none));
      await _refreshAfterMutation();
      return true;
    } catch (error) {
      emit(state.copyWith(operation: MotorcycleOperation.none, message: _message(error)));
      return false;
    } finally {
      _mutating = false;
    }
  }

  Future<void> _refreshAfterMutation() async {
    try {
      emit(state.copyWith(motorcycles: await _getAll(), operation: MotorcycleOperation.none, clearSyncWarning: true));
    } catch (_) {
      emit(state.copyWith(
        operation: MotorcycleOperation.none,
        syncWarning: 'La operación se completó, pero no se pudo actualizar la lista.',
      ));
    }
  }

  String _message(Object error) {
    final failure = ErrorMapper.from(error);
    if (failure is ConflictFailure && failure.message.toLowerCase().contains('vin')) return 'Ya existe una motocicleta registrada con ese VIN.';
    if (failure is ConflictFailure) return 'No se pudo cambiar la motocicleta principal porque hubo un conflicto.';
    if (failure is NotFoundFailure) return 'La motocicleta ya no está disponible.';
    return failure.message;
  }
}
