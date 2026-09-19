import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({required this.categories, required this.initial, required this.loading, required this.onSubmit, super.key});
  final List<ProductCategory> categories;
  final Product? initial;
  final bool loading;
  final Future<bool> Function({required String categoryId, required String name, required String description, double? price, String? currency, int? stockQuantity, required ProductCondition condition, String? location}) onSubmit;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _price = TextEditingController(text: widget.initial?.price?.toString());
  late final _currency = TextEditingController(text: widget.initial?.currency ?? 'PEN');
  late final _stock = TextEditingController(text: widget.initial?.stockQuantity?.toString());
  late final _location = TextEditingController(text: widget.initial?.location);
  late String? _category = widget.initial?.categoryId;
  late ProductCondition _condition = widget.initial?.condition ?? ProductCondition.used;
  final _key = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _price.addListener(_priceChanged);
  }

  void _priceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() { _price.removeListener(_priceChanged); for (final item in [_name, _description, _price, _currency, _stock, _location]) { item.dispose(); } super.dispose(); }

  @override
  Widget build(BuildContext context) => Form(key: _key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Categoría'), validator: (value) => value == null ? 'Selecciona una categoría.' : null, items: widget.categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(), onChanged: widget.loading ? null : (value) => setState(() => _category = value)),
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Título'), validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null),
        TextFormField(controller: _description, maxLines: 4, decoration: const InputDecoration(labelText: 'Descripción'), validator: (value) => value == null || value.trim().isEmpty ? 'Campo requerido.' : null),
        TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (opcional)'), validator: (value) { final text = value?.trim() ?? ''; if (text.isEmpty) return null; final parsed = double.tryParse(text); return parsed == null ? 'Precio inválido.' : parsed < 0 ? 'El precio no puede ser negativo.' : null; }),
        TextFormField(controller: _currency, decoration: const InputDecoration(labelText: 'Moneda'), enabled: _price.text.isNotEmpty, validator: (value) => _price.text.trim().isNotEmpty && (value == null || value.trim().length != 3) ? 'Usa una moneda de tres letras.' : null),
        TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock (opcional)'), validator: (value) { final text = value?.trim() ?? ''; if (text.isEmpty) return null; final parsed = int.tryParse(text); return parsed == null ? 'Stock inválido.' : parsed < 0 ? 'El stock no puede ser negativo.' : null; }),
        DropdownButtonFormField<ProductCondition>(initialValue: _condition, decoration: const InputDecoration(labelText: 'Condición'), items: const [DropdownMenuItem(value: ProductCondition.newProduct, child: Text('Nueva')), DropdownMenuItem(value: ProductCondition.used, child: Text('Usada'))], onChanged: widget.loading ? null : (value) => setState(() => _condition = value ?? ProductCondition.used)),
        TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Ubicación')),
        const SizedBox(height: 20),
        FilledButton.icon(onPressed: widget.loading ? null : () async { if (!_key.currentState!.validate()) return; final price = double.tryParse(_price.text.trim()); await widget.onSubmit(categoryId: _category!, name: _name.text.trim(), description: _description.text.trim(), price: price, currency: price == null ? null : _currency.text.trim().toUpperCase(), stockQuantity: int.tryParse(_stock.text.trim()), condition: _condition, location: _location.text.trim()); }, icon: widget.loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: const Text('Guardar')),
      ]));
}
