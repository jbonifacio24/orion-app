import 'package:flutter/material.dart';

import '../../domain/entities/motorcycle.dart';

String? motorcycleImageUrl(Motorcycle motorcycle) {
  final images = [...motorcycle.images]..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  final primary = images.where((image) => image.isPrimary).isNotEmpty ? images.where((image) => image.isPrimary).first : null;
  final first = images.isEmpty ? null : images.first;
  return primary?.thumbnailUrl ?? primary?.url ?? first?.thumbnailUrl ?? first?.url;
}

class MotorcycleCard extends StatelessWidget {
  const MotorcycleCard({required this.motorcycle, required this.onTap, super.key});
  final Motorcycle motorcycle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 16 / 9, child: MotorcycleImagePreview(url: motorcycleImageUrl(motorcycle))),
            ListTile(title: Text('${motorcycle.brand} ${motorcycle.model}'), subtitle: Text('${motorcycle.year}'), trailing: motorcycle.isPrimary ? const Chip(label: Text('Principal')) : null),
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
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.two_wheeler, size: 56)));
    }
