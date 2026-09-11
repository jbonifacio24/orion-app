import 'package:flutter/material.dart';

import 'app_loading.dart';

class AppButton extends StatelessWidget {
  const AppButton({required this.label, required this.onPressed, this.loading = false, super.key});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          child: loading ? const AppLoading(compact: true) : Text(label),
        ),
      );
}