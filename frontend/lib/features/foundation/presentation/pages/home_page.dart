import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsCubit>().loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MotoHub'),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) => IconButton(
              tooltip: AppLocalizations.notifications,
              onPressed: () => context.pushNamed(RouteNames.notifications),
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_outlined),
                NotificationBadge(count: state.unreadCount),
              ]),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Color(0xFFFFB197)),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('MotoHub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
              ),
          IconButton(
            tooltip: AppLocalizations.conversations,
            onPressed: () => context.pushNamed(RouteNames.conversations),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
              const _MenuItem(icon: Icons.person, label: 'Mi perfil', routeName: 'profile'),
              const _MenuItem(icon: Icons.two_wheeler, label: 'Mis motocicletas', routeName: 'motorcycles'),
              const _MenuItem(icon: Icons.storefront, label: 'Marketplace', routeName: 'marketplace'),
              const _MenuItem(icon: Icons.build_circle_outlined, label: AppLocalizations.workshops, routeName: 'workshops'),
              const _MenuItem(icon: Icons.warning_amber_rounded, label: 'Reportes de robo', routeName: 'theft-reports'),
              const _MenuItem(icon: Icons.inventory_2_outlined, label: 'Mis productos', routeName: 'my-products'),
              const _MenuItem(icon: Icons.favorite_border, label: 'Favoritos', routeName: 'favorites'),
              const _MenuItem(icon: Icons.notifications_outlined, label: AppLocalizations.notifications, routeName: RouteNames.notifications),
              const _MenuItem(icon: Icons.chat_bubble_outline, label: AppLocalizations.conversations, routeName: RouteNames.conversations),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () {
                  Navigator.pop(context);
                  context.read<AuthCubit>().logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bienvenido a MotoHub', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: () => context.pushNamed('profile'), icon: const Icon(Icons.person), label: const Text('Mi perfil')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.pushNamed('motorcycles'), icon: const Icon(Icons.two_wheeler), label: const Text('Mis motocicletas')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.pushNamed('marketplace'), icon: const Icon(Icons.storefront), label: const Text('Marketplace')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.pushNamed('workshops'), icon: const Icon(Icons.build_circle_outlined), label: const Text(AppLocalizations.workshops)),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () => context.pushNamed('theft-reports'), icon: const Icon(Icons.warning_amber_rounded), label: const Text('Reportes de robo')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => context.pushNamed('my-products'), icon: const Icon(Icons.inventory_2_outlined), label: const Text('Mis productos')),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => context.pushNamed('favorites'), icon: const Icon(Icons.favorite_border), label: const Text('Favoritos')),
        ]),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.routeName});

  final IconData icon;
  final String label;
  final String routeName;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          Navigator.pop(context);
          context.pushNamed(routeName);
        },
      );
}
