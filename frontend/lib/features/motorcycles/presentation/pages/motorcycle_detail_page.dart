import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_loading.dart';
import '../cubit/motorcycle_cubit.dart';
import '../widgets/motorcycle_card.dart';

class MotorcycleDetailPage extends StatefulWidget {
  const MotorcycleDetailPage({required this.id, super.key});
  final String id;
  @override
  State<MotorcycleDetailPage> createState() => _MotorcycleDetailPageState();
}

class _MotorcycleDetailPageState extends State<MotorcycleDetailPage> {
  @override
  void initState() { super.initState(); context.read<MotorcycleCubit>().loadMotorcycle(widget.id); }

  Future<void> _delete(MotorcycleCubit cubit, bool isPrimary) async {
    final message = isPrimary ? 'Si eliminas tu motocicleta principal, otra motocicleta podrá pasar a ser principal automáticamente.' : 'Esta acción no se puede deshacer.';
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('¿Eliminar esta motocicleta?'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar'))])) ?? false;
    if (!confirmed || !mounted) return;
    if (await cubit.delete(widget.id) && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Motocicleta eliminada.'))); Navigator.of(context).pop(true); }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MotorcycleCubit>().state;
    final motorcycle = state.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Motocicleta')),
      body: state.operation == MotorcycleOperation.loading && motorcycle == null ? const AppLoading() : motorcycle == null ? Center(child: Text(state.message ?? 'La motocicleta ya no está disponible.')) : ListView(padding: const EdgeInsets.all(24), children: [
        MotorcycleImagePreview(url: motorcycleImageUrl(motorcycle)),
        const SizedBox(height: 16),
        Text('${motorcycle.brand} ${motorcycle.model}', style: Theme.of(context).textTheme.headlineSmall),
        if (motorcycle.isPrimary) const Chip(label: Text('Principal')),
        const SizedBox(height: 12),
        Text('Año: ${motorcycle.year}'),
        if (motorcycle.displacement != null) Text('Cilindrada: ${motorcycle.displacement}'),
        if (motorcycle.color?.isNotEmpty == true) Text('Color: ${motorcycle.color}'),
        if (motorcycle.licensePlate?.isNotEmpty == true) Text('Matrícula: ${motorcycle.licensePlate}'),
        if (motorcycle.vin?.isNotEmpty == true) Text('VIN: ${motorcycle.vin}'),
        if (motorcycle.description?.isNotEmpty == true) Text('Descripción: ${motorcycle.description}'),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: state.operation == MotorcycleOperation.none ? () => context.pushNamed('motorcycle-edit', pathParameters: {'id': motorcycle.id}) : null, icon: const Icon(Icons.edit), label: const Text('Editar')),
        OutlinedButton.icon(onPressed: state.operation == MotorcycleOperation.none ? () => _delete(context.read<MotorcycleCubit>(), motorcycle.isPrimary) : null, icon: const Icon(Icons.delete_outline), label: const Text('Eliminar')),
      ]),
    );
  }

}
