import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_loading.dart';
import '../cubit/motorcycle_cubit.dart';
import '../widgets/motorcycle_form.dart';

class EditMotorcyclePage extends StatelessWidget {
  const EditMotorcyclePage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MotorcycleCubit>().state;
    final motorcycle = state.selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar motocicleta')),
      body: state.operation == MotorcycleOperation.loading && motorcycle == null ? const AppLoading() : motorcycle == null ? Text(state.message ?? 'Motocicleta no disponible.') : ListView(padding: const EdgeInsets.all(24), children: [
        if (state.message != null) Text(state.message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        MotorcycleForm(initial: motorcycle, loading: state.operation == MotorcycleOperation.updating, onSubmit: ({required brand, required model, required year, displacement, color, licensePlate, vin, description, required isPrimary}) async {
          final result = await context.read<MotorcycleCubit>().update(id: id, brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);
          if (context.mounted && result != null) Navigator.of(context).pop(true);
        }),
      ]),
    );
  }
}
