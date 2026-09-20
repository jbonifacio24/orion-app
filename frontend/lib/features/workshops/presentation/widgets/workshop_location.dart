import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop_detail.dart';
import 'workshop_card.dart';

class WorkshopLocation extends StatelessWidget {
  const WorkshopLocation({required this.workshop, super.key});
  final WorkshopDetail workshop;

  @override
  Widget build(BuildContext context) {
    final hasCoordinates = validWorkshopCoordinates(workshop.latitude, workshop.longitude);
    final parts = [workshop.address, workshop.city].where((value) => value?.trim().isNotEmpty == true).cast<String>().toList(growable: false);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (parts.isNotEmpty) Text(parts.join(' · ')),
      if (hasCoordinates) ...[
        if (parts.isNotEmpty) const SizedBox(height: 6),
        Text('${AppLocalizations.coordinates}: ${workshop.latitude!.toStringAsFixed(6)}, ${workshop.longitude!.toStringAsFixed(6)}', style: Theme.of(context).textTheme.bodySmall),
      ],
      if (parts.isEmpty && !hasCoordinates) const Text(AppLocalizations.locationUnavailable),
    ]);
  }
}