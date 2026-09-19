import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/update_product.dart';

enum ProductFormMode { create, edit }

class ProductFormState {
  const ProductFormState({this.submitting = false, this.product, this.error, this.success = false});
  final bool submitting;
  final Product? product;
  final String? error;
  final bool success;
}

class ProductFormCubit extends Cubit<ProductFormState> {
  ProductFormCubit(this._create, this._update, {required this.mode, this.initial}) : super(ProductFormState(product: initial));
  final CreateProduct _create;
  final UpdateProduct _update;
  final ProductFormMode mode;
  final Product? initial;
  bool _submitted = false;

  Future<bool> submit({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) async {
    if (_submitted) return false;
    if (mode == ProductFormMode.edit && (initial == null || initial!.rowVersion.isEmpty)) {
      emit(const ProductFormState(error: 'No se encontró la versión del producto para editar.'));
      return false;
    }
    _submitted = true;
    emit(ProductFormState(submitting: true, product: initial));
    try {
      final product = mode == ProductFormMode.create
          ? await _create(categoryId: categoryId, name: name, description: description, price: price, currency: price == null ? null : currency, stockQuantity: stockQuantity, condition: condition, location: location)
          : await _update(id: initial!.id, categoryId: categoryId, name: name, description: description, price: price, currency: price == null ? null : currency, stockQuantity: stockQuantity, condition: condition, location: location, expectedRowVersion: initial!.rowVersion);
      emit(ProductFormState(product: product, success: true));
      return true;
    } catch (error) {
      final failure = ErrorMapper.from(error);
      final message = failure is ConflictFailure ? 'Este producto fue modificado recientemente. Actualiza la información antes de guardar nuevamente.' : failure.message;
      emit(ProductFormState(product: initial, error: message));
      return false;
    } finally { _submitted = false; }
  }
}
