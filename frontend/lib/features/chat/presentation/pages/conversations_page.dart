import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../cubit/conversations_cubit.dart';
import '../widgets/conversation_tile.dart';

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<ConversationsCubit>().state.items.isEmpty) context.read<ConversationsCubit>().load();
    });
  }

  Future<void> _createDirect(BuildContext context) async {
    final controller = TextEditingController();
    final recipientId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppLocalizations.newConversation),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: AppLocalizations.recipientUserId)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(AppLocalizations.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text(AppLocalizations.open)),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || recipientId == null) return;
    final conversation = await context.read<ConversationsCubit>().getOrCreateDirect(recipientId);
    if (context.mounted && conversation != null) context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversation.id});
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConversationsCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppLocalizations.conversations),
        actions: [
          IconButton(tooltip: AppLocalizations.newConversation, onPressed: state.isCreating ? null : () => _createDirect(context), icon: const Icon(Icons.person_add_alt_1)),
        ],
      ),
      body: Column(
        children: [
          if (state.actionFailure != null) _ActionFailure(message: state.actionFailure!),
          Expanded(child: _content(context, state)),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, ConversationsState state) {
    if (state.isInitialLoading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.failure != null && state.items.isEmpty) return _Failure(message: state.failure!, onRetry: context.read<ConversationsCubit>().load);
    if (state.items.isEmpty) return const Center(child: Text(AppLocalizations.noConversations));
    return RefreshIndicator(
      onRefresh: context.read<ConversationsCubit>().refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = state.items[index];
          return ConversationTile(conversation: item, onTap: () => context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': item.id}));
        },
      ),
    );
  }
}

class _ActionFailure extends StatelessWidget {
  const _ActionFailure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(message), actions: [TextButton(onPressed: context.read<ConversationsCubit>().clearActionFailure, child: const Text(AppLocalizations.dismiss))]);
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry))])));
}
