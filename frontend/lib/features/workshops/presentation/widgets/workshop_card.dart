import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop.dart';

class WorkshopCard extends StatelessWidget {
  const WorkshopCard({required this.workshop, required this.onTap, super.key});
  final Workshop workshop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasLocation = validWorkshopCoordinates(workshop.latitude, workshop.longitude);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(child: Icon(Icons.build_circle_outlined, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(workshop.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              if (workshop.description?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(workshop.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              if (workshop.city?.trim().isNotEmpty == true || workshop.address?.trim().isNotEmpty == true)
                Text([workshop.city, workshop.address].where((value) => value?.trim().isNotEmpty == true).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(children: [
                if (workshop.averageRating != null) ...[
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(workshop.averageRating!.toStringAsFixed(1)),
                  const SizedBox(width: 6),
                  Text('(${workshop.reviewCount})', style: Theme.of(context).textTheme.bodySmall),
                ] else
                  Text(AppLocalizations.noReviews, style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                Icon(hasLocation ? Icons.location_on_outlined : Icons.location_off_outlined, size: 18),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

bool validWorkshopCoordinates(double? latitude, double? longitude) =>
    latitude != null && longitude != null && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;