import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/categories_cubit.dart';
import '../cubit/product_form_cubit.dart';
import '../widgets/product_form.dart';

class CreateProductPage extends StatefulWidget { const CreateProductPage({super.key}); @override State<CreateProductPage> createState() => _CreateProductPageState(); }
class _CreateProductPageState extends State<CreateProductPage> {
  @override
  void initState() { super.initState(); context.read<CategoriesCubit>().load(); }
  @override
  Widget build(BuildContext context) { final categories = context.watch<CategoriesCubit>().state; return BlocListener<ProductFormCubit, ProductFormState>(listenWhen: (previous, current) => !previous.success && current.success, listener: (context, state) { final productId = state.product?.id; if (productId == null) return; context.goNamed('marketplace-product-images', pathParameters: {'id': productId}, queryParameters: {'from': 'create'}); }, child: Scaffold(appBar: AppBar(title: const Text('Crear producto')), body: categories is CategoriesLoaded ? SingleChildScrollView(padding: const EdgeInsets.all(20), child: BlocBuilder<ProductFormCubit, ProductFormState>(builder: (context, form) => ProductForm(categories: categories.categories, initial: null, loading: form.submitting, onSubmit: context.read<ProductFormCubit>().submit))) : Center(child: categories is CategoriesFailure ? Text(categories.message) : const CircularProgressIndicator()))); }
}
