import 'package:flutter/material.dart';

class AppLoading extends StatelessWidget {
  const AppLoading({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: compact ? 18 : null,
        height: compact ? 18 : null,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
