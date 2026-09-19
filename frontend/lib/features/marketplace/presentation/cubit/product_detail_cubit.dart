import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product_detail.dart';
import '../../domain/usecases/add_favorite.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/get_product_detail.dart';
import '../../domain/usecases/remove_favorite.dart';

sealed class ProductDetailState { const ProductDetailState(); }
final class ProductDetailInitial extends ProductDetailState { const ProductDetailInitial(); }
final class ProductDetailLoading extends ProductDetailState { const ProductDetailLoading(); }
final class ProductDetailLoaded extends ProductDetailState { const ProductDetailLoaded(this.product, {this.syncWarning}); final ProductDetail product; final String? syncWarning; }
final class ProductDetailFailure extends ProductDetailState { const ProductDetailFailure(this.message, {this.product}); final String message; final ProductDetail? product; }
final class ProductDetailDeleted extends ProductDetailState { const ProductDetailDeleted(); }

class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductDetailCubit(this._get, this._addFavorite, this._removeFavorite, this._delete) : super(const ProductDetailInitial());
  final GetProductDetail _get;
  final AddFavorite _addFavorite;
  final RemoveFavorite _removeFavorite;
  final DeleteProduct _delete;
  bool _mutating = false;

  Future<void> load(String id) async {
    emit(const ProductDetailLoading());
    try {
      emit(ProductDetailLoaded(await _get(id)));
    } catch (error) {
      emit(ProductDetailFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> refresh(String id) async {
    final current = state is ProductDetailLoaded ? (state as ProductDetailLoaded).product : null;
    try {
      emit(ProductDetailLoaded(await _get(id)));
    } catch (error) {
      if (current != null) {
        emit(ProductDetailLoaded(current, syncWarning: ErrorMapper.from(error).message));
      } else {
        emit(ProductDetailFailure(ErrorMapper.from(error).message));
      }
    }
  }

  Future<void> toggleFavorite() async {
    if (_mutating || state is! ProductDetailLoaded) {
      return;
    }
    final current = (state as ProductDetailLoaded).product;
    final updatedLocally = current.copyWith(isFavorite: !current.isFavorite);
    _mutating = true;
    try {
      if (current.isFavorite) {
        await _removeFavorite(current.id);
      } else {
        await _addFavorite(current.id);
      }
    } catch (error) {
      final message = ErrorMapper.from(error).message;
      emit(ProductDetailFailure(error is ConflictFailure ? 'No se pudo actualizar el favorito.' : message, product: current));
      _mutating = false;
      return;
    }
    emit(ProductDetailLoaded(updatedLocally));
    try {
      emit(ProductDetailLoaded(await _get(current.id)));
    } catch (error) {
      emit(ProductDetailLoaded(updatedLocally, syncWarning: ErrorMapper.from(error).message));
    } finally {
      _mutating = false;
    }
  }

  Future<bool> delete() async {
    if (_mutating || state is! ProductDetailLoaded) return false;
    final current = (state as ProductDetailLoaded).product;
    if (!current.isOwner) return false;
    _mutating = true;
    try { await _delete(current.id); emit(const ProductDetailDeleted()); return true; }
    catch (error) { emit(ProductDetailFailure(ErrorMapper.from(error).message, product: current)); return false; }
    finally { _mutating = false; }
  }
}
