import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/usecases/get_categories.dart';

sealed class CategoriesState { const CategoriesState(); }
final class CategoriesInitial extends CategoriesState { const CategoriesInitial(); }
final class CategoriesLoading extends CategoriesState { const CategoriesLoading(); }
final class CategoriesLoaded extends CategoriesState { const CategoriesLoaded(this.categories); final List<ProductCategory> categories; }
final class CategoriesFailure extends CategoriesState { const CategoriesFailure(this.message); final String message; }

class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._getCategories) : super(const CategoriesInitial());
  final GetCategories _getCategories;
  List<ProductCategory>? _cache;

  Future<void> load() async {
    if (_cache != null) { emit(CategoriesLoaded(_cache!)); return; }
    emit(const CategoriesLoading());
    try {
      _cache = await _getCategories();
      emit(CategoriesLoaded(_cache!));
    } catch (error) { emit(CategoriesFailure(ErrorMapper.from(error).message)); }
  }
}
