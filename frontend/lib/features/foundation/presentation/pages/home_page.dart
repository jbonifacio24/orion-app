import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MotoHub')),
      body: Center(
        child: Text(
          'Bienvenido a MotoHub',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
