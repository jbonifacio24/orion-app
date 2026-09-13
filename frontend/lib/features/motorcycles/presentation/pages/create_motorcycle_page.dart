import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/motorcycle_cubit.dart';
import '../widgets/motorcycle_form.dart';

class CreateMotorcyclePage extends StatelessWidget {
  const CreateMotorcyclePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Añadir motocicleta')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          BlocBuilder<MotorcycleCubit, MotorcycleState>(builder: (context, state) {
            return Column(children: [
              if (state.message != null) Text(state.message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              MotorcycleForm(loading: state.operation == MotorcycleOperation.creating, onSubmit: ({required brand, required model, required year, displacement, color, licensePlate, vin, description, required isPrimary}) async {
                final result = await context.read<MotorcycleCubit>().create(brand: brand, model: model, year: year, displacement: displacement, color: color, licensePlate: licensePlate, vin: vin, description: description, isPrimary: isPrimary);
                if (context.mounted && result != null) Navigator.of(context).pop(true);
              }),
            ]);
          }),
        ]),
      );
}
