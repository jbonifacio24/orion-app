import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_events.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/usecases/get_news_detail.dart';
import 'news_detail_state.dart';

class NewsDetailCubit extends Cubit<NewsDetailState> {
  NewsDetailCubit(this._getNewsDetail, [SessionEvents? sessionEvents]) : super(const NewsDetailState()) {
    _sessionSubscription = sessionEvents?.onInvalidated.listen((_) => _invalidateRequests());
  }

  final GetNewsDetail _getNewsDetail;
  StreamSubscription<void>? _sessionSubscription;
  String? _currentNewsId;
  int _generation = 0;
  int _loadToken = 0;

  Future<void> load(String newsId) async {
    if (isClosed) return;
    final generation = ++_generation;
    final loadToken = ++_loadToken;
    _currentNewsId = newsId;
    emit(const NewsDetailState(isLoading: true));
    try {
      final news = await _getNewsDetail(newsId);
      if (isClosed || generation != _generation || loadToken != _loadToken) return;
      emit(NewsDetailState(news: news));
    } catch (error) {
      if (isClosed || generation != _generation || loadToken != _loadToken) return;
      final failure = ErrorMapper.from(error);
      emit(NewsDetailState(
        failure: failure.message,
        isNotFound: failure is NotFoundFailure,
      ));
    }
  }

  Future<void> retry() {
    final newsId = _currentNewsId;
    if (newsId == null || state.isLoading) return Future.value();
    return load(newsId);
  }

  void _invalidateRequests() {
    _generation++;
    _loadToken++;
    if (!isClosed) emit(state.copyWith(isLoading: false));
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}