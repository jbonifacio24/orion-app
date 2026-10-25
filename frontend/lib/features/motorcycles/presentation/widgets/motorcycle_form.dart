import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/network/media_url_resolver.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/motorcycle.dart';
import '../../domain/entities/motorcycle_image_upload.dart';

class MotorcycleForm extends StatefulWidget {
  const MotorcycleForm({this.initial, required this.loading, required this.onSubmit, super.key});
  final Motorcycle? initial;
  final bool loading;
  final Future<void> Function({required String brand, required String model, required int year, int? displacement, String? color, String? licensePlate, String? vin, String? description, required bool isPrimary, required List<MotorcycleImageUpload> images}) onSubmit;

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
  final _images = <MotorcycleImageUpload>[];

  @override
  void dispose() { for (final controller in [_brand, _model, _year, _displacement, _color, _plate, _vin, _description]) { controller.dispose(); } super.dispose(); }

  String? _length(String? value, int max) => value != null && value.length > max ? 'Máximo $max caracteres.' : null;
  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null;

  Future<void> _pickImages() async {
    final remaining = 3 - (widget.initial?.images.length ?? 0) - _images.length;
    if (remaining <= 0) return;
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'], withData: true);
    if (!mounted || result == null) return;
    final selected = result.files.where((file) => file.bytes != null).take(remaining).map((file) => MotorcycleImageUpload(bytes: file.bytes!, fileName: file.name, sizeBytes: file.size));
    setState(() => _images.addAll(selected));
  }

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
          if ((widget.initial?.images.isNotEmpty ?? false) || _images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Fotos (${(widget.initial?.images.length ?? 0) + _images.length}/3)', style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 92, child: ListView(scrollDirection: Axis.horizontal, children: [
              ...?widget.initial?.images.map((image) => Padding(padding: const EdgeInsets.only(right: 8), child: Image.network(MediaUrlResolver.resolve(image.thumbnailUrl ?? image.url), width: 120, fit: BoxFit.cover))),
              ..._images.asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(right: 8), child: Stack(children: [Image.memory(entry.value.bytes, width: 120, height: 84, fit: BoxFit.cover), Positioned(right: 0, child: IconButton(onPressed: widget.loading ? null : () => setState(() => _images.removeAt(entry.key)), icon: const Icon(Icons.close), color: Colors.white))]))),
            ])),
          ],
          if ((widget.initial?.images.length ?? 0) + _images.length < 3) OutlinedButton.icon(onPressed: widget.loading ? null : _pickImages, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Añadir fotos (máximo 3)')),
          SwitchListTile(title: const Text('Marcar como principal'), value: _isPrimary, onChanged: widget.loading ? null : (value) => setState(() => _isPrimary = value)),
          AppButton(label: 'Guardar', loading: widget.loading, onPressed: () async { if (!_formKey.currentState!.validate()) return; await widget.onSubmit(brand: _brand.text.trim(), model: _model.text.trim(), year: int.parse(_year.text), displacement: int.tryParse(_displacement.text), color: _color.text.trim(), licensePlate: _plate.text.trim(), vin: _vin.text.trim(), description: _description.text.trim(), isPrimary: _isPrimary, images: List.unmodifiable(_images)); }),
        ]),
      );
}
