import 'package:flutter/material.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({required this.selected, required this.loading, required this.onPressed, super.key});
  final bool selected;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(tooltip: selected ? 'Quitar de favoritos' : 'Añadir a favoritos', onPressed: loading ? null : onPressed, icon: loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(selected ? Icons.favorite : Icons.favorite_border));
}
