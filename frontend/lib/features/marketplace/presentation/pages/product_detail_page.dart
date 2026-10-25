import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_loading.dart';
import '../../../../core/network/media_url_resolver.dart';
import '../../../chat/presentation/cubit/conversations_cubit.dart';
import '../cubit/product_detail_cubit.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/seller_summary.dart';
import '../widgets/favorite_button.dart';
import '../widgets/price_label.dart';
import '../widgets/product_image.dart';
import '../../../marketplace_transactions/presentation/cubit/product_transaction_cubit.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({required this.id, super.key});
  final String id;
  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<ProductDetailCubit>().load(widget.id);
    context.read<ProductTransactionCubit>().loadMine();
  }

  void _showNavigationMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Inicio'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('home');
                }),
            ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Marketplace'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('marketplace');
                }),
            ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Mis productos'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('my-products');
                }),
            ListTile(
                leading: const Icon(Icons.favorite_border),
                title: const Text('Favoritos'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('favorites');
                }),
            ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: const Text('Conversaciones'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.goNamed('conversations');
                }),
          ],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    title: const Text('¿Eliminar producto?'),
                    content: const Text('Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar'))
                    ])) ??
        false;
    if (!confirmed || !mounted) return;
    if (await context.read<ProductDetailCubit>().delete() && mounted)
      context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductDetailCubit>().state;
    final product = state is ProductDetailLoaded
        ? state.product
        : state is ProductDetailFailure
            ? state.product
            : null;
    final detailCubit = context.read<ProductDetailCubit>();
    final transactions = context
        .watch<ProductTransactionCubit>()
        .state
        .items
        .where((item) => item.productId == product?.id)
        .toList();
    final conversationsCubit = context.read<ConversationsCubit>();
    return Scaffold(
        appBar: AppBar(
            title: const Text('Producto'),
            leading: IconButton(
                tooltip: 'Volver',
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.goNamed('marketplace'),
                icon: const Icon(Icons.arrow_back)),
            actions: [
              IconButton(
                  tooltip: 'Menú',
                  onPressed: _showNavigationMenu,
                  icon: const Icon(Icons.menu))
            ]),
        body: state is ProductDetailLoading && product == null
            ? const AppLoading()
            : product == null
                ? Center(
                    child: Text(state is ProductDetailFailure
                        ? state.message
                        : 'Producto no disponible.'))
                : RefreshIndicator(
                    onRefresh: () => detailCubit.refresh(widget.id),
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      ProductImage(
                          url: selectProductImageUrl(product.images) ?? '',
                          height: 240),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: Text(product.name,
                                style:
                                    Theme.of(context).textTheme.headlineSmall)),
                        FavoriteButton(
                            selected: product.isFavorite,
                            loading: false,
                            onPressed: detailCubit.toggleFavorite)
                      ]),
                      if (state is ProductDetailLoaded &&
                          state.syncWarning != null)
                        Text(state.syncWarning!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      PriceLabel(
                          price: product.price, currency: product.currency),
                      const SizedBox(height: 12),
                      Text(product.condition == ProductCondition.newProduct
                          ? 'Nueva'
                          : 'Usada'),
                      Text(product.description),
                      if (product.latitude != null &&
                          product.longitude != null) ...[
                        const SizedBox(height: 16),
                        Text('Ubicación',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                    product.latitude!, product.longitude!),
                                initialZoom: 14,
                              ),
                              children: [
                                TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.motohub.app'),
                                MarkerLayer(markers: [
                                  Marker(
                                    point: LatLng(
                                        product.latitude!, product.longitude!),
                                    width: 48,
                                    height: 52,
                                    child: Icon(Icons.location_on,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 44),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ] else if (product.location?.isNotEmpty == true)
                        Text('Ubicación: ${product.location}'),
                      if (product.paymentMethod?.isNotEmpty == true) ...[
                        const SizedBox(height: 12),
                        Text('Modalidad de pago: ${product.paymentMethod}'),
                      ],
                      Text(
                          'Vendedor: ${product.seller.displayName ?? product.seller.userName}'),
                      const SizedBox(height: 12),
                      _SellerTrustCard(seller: product.seller),
                      if (!product.isOwner) ...[
                        const SizedBox(height: 20),
                        _buyerActions(
                          context,
                          product.id,
                          product.seller.id,
                          conversationsCubit,
                          transactions.isEmpty ? null : transactions.first.id,
                        ),
                      ],
                      if (product.isOwner) ...[
                        const SizedBox(height: 20),
                        _ownerActions(
                            context,
                            product,
                            detailCubit,
                            transactions.isEmpty
                                ? null
                                : transactions.first.id),
                      ]
                    ])));
  }

  Widget _buyerActions(
    BuildContext context,
    String productId,
    String sellerId,
    ConversationsCubit conversationsCubit,
    String? transactionId,
  ) {
    final actions = <Widget>[
      _AnimatedProductAction(
        delay: const Duration(milliseconds: 0),
        child: FilledButton.icon(
          onPressed: () => context.pushNamed(
            'marketplace-offer',
            pathParameters: {'productId': productId},
          ),
          icon: const Icon(Icons.local_offer_outlined),
          label: const Text('Hacer oferta'),
        ),
      ),
      _AnimatedProductAction(
        delay: const Duration(milliseconds: 70),
        child: OutlinedButton.icon(
          onPressed: conversationsCubit.state.isCreating
              ? null
              : () async {
                  final conversation =
                      await conversationsCubit.getOrCreateDirect(sellerId);
                  if (!context.mounted || conversation == null) return;
                  context.pushNamed(
                    'chat',
                    pathParameters: {
                      'conversationId': conversation.id,
                    },
                  );
                },
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(
            conversationsCubit.state.isCreating
                ? 'Abriendo chat...'
                : 'Contactar vendedor',
          ),
        ),
      ),
      if (transactionId != null)
        _AnimatedProductAction(
          delay: const Duration(milliseconds: 140),
          child: OutlinedButton.icon(
            onPressed: () => context.pushNamed(
              'marketplace-transaction',
              pathParameters: {'id': transactionId},
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver operación'),
          ),
        ),
    ];

    return _responsiveActionLayout(actions);
  }

  Widget _ownerActions(BuildContext context, Product product,
      ProductDetailCubit detailCubit, String? transactionId) {
    final actions = <Widget>[
      if (transactionId != null)
        _AnimatedProductAction(
          delay: const Duration(milliseconds: 0),
          child: OutlinedButton.icon(
            onPressed: () => context.pushNamed('marketplace-transaction',
                pathParameters: {'id': transactionId}),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Operación'),
          ),
        ),
      _AnimatedProductAction(
        delay: const Duration(milliseconds: 70),
        child: FilledButton.icon(
          onPressed: () async {
            final changed = await context.pushNamed('marketplace-product-edit',
                pathParameters: {'id': product.id});
            if (!mounted) return;
            if (changed == true) await detailCubit.refresh(widget.id);
          },
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
      ),
      _AnimatedProductAction(
        delay: const Duration(milliseconds: 140),
        child: OutlinedButton.icon(
          onPressed: () => context.pushNamed('marketplace-product-images',
              pathParameters: {'id': product.id}),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Imágenes'),
        ),
      ),
      _AnimatedProductAction(
        delay: const Duration(milliseconds: 210),
        child: OutlinedButton.icon(
          onPressed: _delete,
          style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar'),
        ),
      ),
    ];

    return _responsiveActionLayout(actions);
  }

  Widget _responsiveActionLayout(List<Widget> actions) {
    return LayoutBuilder(builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= actions.length * 220;
      if (horizontal) {
        return Row(children: [
          for (final action in actions)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: action,
              ),
            ),
        ]);
      }
      return Column(children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(width: double.infinity, child: action),
          ),
      ]);
    });
  }
}

class _AnimatedProductAction extends StatefulWidget {
  const _AnimatedProductAction({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_AnimatedProductAction> createState() => _AnimatedProductActionState();
}

class _AnimatedProductActionState extends State<_AnimatedProductAction> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, .12),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          child: SizedBox(height: 52, child: widget.child),
        ),
      );
}

class _SellerTrustCard extends StatelessWidget {
  const _SellerTrustCard({required this.seller});

  final SellerSummary seller;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final sellerName = seller.displayName ?? seller.userName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: accent.withValues(alpha: 0.16),
            backgroundImage: seller.profileImageUrl == null
                ? null
                : NetworkImage(
                    MediaUrlResolver.resolve(seller.profileImageUrl!)),
            child: seller.profileImageUrl == null
                ? Icon(Icons.person_rounded, color: accent, size: 28)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sellerName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Row(children: [
                ...List.generate(
                    5,
                    (index) => Icon(
                        index + 1 <= seller.averageRating
                            ? Icons.star_rounded
                            : index < seller.averageRating
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                        size: 18,
                        color: const Color(0xFFFFB11B))),
                const SizedBox(width: 6),
                Text(
                    seller.ratingCount == 0
                        ? 'Sin reseñas'
                        : '${seller.averageRating.toStringAsFixed(1)} (${seller.ratingCount})',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.verified_rounded, size: 16, color: accent),
                const SizedBox(width: 4),
                Text('${seller.successfulSales} ventas exitosas',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
