import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../cubit/categories_cubit.dart';
import '../cubit/product_detail_cubit.dart';
import '../cubit/product_form_cubit.dart';
import '../widgets/product_form.dart';
import '../../domain/entities/product_detail.dart';

class EditProductPage extends StatefulWidget { const EditProductPage({required this.productId, super.key}); final String productId; @override State<EditProductPage> createState() => _EditProductPageState(); }
class _EditProductPageState extends State<EditProductPage> {
  ProductFormCubit? _formCubit;

  @override
  void initState() { super.initState(); context.read<CategoriesCubit>().load(); context.read<ProductDetailCubit>().load(widget.productId); }

  void _onDetailLoaded(ProductDetailLoaded state) {
    if (_formCubit != null) return;
    setState(() => _formCubit = getIt<ProductFormCubit>(param1: ProductFormMode.edit, param2: state.product));
  }

  @override
  void dispose() { _formCubit?.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) => BlocListener<ProductDetailCubit, ProductDetailState>(listener: (context, state) { if (state is ProductDetailLoaded) _onDetailLoaded(state); }, child: BlocBuilder<ProductDetailCubit, ProductDetailState>(builder: (context, detailState) { if (detailState is ProductDetailFailure) return Scaffold(appBar: AppBar(title: const Text('Editar producto')), body: Center(child: Text(detailState.message))); if (_formCubit == null || detailState is! ProductDetailLoaded) return const Scaffold(body: Center(child: CircularProgressIndicator())); return BlocProvider.value(value: _formCubit!, child: _EditForm(product: detailState.product)); }));
}

class _EditForm extends StatelessWidget {
  const _EditForm({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context) { final categories = context.watch<CategoriesCubit>().state; return BlocListener<ProductFormCubit, ProductFormState>(listenWhen: (previous, current) => !previous.success && current.success, listener: (context, state) => context.pop(true), child: Scaffold(appBar: AppBar(title: const Text('Editar producto')), body: categories is CategoriesLoaded ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: BlocBuilder<ProductFormCubit, ProductFormState>(builder: (context, form) => Column(children: [if (form.error != null) Text(form.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)), ProductForm(categories: categories.categories, initial: product, loading: form.submitting, onSubmit: context.read<ProductFormCubit>().submit)]))) : Center(child: categories is CategoriesFailure ? Text(categories.message) : const CircularProgressIndicator()))); }
}
