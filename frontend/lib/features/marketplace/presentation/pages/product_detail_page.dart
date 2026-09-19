import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/product_detail_cubit.dart';
import '../../domain/entities/product.dart';
import '../widgets/favorite_button.dart';
import '../widgets/price_label.dart';
import '../widgets/product_image.dart';

class ProductDetailPage extends StatefulWidget { const ProductDetailPage({required this.id, super.key}); final String id; @override State<ProductDetailPage> createState() => _ProductDetailPageState(); }
class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() { super.initState(); context.read<ProductDetailCubit>().load(widget.id); }
  Future<void> _delete() async { final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Eliminar producto?'), content: const Text('Esta acción no se puede deshacer.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))])) ?? false; if (!confirmed || !mounted) return; if (await context.read<ProductDetailCubit>().delete() && mounted) context.pop(); }
  @override
  Widget build(BuildContext context) { final state = context.watch<ProductDetailCubit>().state; final product = state is ProductDetailLoaded ? state.product : state is ProductDetailFailure ? state.product : null; final detailCubit = context.read<ProductDetailCubit>(); return Scaffold(appBar: AppBar(title: const Text('Producto')), body: state is ProductDetailLoading && product == null ? const Center(child: CircularProgressIndicator()) : product == null ? Center(child: Text(state is ProductDetailFailure ? state.message : 'Producto no disponible.')) : RefreshIndicator(onRefresh: () => detailCubit.refresh(widget.id), child: ListView(padding: const EdgeInsets.all(20), children: [ProductImage(url: selectProductImageUrl(product.images) ?? '', height: 240), const SizedBox(height: 16), Row(children: [Expanded(child: Text(product.name, style: Theme.of(context).textTheme.headlineSmall)), FavoriteButton(selected: product.isFavorite, loading: false, onPressed: detailCubit.toggleFavorite)]), if (state is ProductDetailLoaded && state.syncWarning != null) Text(state.syncWarning!, style: TextStyle(color: Theme.of(context).colorScheme.error)), PriceLabel(price: product.price, currency: product.currency), const SizedBox(height: 12), Text(product.condition == ProductCondition.newProduct ? 'Nueva' : 'Usada'), Text(product.description), if (product.location?.isNotEmpty == true) Text('Ubicación: ${product.location}'), Text('Vendedor: ${product.seller.displayName ?? product.seller.userName}'), if (product.isOwner) ...[const SizedBox(height: 20), FilledButton.icon(onPressed: () async { final changed = await context.pushNamed('marketplace-product-edit', pathParameters: {'id': product.id}); if (!mounted) return; if (changed == true) await detailCubit.refresh(widget.id); }, icon: const Icon(Icons.edit), label: const Text('Editar')), OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('Eliminar'))]]))); }
}
