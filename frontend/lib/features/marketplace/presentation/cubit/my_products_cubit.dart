import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_filters.dart';
import '../../domain/usecases/get_my_products.dart';

class MyProductsState {
  const MyProductsState({this.products = const [], this.loading = false, this.error});
  final List<Product> products;
  final bool loading;
  final String? error;
}

class MyProductsCubit extends Cubit<MyProductsState> {
  MyProductsCubit(this._get) : super(const MyProductsState());
  final GetMyProducts _get;

  Future<void> load() async {
    emit(MyProductsState(products: state.products, loading: true));
    try { emit(MyProductsState(products: (await _get(const ProductFilters())).items)); }
    catch (error) { emit(MyProductsState(products: state.products, error: ErrorMapper.from(error).message)); }
  }
}
