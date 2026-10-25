import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/travel_route.dart';
import '../../domain/repositories/travel_routes_repository.dart';

class TravelRoutesState {
  const TravelRoutesState({this.items = const [], this.isLoading = false, this.isSubmitting = false, this.error, this.actionMessage});

  final List<TravelRoute> items;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? actionMessage;

  TravelRoutesState copyWith({List<TravelRoute>? items, bool? isLoading, bool? isSubmitting, String? error, bool clearError = false, String? actionMessage, bool clearActionMessage = false}) => TravelRoutesState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearError ? null : error ?? this.error,
        actionMessage: clearActionMessage ? null : actionMessage ?? this.actionMessage,
      );
}

class TravelRoutesCubit extends Cubit<TravelRoutesState> {
  TravelRoutesCubit(this._repository) : super(const TravelRoutesState());

  final TravelRoutesRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, clearError: true, clearActionMessage: true));
    try {
      emit(state.copyWith(items: await _repository.getPublished(), isLoading: false));
    } catch (error) {
      emit(state.copyWith(isLoading: false, error: ErrorMapper.from(error).message));
    }
  }

  Future<bool> create(TravelRouteDraft draft) async {
    if (state.isSubmitting) return false;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearActionMessage: true));
    try {
      final created = await _repository.create(draft);
      emit(state.copyWith(items: [...state.items, created], isSubmitting: false, actionMessage: 'Ruta publicada correctamente.'));
      return true;
    } catch (error) {
      emit(state.copyWith(isSubmitting: false, error: ErrorMapper.from(error).message));
      return false;
    }
  }

  Future<String?> join(TravelRoute route) async {
    if (state.isSubmitting) return null;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearActionMessage: true));
    try {
      final conversationId = await _repository.join(route.id);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'Te has unido a ${route.title}.'));
      return conversationId;
    } catch (error) {
      emit(state.copyWith(isSubmitting: false, error: ErrorMapper.from(error).message));
      return null;
    }
  }

  Future<bool> delete(TravelRoute route) async {
    if (state.isSubmitting) return false;
    emit(state.copyWith(isSubmitting: true, clearError: true, clearActionMessage: true));
    try {
      await _repository.delete(route.id);
      emit(state.copyWith(items: state.items.where((item) => item.id != route.id).toList(growable: false), isSubmitting: false, actionMessage: 'Ruta eliminada.'));
      return true;
    } catch (error) {
      emit(state.copyWith(isSubmitting: false, error: ErrorMapper.from(error).message));
      return false;
    }
  }
}