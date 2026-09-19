import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/marketplace_cubit.dart';
import '../cubit/categories_cubit.dart';
import '../widgets/product_card.dart';
import '../widgets/filter_sheet.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});
  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  late final _search = TextEditingController();
  late final _scroll = ScrollController();
  @override
  void initState() { super.initState(); context.read<MarketplaceCubit>().load(); _scroll.addListener(_onScroll); }
  void _onScroll() { if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) context.read<MarketplaceCubit>().loadMore(); }
  @override
  void dispose() { _search.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MarketplaceCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace'), actions: [IconButton(onPressed: () async { final categoriesCubit = context.read<CategoriesCubit>(); await categoriesCubit.load(); if (!context.mounted) return; final categories = categoriesCubit.state; if (categories is CategoriesLoaded) { showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => FilterSheet(initial: state.filters, categories: categories.categories, onApply: context.read<MarketplaceCubit>().updateFilters)); } }, icon: const Icon(Icons.tune), tooltip: 'Filtros'), IconButton(onPressed: () => context.pushNamed('favorites'), icon: const Icon(Icons.favorite_border), tooltip: 'Favoritos')]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _search, onChanged: context.read<MarketplaceCubit>().searchChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar productos'))),
        Expanded(child: state.isInitialLoading && state.products.isEmpty ? const Center(child: CircularProgressIndicator()) : state.error != null && state.products.isEmpty ? Center(child: Text(state.error!)) : state.products.isEmpty ? const Center(child: Text('No hay productos disponibles.')) : RefreshIndicator(onRefresh: context.read<MarketplaceCubit>().refresh, child: ListView.builder(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: state.products.length + (state.isLoadingMore ? 1 : 0), itemBuilder: (context, index) { if (index == state.products.length) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())); final product = state.products[index]; return Padding(padding: const EdgeInsets.only(bottom: 12), child: ProductCard(product: product, onTap: () => context.pushNamed('marketplace-product-detail', pathParameters: {'id': product.id}))); }))),
      ]),
    );
  }
}
