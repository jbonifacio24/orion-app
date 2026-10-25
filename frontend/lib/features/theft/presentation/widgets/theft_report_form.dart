import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../motorcycles/domain/entities/motorcycle.dart';
import '../../domain/entities/theft_report.dart';
import 'theft_location_picker.dart';

class TheftReportForm extends StatefulWidget {
  const TheftReportForm({required this.motorcycles, required this.loading, required this.onSubmit, super.key});
  final List<Motorcycle> motorcycles;
  final bool loading;
  final Future<bool> Function(CreateTheftReportInput input) onSubmit;

  @override
  State<TheftReportForm> createState() => _TheftReportFormState();
}

class _TheftReportFormState extends State<TheftReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  final _color = TextEditingController();
  final _location = TextEditingController();
  DateTime _theftDate = DateTime.now();
  bool _useOwnMotorcycle = true;
  String? _motorcycleId;
  LatLng? _selectedLocation;

  @override
  void dispose() {
    for (final controller in [_title, _description, _brand, _model, _plate, _vin, _color, _location]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null;
  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: _theftDate, firstDate: DateTime(2000), lastDate: DateTime.now());
    if (date != null && mounted) setState(() => _theftDate = date);
  }

  Future<void> _pickLocation() async {
    final location = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * 0.84, child: TheftLocationPicker(initialLocation: _selectedLocation)),
    );
    if (location != null && mounted) setState(() => _selectedLocation = location);
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(controller: _title, maxLength: 200, decoration: const InputDecoration(labelText: 'Título'), validator: _required),
          TextFormField(controller: _description, maxLength: 10000, maxLines: 4, decoration: const InputDecoration(labelText: 'Descripción'), validator: _required),
          ListTile(contentPadding: EdgeInsets.zero, title: const Text('Fecha del robo'), subtitle: Text('${_theftDate.day.toString().padLeft(2, '0')}/${_theftDate.month.toString().padLeft(2, '0')}/${_theftDate.year}'), trailing: IconButton(tooltip: 'Cambiar fecha', onPressed: widget.loading ? null : _pickDate, icon: const Icon(Icons.calendar_today))),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, icon: Icon(Icons.two_wheeler), label: Text('Mi motocicleta')), ButtonSegment(value: false, icon: Icon(Icons.edit), label: Text('Manual'))],
            selected: {_useOwnMotorcycle},
            onSelectionChanged: widget.loading ? null : (selection) => setState(() => _useOwnMotorcycle = selection.single),
          ),
          const SizedBox(height: 12),
          if (_useOwnMotorcycle)
            DropdownButtonFormField<String>(
              initialValue: _motorcycleId,
              decoration: const InputDecoration(labelText: 'Motocicleta'),
              validator: (value) => value == null ? 'Selecciona una motocicleta.' : null,
              items: widget.motorcycles.map((motorcycle) => DropdownMenuItem(value: motorcycle.id, child: Text('${motorcycle.brand} ${motorcycle.model}'))).toList(),
              onChanged: widget.loading ? null : (value) => setState(() => _motorcycleId = value),
            )
          else ...[
            TextFormField(controller: _brand, maxLength: 100, decoration: const InputDecoration(labelText: 'Marca'), validator: _required),
            TextFormField(controller: _model, maxLength: 100, decoration: const InputDecoration(labelText: 'Modelo'), validator: _required),
            TextFormField(controller: _plate, maxLength: 30, decoration: const InputDecoration(labelText: 'Matrícula (opcional si indicas VIN)')),
            TextFormField(controller: _vin, maxLength: 100, decoration: const InputDecoration(labelText: 'VIN (opcional si indicas matrícula)')),
            TextFormField(controller: _color, maxLength: 50, decoration: const InputDecoration(labelText: 'Color (opcional)')),
          ],
          TextFormField(controller: _location, maxLength: 300, decoration: const InputDecoration(labelText: 'Lugar del robo (opcional)')),
          Card(
            child: ListTile(
              leading: Icon(Icons.map_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(_selectedLocation == null ? 'Selecciona el lugar en el mapa' : 'Ubicación seleccionada'),
              subtitle: _selectedLocation == null ? const Text('Toca el mapa para marcar dónde ocurrió') : Text('${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}'),
              trailing: IconButton(tooltip: 'Abrir mapa', onPressed: widget.loading ? null : _pickLocation, icon: const Icon(Icons.open_in_new_rounded)),
              onTap: widget.loading ? null : _pickLocation,
            ),
          ),
          if (_selectedLocation != null)
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: widget.loading ? null : () => setState(() => _selectedLocation = null), icon: const Icon(Icons.clear), label: const Text('Quitar ubicación'))),
          const SizedBox(height: 20),
          AppButton(label: 'Publicar reporte', loading: widget.loading, onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            if (!_useOwnMotorcycle && _plate.text.trim().isEmpty && _vin.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indica una matrícula o un VIN.')));
              return;
            }
            await widget.onSubmit(CreateTheftReportInput(
              title: _title.text.trim(),
              description: _description.text.trim(),
              theftDate: _theftDate,
              motorcycleId: _useOwnMotorcycle ? _motorcycleId : null,
              brand: _useOwnMotorcycle ? null : _optional(_brand),
              model: _useOwnMotorcycle ? null : _optional(_model),
              licensePlate: _useOwnMotorcycle ? null : _optional(_plate),
              vin: _useOwnMotorcycle ? null : _optional(_vin),
              color: _useOwnMotorcycle ? null : _optional(_color),
              theftLocation: _optional(_location),
              latitude: _selectedLocation?.latitude,
              longitude: _selectedLocation?.longitude,
            ));
          }),
        ]),
      );
}