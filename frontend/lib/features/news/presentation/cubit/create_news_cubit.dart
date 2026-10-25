import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/usecases/create_news.dart';

class CreateNewsState {
  const CreateNewsState({this.isSubmitting = false, this.message});

  final bool isSubmitting;
  final String? message;

  CreateNewsState copyWith({bool? isSubmitting, String? message, bool clearMessage = false}) => CreateNewsState(
        isSubmitting: isSubmitting ?? this.isSubmitting,
        message: clearMessage ? null : message ?? this.message,
      );
}

class CreateNewsCubit extends Cubit<CreateNewsState> {
  CreateNewsCubit(this._createNews) : super(const CreateNewsState());

  final CreateNews _createNews;

  Future<bool> submit({
    required String title,
    String? summary,
    required String content,
    String? featuredImageUrl,
  }) async {
    if (state.isSubmitting) return false;
    emit(state.copyWith(isSubmitting: true, clearMessage: true));
    try {
      await _createNews(
        title: title,
        summary: summary,
        content: content,
        featuredImageUrl: featuredImageUrl,
      );
      emit(state.copyWith(isSubmitting: false));
      return true;
    } catch (error) {
      emit(state.copyWith(isSubmitting: false, message: ErrorMapper.from(error).message));
      return false;
    }
  }
}
