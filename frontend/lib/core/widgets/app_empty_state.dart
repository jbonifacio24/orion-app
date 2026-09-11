import 'package:flutter/material.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}