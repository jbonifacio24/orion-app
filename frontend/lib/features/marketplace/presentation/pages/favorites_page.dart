import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/favorites_cubit.dart';
import '../widgets/product_card.dart';

class FavoritesPage extends StatefulWidget { const FavoritesPage({super.key}); @override State<FavoritesPage> createState() => _FavoritesPageState(); }
class _FavoritesPageState extends State<FavoritesPage> {
  @override
  void initState() { super.initState(); context.read<FavoritesCubit>().load(); }
  @override
  Widget build(BuildContext context) { final state = context.watch<FavoritesCubit>().state; return Scaffold(appBar: AppBar(title: const Text('Favoritos')), body: state.loading && state.products.isEmpty ? const Center(child: CircularProgressIndicator()) : state.error != null && state.products.isEmpty ? Center(child: Text(state.error!)) : state.products.isEmpty ? const Center(child: Text('Todavía no tienes favoritos.')) : RefreshIndicator(onRefresh: context.read<FavoritesCubit>().load, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.products.length, itemBuilder: (context, index) { final product = state.products[index]; return Padding(padding: const EdgeInsets.only(bottom: 12), child: ProductCard(product: product, onTap: () => context.pushNamed('marketplace-product-detail', pathParameters: {'id': product.id}))); }))); }
}
