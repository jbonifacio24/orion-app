import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/profile_cubit.dart';
import '../widgets/profile_form.dart';

class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final profile = state is ProfileLoaded
              ? state.profile
              : state is ProfileUpdating
                  ? state.profile
                  : state is ProfileFailure
                      ? state.profile
                      : null;
          if (state is ProfileInitial || state is ProfileLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            final message = state is ProfileFailure ? state.message : 'Perfil no disponible.';
            return Center(child: Text(message));
          }
          final cubit = context.read<ProfileCubit>();
          return ListView(padding: const EdgeInsets.all(24), children: [
            if (state is ProfileFailure) ...[
              Text(state.message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
            ],
            Text('Los datos de cuenta son de solo lectura.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ProfileForm(
              profile: profile,
              loading: state is ProfileUpdating,
              onSubmit: (firstName, lastName, phone, bio) async {
                await cubit.updateProfile(firstName: firstName, lastName: lastName, phoneNumber: phone, bio: bio);
                if (context.mounted && cubit.state is ProfileLoaded) Navigator.of(context).pop();
              },
            ),
          ]);
        },
      ),
    );
  }
}
