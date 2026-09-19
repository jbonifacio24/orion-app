import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import 'price_label.dart';
import 'product_image.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = selectProductImageUrl(product.images) ?? '';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ProductImage(url: image, height: 150),
          Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            PriceLabel(price: product.price, currency: product.currency),
            const SizedBox(height: 4),
            Text(product.status.name, style: Theme.of(context).textTheme.bodySmall),
          ])),
        ]),
      ),
    );
  }
}
