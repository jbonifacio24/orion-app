import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/motorcycle.dart';

class MotorcycleForm extends StatefulWidget {
  const MotorcycleForm({this.initial, required this.loading, required this.onSubmit, super.key});
  final Motorcycle? initial;
  final bool loading;
  final Future<void> Function({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary}) onSubmit;

  @override
  State<MotorcycleForm> createState() => _MotorcycleFormState();
}

class _MotorcycleFormState extends State<MotorcycleForm> {
  late final _brand = TextEditingController(text: widget.initial?.brand);
  late final _model = TextEditingController(text: widget.initial?.model);
  late final _year = TextEditingController(text: widget.initial?.year.toString());
  late final _displacement = TextEditingController(text: widget.initial?.displacement?.toString());
  late final _color = TextEditingController(text: widget.initial?.color);
  late final _plate = TextEditingController(text: widget.initial?.licensePlate);
  late final _vin = TextEditingController(text: widget.initial?.vin);
  late final _description = TextEditingController(text: widget.initial?.description);
  final _formKey = GlobalKey<FormState>();
  late bool _isPrimary = widget.initial?.isPrimary ?? false;

  @override
  void dispose() { for (final controller in [_brand, _model, _year, _displacement, _color, _plate, _vin, _description]) { controller.dispose(); } super.dispose(); }

  String? _length(String? value, int max) => value != null && value.length > max ? 'Máximo $max caracteres.' : null;
  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null;

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _brand, maxLength: 100, decoration: const InputDecoration(labelText: 'Marca'), validator: (value) => _required(value) ?? _length(value, 100)),
          TextFormField(controller: _model, maxLength: 100, decoration: const InputDecoration(labelText: 'Modelo'), validator: (value) => _required(value) ?? _length(value, 100)),
          TextFormField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Año'), validator: (value) { final year = int.tryParse(value ?? ''); return year == null || year < 1885 || year > 2200 ? 'Año entre 1885 y 2200.' : null; }),
          TextFormField(controller: _displacement, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cilindrada'), validator: (value) { if (value == null || value.trim().isEmpty) return null; final displacement = int.tryParse(value); return displacement != null && displacement > 0 ? null : 'Debe ser mayor que cero.'; }),
          TextFormField(controller: _color, maxLength: 50, decoration: const InputDecoration(labelText: 'Color'), validator: (value) => _length(value, 50)),
          TextFormField(controller: _plate, maxLength: 30, decoration: const InputDecoration(labelText: 'Matrícula'), validator: (value) => _length(value, 30)),
          TextFormField(controller: _vin, maxLength: 100, decoration: const InputDecoration(labelText: 'VIN'), validator: (value) => _length(value, 100)),
          TextFormField(controller: _description, maxLength: 5000, maxLines: 4, decoration: const InputDecoration(labelText: 'Descripción'), validator: (value) => _length(value, 5000)),
          SwitchListTile(title: const Text('Marcar como principal'), value: _isPrimary, onChanged: widget.loading ? null : (value) => setState(() => _isPrimary = value)),
          AppButton(label: 'Guardar', loading: widget.loading, onPressed: () async { if (!_formKey.currentState!.validate()) return; await widget.onSubmit(brand: _brand.text.trim(), model: _model.text.trim(), year: int.parse(_year.text), displacement: int.tryParse(_displacement.text), color: _color.text.trim(), licensePlate: _plate.text.trim(), vin: _vin.text.trim(), description: _description.text.trim(), isPrimary: _isPrimary); }),
        ]),
      );
}
