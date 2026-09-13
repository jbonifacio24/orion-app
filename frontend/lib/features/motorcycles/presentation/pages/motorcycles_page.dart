import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/motorcycle_cubit.dart';
import '../widgets/motorcycle_card.dart';

class MotorcyclesPage extends StatefulWidget {
  const MotorcyclesPage({super.key});
  @override
  State<MotorcyclesPage> createState() => _MotorcyclesPageState();
}

class _MotorcyclesPageState extends State<MotorcyclesPage> {
  @override
  void initState() { super.initState(); context.read<MotorcycleCubit>().loadMotorcycles(); }

  Future<void> _open(BuildContext context, String location) async {
    final cubit = context.read<MotorcycleCubit>();
    await context.push(location);
    if (mounted) cubit.loadMotorcycles();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MotorcycleCubit>().state;
    final busy = state.operation == MotorcycleOperation.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis motocicletas')),
      floatingActionButton: FloatingActionButton.extended(onPressed: state.operation == MotorcycleOperation.none ? () => _open(context, '/motorcycles/create') : null, icon: const Icon(Icons.add), label: const Text('Añadir')),
      body: busy && state.motorcycles.isEmpty ? const AppLoading() : state.message != null && state.motorcycles.isEmpty ? AppErrorState(message: state.message!) : state.motorcycles.isEmpty ? const AppEmptyState(message: 'Todavía no tienes motocicletas.') : RefreshIndicator(onRefresh: context.read<MotorcycleCubit>().loadMotorcycles, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.motorcycles.length, itemBuilder: (context, index) { final motorcycle = state.motorcycles[index]; return Padding(padding: const EdgeInsets.only(bottom: 12), child: MotorcycleCard(motorcycle: motorcycle, onTap: () => _open(context, '/motorcycles/${motorcycle.id}'))); })),
    );
  }
}
