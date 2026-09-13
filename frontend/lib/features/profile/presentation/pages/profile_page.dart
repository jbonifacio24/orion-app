import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/router/route_names.dart';
import '../cubit/profile_cubit.dart';
import '../widgets/profile_header.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() { super.initState(); context.read<ProfileCubit>().loadProfile(); }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProfileCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: switch (state) {
        ProfileInitial() || ProfileLoading() => const AppLoading(),
        ProfileFailure(:final message) => AppErrorState(message: message),
        ProfileLoaded(:final profile) || ProfileUpdating(:final profile) => RefreshIndicator(
            onRefresh: context.read<ProfileCubit>().loadProfile,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              ProfileHeader(profile: profile),
              const SizedBox(height: 24),
              ListTile(title: const Text('Correo'), subtitle: Text(profile.email), leading: const Icon(Icons.email_outlined)),
              ListTile(title: const Text('Teléfono'), subtitle: Text(profile.phoneNumber?.isNotEmpty == true ? profile.phoneNumber! : 'No indicado'), leading: const Icon(Icons.phone_outlined)),
              ListTile(title: const Text('Biografía'), subtitle: Text(profile.bio?.isNotEmpty == true ? profile.bio! : 'No indicada'), leading: const Icon(Icons.notes_outlined)),
              ListTile(title: const Text('Correo confirmado'), subtitle: Text(profile.emailConfirmed ? 'Sí' : 'No'), leading: Icon(profile.emailConfirmed ? Icons.verified : Icons.info_outline)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: () => context.pushNamed(RouteNames.profileEdit, extra: profile), icon: const Icon(Icons.edit), label: const Text('Editar perfil')),
            ]),
          ),
      },
    );
  }
}
