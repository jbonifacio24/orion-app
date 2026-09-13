import 'package:flutter/material.dart';

import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/user_profile.dart';

class ProfileForm extends StatefulWidget {
  const ProfileForm({required this.profile, required this.loading, required this.onSubmit, super.key});
  final UserProfile profile;
  final bool loading;
  final void Function(String? firstName, String? lastName, String? phoneNumber, String? bio) onSubmit;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _firstName = TextEditingController(text: widget.profile.firstName);
  late final _lastName = TextEditingController(text: widget.profile.lastName);
  late final _phone = TextEditingController(text: widget.profile.phoneNumber);
  late final _bio = TextEditingController(text: widget.profile.bio);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _phone.dispose(); _bio.dispose(); super.dispose();
  }

  String? _max(String? value, int length) => value != null && value.length > length ? 'Máximo $length caracteres.' : null;

  @override
  Widget build(BuildContext context) => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(controller: _firstName, maxLength: 100, decoration: const InputDecoration(labelText: 'Nombre'), validator: (value) => _max(value, 100)),
            TextFormField(controller: _lastName, maxLength: 100, decoration: const InputDecoration(labelText: 'Apellidos'), validator: (value) => _max(value, 100)),
            TextFormField(controller: _phone, maxLength: 30, decoration: const InputDecoration(labelText: 'Teléfono'), validator: (value) => _max(value, 30)),
            TextFormField(controller: _bio, maxLength: 2000, maxLines: 4, decoration: const InputDecoration(labelText: 'Biografía'), validator: (value) => _max(value, 2000)),
            const SizedBox(height: 12),
            AppButton(label: 'Guardar', loading: widget.loading, onPressed: () {
              if (_formKey.currentState!.validate()) widget.onSubmit(_firstName.text.trim(), _lastName.text.trim(), _phone.text.trim(), _bio.text.trim());
            }),
          ],
        ),
      );
}
