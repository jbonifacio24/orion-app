import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop_detail.dart';
import '../cubit/workshop_detail_cubit.dart';
import '../widgets/workshop_location.dart';
import '../widgets/workshop_reviews.dart';
import '../widgets/workshop_schedule.dart';
import '../widgets/workshop_services.dart';

class WorkshopDetailPage extends StatefulWidget {
  const WorkshopDetailPage({required this.id, super.key});
  final String id;
  @override
  State<WorkshopDetailPage> createState() => _WorkshopDetailPageState();
}

class _WorkshopDetailPageState extends State<WorkshopDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<WorkshopDetailCubit>().load(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkshopDetailCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text(AppLocalizations.workshopDetail)),
      body: switch (state) {
        WorkshopDetailInitial() || WorkshopDetailLoading() => const Center(child: CircularProgressIndicator()),
        WorkshopDetailFailure(:final message, :final workshop) => workshop == null ? _Failure(message: message, onRetry: context.read<WorkshopDetailCubit>().retry) : _Content(workshop: workshop),
        WorkshopDetailLoaded(:final workshop) => _Content(workshop: workshop),
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.workshop});
  final WorkshopDetail workshop;

  @override
  Widget build(BuildContext context) {
    final rating = workshop.averageRating == null ? AppLocalizations.noReviews : '${workshop.averageRating!.toStringAsFixed(1)} (${workshop.reviewCount})';
    return RefreshIndicator(onRefresh: context.read<WorkshopDetailCubit>().refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
      Text(workshop.name, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(rating),
      if (workshop.description?.trim().isNotEmpty == true) ...[const SizedBox(height: 16), Text(workshop.description!)],
      if (workshop.phoneNumber?.trim().isNotEmpty == true || workshop.email?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 20),
        Text(AppLocalizations.contact, style: Theme.of(context).textTheme.titleMedium),
        if (workshop.phoneNumber?.trim().isNotEmpty == true) Text('${AppLocalizations.phone}: ${workshop.phoneNumber}'),
        if (workshop.email?.trim().isNotEmpty == true) Text('${AppLocalizations.email}: ${workshop.email}'),
      ],
      const SizedBox(height: 20),
      Text(AppLocalizations.address, style: Theme.of(context).textTheme.titleMedium),
      WorkshopLocation(workshop: workshop),
      const SizedBox(height: 20),
      Text(AppLocalizations.services, style: Theme.of(context).textTheme.titleMedium),
      WorkshopServices(services: workshop.services),
      const SizedBox(height: 20),
      Text(AppLocalizations.schedule, style: Theme.of(context).textTheme.titleMedium),
      WorkshopScheduleView(schedules: workshop.schedules),
      const SizedBox(height: 20),
      Text(AppLocalizations.reviews, style: Theme.of(context).textTheme.titleMedium),
      WorkshopReviews(reviews: workshop.reviews),
    ]));
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry))])));
}