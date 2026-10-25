import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
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
    final isAdmin = context.select<AuthCubit, bool>((cubit) => cubit.state is AuthAuthenticated && (cubit.state as AuthAuthenticated).user.roles.any((role) => role.toLowerCase() == 'admin'));
    final busy = state.operation == MotorcycleOperation.loading;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis motocicletas')),
      floatingActionButton: FloatingActionButton.extended(onPressed: state.operation == MotorcycleOperation.none ? () => _open(context, '/motorcycles/create') : null, icon: const Icon(Icons.add), label: const Text('Añadir')),
      body: busy && state.motorcycles.isEmpty ? const AppLoading() : state.message != null && state.motorcycles.isEmpty ? AppErrorState(message: state.message!) : state.motorcycles.isEmpty ? const AppEmptyState(message: 'Todavía no tienes motocicletas.') : RefreshIndicator(onRefresh: context.read<MotorcycleCubit>().loadMotorcycles, child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: state.motorcycles.length, itemBuilder: (context, index) { final motorcycle = state.motorcycles[index]; return Padding(padding: const EdgeInsets.only(bottom: 12), child: MotorcycleCard(motorcycle: motorcycle, onTap: () => _open(context, '/motorcycles/${motorcycle.id}'), onDelete: isAdmin ? () => _delete(context, motorcycle.id, motorcycle.isPrimary) : null)); })),
    );
  }

  Future<void> _delete(BuildContext context, String id, bool isPrimary) async {
    final message = isPrimary ? 'Si eliminas tu motocicleta principal, otra motocicleta podrá pasar a ser principal automáticamente.' : 'Esta acción no se puede deshacer.';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Eliminar esta motocicleta?'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))])) ?? false;
    if (!confirmed || !context.mounted) return;
    final cubit = context.read<MotorcycleCubit>();
    final deleted = await cubit.deleteAsAdmin(id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(deleted ? 'Motocicleta eliminada.' : cubit.state.message ?? 'No se pudo eliminar la motocicleta.')));
  }
}
