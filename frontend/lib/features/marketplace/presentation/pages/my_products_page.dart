import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/my_products_cubit.dart';
import '../widgets/product_card.dart';

class MyProductsPage extends StatefulWidget { const MyProductsPage({super.key}); @override State<MyProductsPage> createState() => _MyProductsPageState(); }
class _MyProductsPageState extends State<MyProductsPage> {
  @override
  void initState() { super.initState(); context.read<MyProductsCubit>().load(); }
  @override
  Widget build(BuildContext context) { final state = context.watch<MyProductsCubit>().state; return Scaffold(appBar: AppBar(title: const Text('Mis productos')), floatingActionButton: FloatingActionButton.extended(onPressed: () => context.pushNamed('marketplace-create'), icon: const Icon(Icons.add), label: const Text('Publicar')), body: state.loading && state.products.isEmpty ? const Center(child: CircularProgressIndicator()) : state.error != null && state.products.isEmpty ? Center(child: Text(state.error!)) : state.products.isEmpty ? const Center(child: Text('Todavía no tienes productos.')) : RefreshIndicator(onRefresh: context.read<MyProductsCubit>().load, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.products.length, itemBuilder: (context, index) { final product = state.products[index]; return Padding(padding: const EdgeInsets.only(bottom: 12), child: ProductCard(product: product, onTap: () => context.pushNamed('marketplace-product-detail', pathParameters: {'id': product.id}))); }))); }
}
