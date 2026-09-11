import 'package:flutter/material.dart';

import '../../../../core/widgets/app_loading.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: AppLoading()),
      );
}
