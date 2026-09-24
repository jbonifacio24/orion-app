import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/theft_report.dart';
import '../cubit/my_theft_reports_cubit.dart';
import '../widgets/theft_report_card.dart';

class MyTheftReportsPage extends StatefulWidget {
  const MyTheftReportsPage({super.key});
  @override
  State<MyTheftReportsPage> createState() => _MyTheftReportsPageState();
}

class _MyTheftReportsPageState extends State<MyTheftReportsPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    context.read<MyTheftReportsCubit>().load();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      context.read<MyTheftReportsCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await context.pushNamed<bool>('theft-report-create');
    if (mounted && created == true) context.read<MyTheftReportsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MyTheftReportsCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes de robo')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_alert), label: const Text('Reportar robo')),
      body: state.loading && state.reports.isEmpty
          ? const AppLoading()
          : state.error != null && state.reports.isEmpty
              ? Center(child: AppErrorState(message: state.error!))
            : state.reports.isEmpty
              ? const AppEmptyState(message: 'Todavía no has creado reportes.')
              : RefreshIndicator(
                  onRefresh: context.read<MyTheftReportsCubit>().load,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: state.reports.length + (state.loadingMore || state.loadingMoreError != null ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == state.reports.length) {
                        return state.loadingMoreError != null
                            ? Center(child: OutlinedButton.icon(onPressed: context.read<MyTheftReportsCubit>().retryLoadMore, icon: const Icon(Icons.refresh), label: const Text('Reintentar')))
                            : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                      }
                      final report = state.reports[index];
                      return TheftReportCard(
                        report: report,
                        onTap: () => context.pushNamed('theft-report-detail', pathParameters: {'id': report.id}),
                        trailing: state.updatingId == report.id
                            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : report.status.isActive
                                ? PopupMenuButton<TheftReportStatus>(
                                    tooltip: 'Resolver reporte',
                                    onSelected: (status) => context.read<MyTheftReportsCubit>().updateStatus(report.id, status),
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(value: TheftReportStatus.recovered, child: Text('Marcar como recuperado')),
                                      PopupMenuItem(value: TheftReportStatus.closed, child: Text('Cerrar reporte')),
                                    ],
                                  )
                                : Chip(label: Text(report.status.label)),
                      );
                    },
                  ),
                ),
    );
  }
}