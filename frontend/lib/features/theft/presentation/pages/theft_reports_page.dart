import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/theft_report.dart';
import '../cubit/theft_reports_cubit.dart';
import '../widgets/theft_report_card.dart';

class TheftReportsPage extends StatefulWidget {
  const TheftReportsPage({super.key});
  @override
  State<TheftReportsPage> createState() => _TheftReportsPageState();
}

class _TheftReportsPageState extends State<TheftReportsPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    context.read<TheftReportsCubit>().load();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels > _scrollController.position.maxScrollExtent - 300) {
      context.read<TheftReportsCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final created = await context.pushNamed<bool>('theft-report-create');
    if (mounted && created == true) context.read<TheftReportsCubit>().load();
  }

  Future<void> _deleteReport(TheftReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text('¿Deseas eliminar el reporte "${report.title}"? Esta acción lo ocultará de la lista pública.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cubit = context.read<TheftReportsCubit>();
    final deleted = await cubit.deleteReport(report.id);
    if (!mounted || deleted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cubit.state.error ?? 'No se pudo eliminar el reporte.')));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TheftReportsCubit>().state;
    final isAdmin = context.select<AuthCubit, bool>((cubit) => cubit.state is AuthAuthenticated && (cubit.state as AuthAuthenticated).user.roles.any((role) => role.toLowerCase() == 'admin'));
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes de robo'), actions: [IconButton(tooltip: 'Mis reportes', onPressed: () => context.pushNamed('my-theft-reports'), icon: const Icon(Icons.assignment_ind_outlined))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_alert), label: const Text('Reportar robo')),
      body: state.loading && state.reports.isEmpty
          ? const AppLoading()
          : state.error != null && state.reports.isEmpty
              ? Center(child: AppErrorState(message: state.error!))
              : state.reports.isEmpty
                  ? const AppEmptyState(message: 'No hay reportes activos.')
                  : RefreshIndicator(onRefresh: context.read<TheftReportsCubit>().load, child: ListView.separated(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: state.reports.length + (state.loadingMore || state.loadingMoreError != null ? 1 : 0), separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
                      if (index == state.reports.length) {
                        return state.loadingMoreError != null
                            ? Center(child: OutlinedButton.icon(onPressed: context.read<TheftReportsCubit>().retryLoadMore, icon: const Icon(Icons.refresh), label: const Text('Reintentar')))
                            : const Padding(padding: EdgeInsets.all(20), child: AppLoading(compact: true));
                      }
                      final report = state.reports[index];
                      return TheftReportCard(
                        report: report,
                        onTap: () => context.pushNamed('theft-report-detail', pathParameters: {'id': report.id}),
                        trailing: isAdmin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(label: Text(report.status.label), backgroundColor: Theme.of(context).colorScheme.errorContainer),
                                  IconButton(
                                    tooltip: 'Eliminar reporte',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: state.deletingReportId == null ? () => _deleteReport(report) : null,
                                    icon: state.deletingReportId == report.id ? const AppLoading(compact: true) : const Icon(Icons.delete_outline),
                                  ),
                                ],
                              )
                            : null,
                      );
                    })),
    );
  }
}