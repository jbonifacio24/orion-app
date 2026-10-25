import 'package:flutter/material.dart';

import '../../../../core/network/media_url_resolver.dart';
import '../../domain/entities/motorcycle.dart';

String? motorcycleImageUrl(Motorcycle motorcycle) {
  final images = [...motorcycle.images]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  final primary = images.where((image) => image.isPrimary).isNotEmpty ? images.where((image) => image.isPrimary).first : null;
  final first = images.isEmpty ? null : images.first;
  return primary?.thumbnailUrl ?? primary?.url ?? first?.thumbnailUrl ?? first?.url;
}

class MotorcycleCard extends StatelessWidget {
  const MotorcycleCard({required this.motorcycle, required this.onTap, this.onDelete, super.key});
  final Motorcycle motorcycle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 16 / 9, child: MotorcycleImagePreview(url: motorcycleImageUrl(motorcycle))),
            ListTile(title: Text('${motorcycle.brand} ${motorcycle.model}'), subtitle: Text('${motorcycle.year}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (motorcycle.isPrimary) const Chip(label: Text('Principal')), if (onDelete != null) IconButton(tooltip: 'Eliminar motocicleta', onPressed: onDelete, icon: const Icon(Icons.delete_outline))])),
          ]),
        ),
      );
}

    class MotorcycleImagePreview extends StatelessWidget {
      const MotorcycleImagePreview({this.url, super.key});
      final String? url;

      @override
      Widget build(BuildContext context) => url == null || url!.isEmpty
          ? const Center(child: Icon(Icons.two_wheeler, size: 56))
          : Image.network(
              MediaUrlResolver.resolve(url!),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.two_wheeler, size: 56)),
            );
    }
