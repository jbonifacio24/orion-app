import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/workshop_schedule.dart';

class WorkshopScheduleView extends StatelessWidget {
  const WorkshopScheduleView({required this.schedules, super.key});
  final List<WorkshopSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) return const Text(AppLocalizations.noSchedule);
    return Column(children: schedules.map((schedule) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_dayName(schedule.dayOfWeek)),
          trailing: Text(schedule.isClosed ? AppLocalizations.closed : _timeRange(schedule)),
        )).toList(growable: false));
  }

  String _dayName(int day) => switch (day) {
        0 => AppLocalizations.sunday,
        1 => AppLocalizations.monday,
        2 => AppLocalizations.tuesday,
        3 => AppLocalizations.wednesday,
        4 => AppLocalizations.thursday,
        5 => AppLocalizations.friday,
        6 => AppLocalizations.saturday,
        _ => AppLocalizations.schedule,
      };

  String _timeRange(WorkshopSchedule schedule) {
    final open = schedule.openTime?.substring(0, schedule.openTime!.length >= 5 ? 5 : schedule.openTime!.length);
    final close = schedule.closeTime?.substring(0, schedule.closeTime!.length >= 5 ? 5 : schedule.closeTime!.length);
    if (open == null && close == null) return AppLocalizations.locationUnavailable;
    return '${open ?? '--:--'} - ${close ?? '--:--'}';
  }
}