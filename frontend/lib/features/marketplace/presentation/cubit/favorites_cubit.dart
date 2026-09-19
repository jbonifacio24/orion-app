import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/get_favorites.dart';
import '../../domain/usecases/remove_favorite.dart';

class FavoritesState {
  const FavoritesState({this.products = const [], this.loading = false, this.mutatingId, this.error});
  final List<Product> products;
  final bool loading;
  final String? mutatingId;
  final String? error;
}

class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit(this._get, this._add, this._remove) : super(const FavoritesState());
  final GetFavorites _get;
  final AddFavorite _add;
  final RemoveFavorite _remove;

  Future<void> load() async {
    emit(FavoritesState(products: state.products, loading: true));
    try { emit(FavoritesState(products: await _get())); } catch (error) { emit(FavoritesState(products: state.products, error: ErrorMapper.from(error).message)); }
  }

  Future<void> remove(String id) async {
    if (state.mutatingId != null) return;
    final previous = state.products;
    emit(FavoritesState(products: previous.where((item) => item.id != id).toList(growable: false), mutatingId: id));
    try { await _remove(id); emit(FavoritesState(products: state.products)); }
    catch (error) { emit(FavoritesState(products: previous, error: ErrorMapper.from(error).message)); }
  }

  Future<void> add(Product product) async {
    if (state.mutatingId != null || state.products.any((item) => item.id == product.id)) return;
    final previous = state.products;
    emit(FavoritesState(products: [...previous, product], mutatingId: product.id));
    try { await _add(product.id); emit(FavoritesState(products: state.products)); }
    catch (error) { emit(FavoritesState(products: previous, error: ErrorMapper.from(error).message)); }
  }
}
