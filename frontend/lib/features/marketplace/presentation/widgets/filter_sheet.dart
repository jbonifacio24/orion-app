import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_filters.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({required this.initial, required this.categories, required this.onApply, super.key});
  final ProductFilters initial;
  final List<ProductCategory> categories;
  final ValueChanged<ProductFilters> onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ProductFilters filters = widget.initial;
  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: filters.categoryId, decoration: const InputDecoration(labelText: 'Categoría'), items: [const DropdownMenuItem(value: null, child: Text('Todas')), ...widget.categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))], onChanged: (value) => setState(() => filters = value == null ? filters.copyWith(clearCategory: true) : filters.copyWith(categoryId: value))),
        DropdownButtonFormField<ProductCondition>(initialValue: filters.condition, decoration: const InputDecoration(labelText: 'Condición'), items: const [DropdownMenuItem(value: null, child: Text('Todas')), DropdownMenuItem(value: ProductCondition.newProduct, child: Text('Nueva')), DropdownMenuItem(value: ProductCondition.used, child: Text('Usada'))], onChanged: (value) => setState(() => filters = value == null ? filters.copyWith(clearCondition: true) : filters.copyWith(condition: value))),
        DropdownButtonFormField<String>(initialValue: filters.sort, decoration: const InputDecoration(labelText: 'Ordenar'), items: const [DropdownMenuItem(value: 'newest', child: Text('Más recientes')), DropdownMenuItem(value: 'oldest', child: Text('Más antiguas')), DropdownMenuItem(value: 'priceAsc', child: Text('Precio menor')), DropdownMenuItem(value: 'priceDesc', child: Text('Precio mayor')), DropdownMenuItem(value: 'name', child: Text('Nombre'))], onChanged: (value) => setState(() => filters = filters.copyWith(sort: value))),
        const SizedBox(height: 16),
        FilledButton(onPressed: () { widget.onApply(filters); Navigator.pop(context); }, child: const Text('Aplicar filtros')),
      ])));
}
