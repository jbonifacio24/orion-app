import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../cubit/workshops_cubit.dart';
import '../widgets/workshop_card.dart';
import '../widgets/workshop_map_view.dart';

class WorkshopsPage extends StatefulWidget {
  const WorkshopsPage({super.key});
  @override
  State<WorkshopsPage> createState() => _WorkshopsPageState();
}

class _WorkshopsPageState extends State<WorkshopsPage> {
  late final _search = TextEditingController();
  late final _city = TextEditingController();
  late final _scroll = ScrollController();
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    context.read<WorkshopsCubit>().load();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) context.read<WorkshopsCubit>().loadMore();
  }

  @override
  void dispose() {
    _search.dispose();
    _city.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WorkshopsCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text(AppLocalizations.workshops)),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: TextField(controller: _search, onChanged: context.read<WorkshopsCubit>().searchChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: AppLocalizations.searchWorkshops))),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(controller: _city, onChanged: context.read<WorkshopsCubit>().cityChanged, decoration: const InputDecoration(prefixIcon: Icon(Icons.location_city), labelText: AppLocalizations.city))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Semantics(
            label: AppLocalizations.workshopsViewMode,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.list), label: Text(AppLocalizations.listView)),
                ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text(AppLocalizations.mapView)),
              ],
              selected: {_showMap},
              onSelectionChanged: (selection) => setState(() => _showMap = selection.single),
            ),
          ),
        ),
        Expanded(child: _buildContent(context, state)),
      ]),
    );
  }

  Widget _buildContent(BuildContext context, WorkshopsState state) {
    if (state.isInitialLoading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.failure != null && state.items.isEmpty) return _Failure(message: state.failure!, onRetry: context.read<WorkshopsCubit>().retry);
    if (_showMap) {
      return WorkshopMapView(
        workshops: state.items,
        onWorkshopTap: (id) => context.pushNamed('workshop-detail', pathParameters: {'id': id}),
      );
    }
    if (state.items.isEmpty) return const Center(child: Text(AppLocalizations.noWorkshops));
    return RefreshIndicator(
      onRefresh: context.read<WorkshopsCubit>().refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: state.items.length + (state.isLoadingMore || state.loadingMoreFailure != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.items.length) return state.loadingMoreFailure != null ? _Failure(message: state.loadingMoreFailure!, onRetry: context.read<WorkshopsCubit>().retryLoadMore) : const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
          final workshop = state.items[index];
          return Padding(padding: const EdgeInsets.only(bottom: 12), child: WorkshopCard(workshop: workshop, onTap: () => context.pushNamed('workshop-detail', pathParameters: {'id': workshop.id})));
        },
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry))])));
}