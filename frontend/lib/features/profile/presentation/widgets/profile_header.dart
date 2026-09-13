import 'package:flutter/material.dart';

import '../../domain/entities/user_profile.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.profile, super.key});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = [profile.firstName, profile.lastName].whereType<String>().where((value) => value.isNotEmpty).join(' ');
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          child: profile.profileImageUrl?.trim().isNotEmpty == true
              ? ClipOval(
                  child: Image.network(
                    profile.profileImageUrl!,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 42),
                  ),
                )
              : const Icon(Icons.person, size: 42),
        ),
        const SizedBox(height: 12),
        Text(name.isEmpty ? profile.userName : name, style: Theme.of(context).textTheme.headlineSmall),
        Text('@${profile.userName}'),
      ],
    );
  }
}
