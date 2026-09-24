import 'package:flutter/material.dart';

import '../../domain/entities/theft_report.dart';

class TheftReportCard extends StatelessWidget {
  const TheftReportCard({required this.report, this.onTap, this.trailing, super.key});
  final TheftReport report;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (report.motorcycleName.isNotEmpty) report.motorcycleName,
      if (report.licensePlate?.trim().isNotEmpty == true) report.licensePlate!,
      '${report.theftDate.day.toString().padLeft(2, '0')}/${report.theftDate.month.toString().padLeft(2, '0')}/${report.theftDate.year}',
    ].join(' · ');
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.warning_amber_rounded),
        title: Text(report.title),
        subtitle: Text(subtitle),
        trailing: trailing ?? Chip(label: Text(report.status.label), backgroundColor: report.status.isActive ? colors.errorContainer : colors.secondaryContainer),
      ),
    );
  }
}