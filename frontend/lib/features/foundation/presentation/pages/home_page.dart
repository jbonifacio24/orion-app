import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoHub'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthCubit>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bienvenido a MotoHub', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: () => context.pushNamed('profile'), icon: const Icon(Icons.person), label: const Text('Mi perfil')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.pushNamed('motorcycles'), icon: const Icon(Icons.two_wheeler), label: const Text('Mis motocicletas')),
        ]),
      ),
    );
  }
}
