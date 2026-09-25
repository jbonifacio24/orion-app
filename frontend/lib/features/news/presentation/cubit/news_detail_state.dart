import 'package:equatable/equatable.dart';

import '../../domain/entities/news_detail.dart';

class NewsDetailState extends Equatable {
  const NewsDetailState({
    this.news,
    this.isLoading = false,
    this.failure,
    this.isNotFound = false,
  });

  final NewsDetail? news;
  final bool isLoading;
  final String? failure;
  final bool isNotFound;

  NewsDetailState copyWith({
    NewsDetail? news,
    bool clearNews = false,
    bool? isLoading,
    String? failure,
    bool clearFailure = false,
    bool? isNotFound,
  }) => NewsDetailState(
        news: clearNews ? null : news ?? this.news,
        isLoading: isLoading ?? this.isLoading,
        failure: clearFailure ? null : failure ?? this.failure,
        isNotFound: isNotFound ?? this.isNotFound,
      );

  @override
  List<Object?> get props => [news, isLoading, failure, isNotFound];
}