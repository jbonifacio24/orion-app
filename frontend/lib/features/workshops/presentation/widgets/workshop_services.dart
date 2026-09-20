import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop_service.dart';

class WorkshopServices extends StatelessWidget {
  const WorkshopServices({required this.services, super.key});
  final List<WorkshopService> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const Text(AppLocalizations.noServices);
    return Column(children: services.map((service) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.build_outlined),
          title: Text(service.name),
          subtitle: service.description?.trim().isNotEmpty == true ? Text(service.description!) : null,
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (service.price != null) Text(service.price!.toStringAsFixed(2)),
            if (service.durationMinutes != null) Text('${service.durationMinutes} ${AppLocalizations.minutes}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        )).toList(growable: false));
  }
}