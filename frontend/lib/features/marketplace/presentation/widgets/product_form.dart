import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../../theft/presentation/widgets/theft_location_picker.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({required this.categories, required this.initial, required this.loading, required this.onSubmit, super.key});
  final List<ProductCategory> categories;
  final Product? initial;
  final bool loading;
  final Future<bool> Function({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location, double? latitude, double? longitude, String? paymentMethod}) onSubmit;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  static const _paymentMethods = ['Yape', 'Efectivo', 'Contraentrega'];

  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _price = TextEditingController(text: widget.initial?.price?.toString());
  late final _currency = TextEditingController(text: widget.initial?.currency ?? 'PEN');
  late final _stock = TextEditingController(text: widget.initial?.stockQuantity?.toString());
  LatLng? _selectedLocation;
  late String? _paymentMethod = _normalizePaymentMethod(widget.initial?.paymentMethod);
  late String? _category = widget.initial?.categoryId;
  late ProductCondition _condition = widget.initial?.condition ?? ProductCondition.used;
  final _key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final latitude = widget.initial?.latitude;
    final longitude = widget.initial?.longitude;
    if (latitude != null && longitude != null) {
      _selectedLocation = LatLng(latitude, longitude);
    }
    _price.addListener(_priceChanged);
  }

  void _priceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _price.removeListener(_priceChanged);
    for (final item in [_name, _description, _price, _currency, _stock]) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              validator: (value) => value == null ? 'Selecciona una categoría.' : null,
              items: widget.categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: widget.loading ? null : (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio (opcional)'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final parsed = double.tryParse(text);
                return parsed == null ? 'Precio inválido.' : parsed < 0 ? 'El precio no puede ser negativo.' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
              enabled: _price.text.isNotEmpty,
              validator: (value) => _price.text.trim().isNotEmpty && (value == null || value.trim().length != 3) ? 'Usa una moneda de tres letras.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _stock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock (opcional)'),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final parsed = int.tryParse(text);
                return parsed == null ? 'Stock inválido.' : parsed < 0 ? 'El stock no puede ser negativo.' : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProductCondition>(
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condición'),
              items: const [
                DropdownMenuItem(value: ProductCondition.newProduct, child: Text('Nueva')),
                DropdownMenuItem(value: ProductCondition.used, child: Text('Usada')),
              ],
              onChanged: widget.loading ? null : (value) => setState(() => _condition = value ?? ProductCondition.used),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Modalidad de pago'),
              validator: (value) => value == null ? 'Selecciona una modalidad de pago.' : null,
              items: _paymentMethods.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
              onChanged: widget.loading ? null : (value) => setState(() => _paymentMethod = value),
            ),
            const SizedBox(height: 16),
            _locationSection(context),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: widget.loading ? null : _submit,
              icon: widget.loading ? const AppLoading(compact: true) : const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        ),
      );

  Widget _locationSection(BuildContext context) {
    final selectedLocation = _selectedLocation;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ubicación del producto', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.loading ? null : _selectLocation,
          icon: const Icon(Icons.map_outlined),
          label: Text(selectedLocation == null ? 'Elegir en el mapa' : 'Cambiar ubicación'),
        ),
        if (selectedLocation != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(initialCenter: selectedLocation, initialZoom: 14),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.motohub.app'),
                  MarkerLayer(markers: [
                    Marker(point: selectedLocation, width: 48, height: 52, child: Icon(Icons.location_on, color: colorScheme.primary, size: 44)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _selectLocation() async {
    final selectedLocation = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => TheftLocationPicker(initialLocation: _selectedLocation)),
    );
    if (!mounted || selectedLocation == null) return;
    setState(() => _selectedLocation = selectedLocation);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final price = double.tryParse(_price.text.trim());
    await widget.onSubmit(
      categoryId: _category!,
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: price,
      currency: price == null ? null : _currency.text.trim().toUpperCase(),
      stockQuantity: int.tryParse(_stock.text.trim()),
      condition: _condition,
      location: null,
      latitude: _selectedLocation?.latitude,
      longitude: _selectedLocation?.longitude,
      paymentMethod: _paymentMethod,
    );
  }

  String? _normalizePaymentMethod(String? paymentMethod) {
    switch (paymentMethod?.trim().toLowerCase()) {
      case 'yape':
        return 'Yape';
      case 'efectivo':
        return 'Efectivo';
      case 'contraentrega':
      case 'contra entrega':
        return 'Contraentrega';
      default:
        return null;
    }
  }
}
