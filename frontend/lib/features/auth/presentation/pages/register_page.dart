import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../cubit/auth_cubit.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _email = TextEditingController();
  final _userName = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _userName.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Correo electrónico')),
                const SizedBox(height: 12),
                TextField(controller: _userName, decoration: const InputDecoration(labelText: 'Usuario')),
                const SizedBox(height: 12),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña')),
                const SizedBox(height: 12),
                TextField(controller: _confirmPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Repetir contraseña')),
                if (state case AuthFailure(:final message)) ...[
                  const SizedBox(height: 12),
                  AppErrorState(message: message),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: 'Registrarme',
                  loading: state is AuthLoading,
                  onPressed: () => context.read<AuthCubit>().register(
                        email: _email.text.trim(),
                        userName: _userName.text.trim(),
                        password: _password.text,
                        confirmPassword: _confirmPassword.text,
                      ),
                ),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Ya tengo una cuenta')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
