import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop_review.dart';

class WorkshopReviews extends StatelessWidget {
  const WorkshopReviews({required this.reviews, super.key});
  final List<WorkshopReview> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const Text(AppLocalizations.noReviews);
    return Column(children: reviews.map((review) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Text(review.rating.toString())),
          title: Text(_formatDate(review.createdAt)),
          subtitle: review.comment?.trim().isNotEmpty == true ? Text(review.comment!) : null,
        )).toList(growable: false));
  }

  String _formatDate(DateTime date) => '${date.toLocal().day.toString().padLeft(2, '0')}/${date.toLocal().month.toString().padLeft(2, '0')}/${date.toLocal().year}';
}