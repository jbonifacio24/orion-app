import 'package:flutter/material.dart';

class AppErrorState extends StatelessWidget {
  const AppErrorState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
}