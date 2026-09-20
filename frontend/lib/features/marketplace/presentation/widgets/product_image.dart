import 'package:flutter/material.dart';

import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/product_image.dart' as domain;

String? selectProductImageUrl(List<domain.ProductImage> images) {
  if (images.isEmpty) return null;
  final ordered = [...images]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  return (ordered.where((image) => image.isPrimary).firstOrNull ?? ordered.first).url;
}

class ProductImage extends StatelessWidget {
  const ProductImage({required this.url, this.height = 180, super.key});
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: url.isEmpty
            ? const _Placeholder()
            : Image.network(MediaUrlResolver.resolve(url), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Placeholder()),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.two_wheeler, size: 48)));
}
