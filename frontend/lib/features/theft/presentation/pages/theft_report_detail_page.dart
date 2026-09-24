import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/theft_report.dart';
import '../cubit/theft_report_detail_cubit.dart';

class TheftReportDetailPage extends StatefulWidget {
  const TheftReportDetailPage({required this.id, super.key});
  final String id;
  @override
  State<TheftReportDetailPage> createState() => _TheftReportDetailPageState();
}

class _TheftReportDetailPageState extends State<TheftReportDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<TheftReportDetailCubit>().load(widget.id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detalle del reporte')),
        body: switch (context.watch<TheftReportDetailCubit>().state) {
          TheftReportDetailInitial() || TheftReportDetailLoading() => const AppLoading(),
          TheftReportDetailFailure(:final message) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [AppErrorState(message: message), OutlinedButton.icon(onPressed: context.read<TheftReportDetailCubit>().retry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))])),
          TheftReportDetailLoaded(:final report) => _ReportDetail(report: report),
        },
      );
}

class _ReportDetail extends StatelessWidget {
  const _ReportDetail({required this.report});
  final TheftReport report;

  String _maskedVin(String vin) => vin.contains('*') ? vin : vin.length <= 4 ? '****' : '${'*' * (vin.length - 4)}${vin.substring(vin.length - 4)}';

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: context.read<TheftReportDetailCubit>().retry,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(report.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Chip(label: Text(report.status.label)),
          const SizedBox(height: 16),
          Text(report.description),
          const SizedBox(height: 24),
          if (report.motorcycleName.isNotEmpty) _Field(label: 'Motocicleta', value: report.motorcycleName),
          if (report.licensePlate?.trim().isNotEmpty == true) _Field(label: 'Matrícula', value: report.licensePlate!),
          if (report.vin?.trim().isNotEmpty == true) _Field(label: 'VIN', value: _maskedVin(report.vin!)),
          if (report.color?.trim().isNotEmpty == true) _Field(label: 'Color', value: report.color!),
          _Field(label: 'Fecha del robo', value: '${report.theftDate.day.toString().padLeft(2, '0')}/${report.theftDate.month.toString().padLeft(2, '0')}/${report.theftDate.year}'),
          if (report.theftLocation?.trim().isNotEmpty == true) _Field(label: 'Lugar', value: report.theftLocation!),
        ]),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.labelLarge), Text(value)]));
}