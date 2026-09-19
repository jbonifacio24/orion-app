import 'package:flutter/material.dart';

class PriceLabel extends StatelessWidget {
  const PriceLabel({required this.price, this.currency, super.key});
  final double? price;
  final String? currency;

  @override
  Widget build(BuildContext context) => Text(price == null ? 'Negociable' : '${currency ?? 'PEN'} ${price!.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
}
