import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge.dart';
import '../../../chat/presentation/cubit/conversations_cubit.dart';

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
      if (mounted) {
        context.read<NotificationsCubit>().loadUnreadCount();
        context.read<ConversationsCubit>().load();
      }
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
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(color: Theme.of(context).appBarTheme.backgroundColor),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvgPicture.asset('assets/images/motohub_logo.svg', width: 250, height: 78),
                ),
              ),
              SwitchListTile(
                secondary: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                title: const Text('Modo oscuro'),
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (enabled) => AppTheme.setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light),
              ),
              BlocBuilder<ConversationsCubit, ConversationsState>(
                builder: (context, state) => IconButton(
                  tooltip: AppLocalizations.conversations,
                  onPressed: () => context.pushNamed(RouteNames.conversations),
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      NotificationBadge(count: state.unreadCount),
                    ],
                  ),
                ),
              ),
              const _MenuItem(icon: Icons.person, label: 'Mi perfil', routeName: 'profile'),
              const _MenuItem(icon: Icons.two_wheeler, label: 'Mis motocicletas', routeName: 'motorcycles'),
              const _MenuItem(icon: Icons.storefront, label: 'Marketplace', routeName: 'marketplace'),
              const _MenuItem(icon: Icons.delivery_dining_outlined, label: 'Delivery', routeName: 'delivery'),
              const _MenuItem(icon: Icons.route_outlined, label: 'Rutas de viaje', routeName: RouteNames.travelRoutes),
              const _MenuItem(icon: Icons.build_circle_outlined, label: AppLocalizations.workshops, routeName: 'workshops'),
              _MenuItem(icon: Icons.forum_outlined, label: AppLocalizations.communityTitle(Localizations.localeOf(context)), routeName: 'community'),
              _MenuItem(icon: Icons.article_outlined, label: AppLocalizations.newsTitle(Localizations.localeOf(context)), routeName: RouteNames.news),
              const _MenuItem(icon: Icons.warning_amber_rounded, label: 'Reportes de robo', routeName: 'theft-reports'),
              const _MenuItem(icon: Icons.inventory_2_outlined, label: 'Mis productos', routeName: 'my-products'),
              const _MenuItem(icon: Icons.favorite_border, label: 'Favoritos', routeName: 'favorites'),
              const _MenuItem(icon: Icons.notifications_outlined, label: AppLocalizations.notifications, routeName: RouteNames.notifications),
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
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 20 : 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: _GarageHero(compact: compact),
            ),
          );
        }),
      ),
    );
  }
}

class _GarageHero extends StatefulWidget {
  const _GarageHero({required this.compact});

  final bool compact;

  @override
  State<_GarageHero> createState() => _GarageHeroState();
}

class _GarageHeroState extends State<_GarageHero> {
  static const _clips = [
    (asset: 'assets/videos/forest_ride.mp4', title: 'Ruta por el bosque'),
    (asset: 'assets/videos/countryside_ride.mp4', title: 'Camino de campo'),
    (asset: 'assets/videos/road_trip.mp4', title: 'Viaje por carretera'),
  ];

  VideoPlayerController? _controller;
  Timer? _clipTimer;
  int _currentClip = 0;
  int _loadVersion = 0;
  bool _videoFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClip(_currentClip));
  }

  Future<void> _loadClip(int index) async {
    final loadVersion = ++_loadVersion;
    _clipTimer?.cancel();
    final previousController = _controller;
    final controller = VideoPlayerController.asset(_clips[index].asset);
    _controller = controller;
    _videoFailed = false;
    if (mounted) setState(() {});
    await previousController?.dispose();

    try {
      await controller.initialize();
      if (!mounted || loadVersion != _loadVersion) return;
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() {});
    } catch (_) {
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() => _videoFailed = true);
    }

    if (!mounted || loadVersion != _loadVersion) return;
    _clipTimer = Timer(const Duration(seconds: 4), () {
      _showClip((index + 1) % _clips.length);
    });
  }

  void _showClip(int index) {
    setState(() => _currentClip = index);
    unawaited(_loadClip(index));
  }

  @override
  void dispose() {
    _loadVersion++;
    _clipTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildVideo() {
    final controller = _controller;
    if (_videoFailed || controller == null || !controller.value.isInitialized) {
      return Image.network(
        'https://images.unsplash.com/photo-1558981806-ec527fa84c39?auto=format&fit=crop&w=1600&q=85',
        fit: BoxFit.cover,
        alignment: widget.compact ? Alignment.center : Alignment.centerRight,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Color(0xFF39221B),
          child: Icon(Icons.two_wheeler_rounded, size: 180, color: Color(0x55FFFFFF)),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF211715),
          boxShadow: const [BoxShadow(color: Color(0x33201614), blurRadius: 20, offset: Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: widget.compact ? 430 : 560,
          child: Stack(children: [
              Positioned.fill(child: _buildVideo()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xF2211715), const Color(0x991F1715), const Color(0x221F1715)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: widget.compact ? const [0, 0.58, 1] : const [0, 0.44, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(widget.compact ? 28 : 56),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('BIENVENIDO A', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFFFF9E7D), fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('MotoHub', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text('El punto de encuentro para quienes viven sobre dos ruedas.', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, height: 1.25))),
                    const SizedBox(height: 18),
                    Container(width: 56, height: 4, decoration: BoxDecoration(color: const Color(0xFFFF9E7D), borderRadius: BorderRadius.circular(4))),
                  ]),
                ),
              ),
              Positioned(
                left: widget.compact ? 16 : 32,
                right: widget.compact ? 16 : 32,
                bottom: widget.compact ? 14 : 24,
                child: Row(
                  children: [
                    IconButton.filled(
                      tooltip: 'Video anterior',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.42),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showClip((_currentClip - 1 + _clips.length) % _clips.length),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_clips.length, (index) => IconButton(
                              tooltip: '${_clips[index].title}, ${index + 1} de ${_clips.length}',
                              onPressed: () => _showClip(index),
                              constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                              icon: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: _currentClip == index ? 22 : 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: _currentClip == index ? 1 : 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            )),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Video siguiente',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.42),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showClip((_currentClip + 1) % _clips.length),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
          ]),
        ),
      );
}

class _MenuItem extends StatefulWidget {
  const _MenuItem({required this.icon, required this.label, required this.routeName});

  final IconData icon;
  final String label;
  final String routeName;

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _hovered ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: ListTile(
            hoverColor: Colors.transparent,
            leading: AnimatedSlide(
            offset: _hovered ? const Offset(0.12, 0) : Offset.zero,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: _hovered ? 1.12 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(widget.icon, color: _hovered ? colorScheme.primary : null),
            ),
          ),
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: _hovered ? colorScheme.primary : colorScheme.onSurface,
                  fontWeight: _hovered ? FontWeight.w600 : FontWeight.normal,
                ),
              child: Text(widget.label),
            ),
            onTap: () {
              Navigator.pop(context);
              context.pushNamed(widget.routeName);
            },
          ),
        ),
      ),
    );
  }
}
