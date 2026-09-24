import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/chat_entities.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/conversations_cubit.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final TextEditingController _composer;
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _scroll = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAndMarkRead();
    });
  }

  Future<void> _loadAndMarkRead() async {
    final cubit = context.read<ChatCubit>();
    await cubit.load(widget.conversationId);
    if (!mounted || cubit.state.conversationId != widget.conversationId) return;
    if (await cubit.markRead() && mounted) {
      context.read<ConversationsCubit>().markConversationReadLocally(widget.conversationId);
    }
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.pixels <= 120) context.read<ChatCubit>().loadOlder();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final cubit = context.read<ChatCubit>();
    final sent = await cubit.send(_composer.text);
    if (sent && mounted) {
      _composer.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChatCubit>().state;
    final authState = context.watch<AuthCubit>().state;
    final conversation = _conversationSummary(context);
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : '';
    return Scaffold(
      appBar: AppBar(title: Text(conversation?.participant.displayName.isNotEmpty == true ? conversation!.participant.displayName : AppLocalizations.chat)),
      body: Column(
        children: [
          if (state.actionFailure != null) _ActionFailure(message: state.actionFailure!),
          Expanded(child: _content(context, state, currentUserId)),
          _composerBar(context, state),
        ],
      ),
    );
  }

  Conversation? _conversationSummary(BuildContext context) {
    for (final item in context.read<ConversationsCubit>().state.items) {
      if (item.id == widget.conversationId) return item;
    }
    return null;
  }

  Widget _content(BuildContext context, ChatState state, String currentUserId) {
    if (state.isInitialLoading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (state.failure != null && state.items.isEmpty) return _Failure(message: state.failure!, onRetry: () => context.read<ChatCubit>().load(widget.conversationId));
    if (state.items.isEmpty) return const Center(child: Text(AppLocalizations.noMessages));
    return RefreshIndicator(
      onRefresh: context.read<ChatCubit>().refresh,
      child: ListView.builder(
        controller: _scroll,
        reverse: false,
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (state.isLoadingMore && index == 0) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
          final messageIndex = state.isLoadingMore ? index - 1 : index;
          final message = state.items[messageIndex];
          return MessageBubble(message: message, isMine: message.senderUserId == currentUserId);
        },
      ),
    );
  }

  Widget _composerBar(BuildContext context, ChatState state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 10000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: AppLocalizations.writeMessage, counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: AppLocalizations.send,
                onPressed: state.isSending || _composer.text.trim().isEmpty || _composer.text.trim().length > 10000 ? null : _send,
                icon: state.isSending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      );
}

class _ActionFailure extends StatelessWidget {
  const _ActionFailure({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(message), actions: [TextButton(onPressed: context.read<ChatCubit>().clearActionFailure, child: const Text(AppLocalizations.dismiss))]);
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry))])));
}
