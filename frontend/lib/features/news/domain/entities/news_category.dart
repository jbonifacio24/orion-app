import 'package:equatable/equatable.dart';

class NewsCategory extends Equatable {
  const NewsCategory({required this.id, required this.name, required this.slug});

  final String id;
  final String name;
  final String slug;

  @override
  List<Object?> get props => [id, name, slug];
}