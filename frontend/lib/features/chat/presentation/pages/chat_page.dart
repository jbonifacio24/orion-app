import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_realtime_repository.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/conversations_cubit.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/message_bubble.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.conversationId, super.key});

  final String conversationId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const _maxAudioBytes = 14 * 1024 * 1024;

  late final TextEditingController _composer;
  late final ScrollController _scroll;
  late final AudioRecorder _audioRecorder;
  final ImagePicker _imagePicker = ImagePicker();
  BytesBuilder _recordedAudio = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _audioSubscription;
  Completer<void>? _audioStreamDone;
  Timer? _recordingTimer;
  Duration _recordingElapsed = Duration.zero;
  bool _isRecording = false;
  bool _isFinishingRecording = false;

  bool get _supportsCameraCapture => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _composer = TextEditingController();
    _scroll = ScrollController()..addListener(_onScroll);
    _audioRecorder = AudioRecorder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadAndMarkRead();
    });
  }

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId == widget.conversationId) return;
    _composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _loadAndMarkRead();
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
    _recordingTimer?.cancel();
    _audioSubscription?.cancel();
    unawaited(_disposeAudioRecorder());
    super.dispose();
  }

  Future<void> _disposeAudioRecorder() async {
    try {
      if (await _audioRecorder.isRecording()) await _audioRecorder.cancel();
    } catch (_) {}
    await _audioRecorder.dispose();
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
      appBar: AppBar(title: Text(conversation?.title ?? (conversation?.participant.displayName.isNotEmpty == true ? conversation!.participant.displayName : AppLocalizations.chat))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final chat = Column(
            children: [
              if (state.actionFailure != null) _ActionFailure(message: state.actionFailure!),
              _RealtimeIndicator(state.realtimeState),
              Expanded(child: _content(context, state, currentUserId)),
              _composerBar(context, state),
            ],
          );
          if (constraints.maxWidth < 760) return chat;
          return Row(
            children: [
              SizedBox(width: 280, child: _conversationSidebar(context)),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: chat),
            ],
          );
        },
      ),
    );
  }

  Widget _conversationSidebar(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(child: Text(AppLocalizations.conversations, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(tooltip: AppLocalizations.retry, onPressed: context.read<ConversationsCubit>().refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<ConversationsCubit, ConversationsState>(
              builder: (context, state) {
                if (state.isInitialLoading && state.items.isEmpty) return const AppLoading();
                if (state.failure != null && state.items.isEmpty) {
                  return Center(
                    child: TextButton.icon(onPressed: context.read<ConversationsCubit>().load, icon: const Icon(Icons.refresh), label: const Text(AppLocalizations.retry)),
                  );
                }
                if (state.items.isEmpty) return const Center(child: Text(AppLocalizations.noConversations));
                return ListView.separated(
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    return ConversationTile(
                      conversation: item,
                      selected: item.id == widget.conversationId,
                      onTap: () => context.goNamed(RouteNames.chat, pathParameters: {'conversationId': item.id}),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );

  Conversation? _conversationSummary(BuildContext context) {
    for (final item in context.read<ConversationsCubit>().state.items) {
      if (item.id == widget.conversationId) return item;
    }
    return null;
  }

  Widget _content(BuildContext context, ChatState state, String currentUserId) {
    if (state.isInitialLoading && state.items.isEmpty) return const AppLoading();
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
          if (state.isLoadingMore && index == 0) return const Padding(padding: EdgeInsets.all(12), child: AppLoading(compact: true));
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
              IconButton(
                tooltip: 'Adjuntar archivo',
                onPressed: state.isSending ? null : _pickAttachment,
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                tooltip: _supportsCameraCapture ? 'Tomar foto' : 'Elegir imagen para enviar',
                onPressed: state.isSending || _isRecording ? null : _captureImage,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 10000,
                  readOnly: _isRecording,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: _isRecording ? 'Grabando nota de voz · ${_recordingTime()}' : AppLocalizations.writeMessage, counterText: ''),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _isRecording ? 'Detener y enviar audio' : 'Grabar audio',
                onPressed: state.isSending ? null : _toggleRecording,
                color: _isRecording ? Theme.of(context).colorScheme.error : null,
                icon: Icon(_isRecording ? Icons.stop_circle_outlined : Icons.mic_none),
              ),
              IconButton.filled(
                tooltip: AppLocalizations.send,
                onPressed: state.isSending || _isRecording || _composer.text.trim().isEmpty || _composer.text.trim().length > 10000 ? null : _send,
                icon: state.isSending ? const AppLoading(compact: true) : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      );

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp3', 'ogg', 'wav', 'webm'], withData: true);
    if (!mounted || result == null || result.files.isEmpty) return;
    await context.read<ChatCubit>().sendAttachment(result.files.single);
  }

  Future<void> _captureImage() async {
    try {
      if (_supportsCameraCapture) {
        final photo = await _imagePicker.pickImage(source: ImageSource.camera, maxWidth: 1920, maxHeight: 1920, imageQuality: 85);
        if (photo == null || !mounted) return;
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        final name = photo.name.contains('.') ? photo.name : 'foto.jpg';
        await context.read<ChatCubit>().sendAttachment(PlatformFile(name: name, size: bytes.length, bytes: bytes));
        return;
      }

      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null || result.files.isEmpty || !mounted) return;
      await context.read<ChatCubit>().sendAttachment(result.files.single);
    } catch (error) {
      if (mounted) _showMessage('No se pudo abrir la cámara o seleccionar la imagen.');
    }
  }

  Future<void> _toggleRecording() => _isRecording ? _finishRecording() : _startRecording();

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) _showMessage('Permite el acceso al micrófono para grabar audio.');
        return;
      }
      _recordedAudio = BytesBuilder(copy: false);
      _audioStreamDone = Completer<void>();
      final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      _audioSubscription = stream.listen(
        _onAudioChunk,
        onError: (Object error) {
          if (!(_audioStreamDone?.isCompleted ?? true)) _audioStreamDone!.complete();
        },
        onDone: () {
          if (!(_audioStreamDone?.isCompleted ?? true)) _audioStreamDone!.complete();
        },
      );
      if (!mounted) {
        await _audioRecorder.cancel();
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingElapsed = Duration.zero;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingElapsed += const Duration(seconds: 1));
      });
    } catch (_) {
      if (mounted) _showMessage('No se pudo iniciar la grabación de audio.');
    }
  }

  void _onAudioChunk(Uint8List chunk) {
    if (!_isRecording || _isFinishingRecording) return;
    if (_recordedAudio.length + chunk.length > _maxAudioBytes) {
      unawaited(_finishRecording(send: false, reachedSizeLimit: true));
      return;
    }
    _recordedAudio.add(chunk);
  }

  Future<void> _finishRecording({bool send = true, bool reachedSizeLimit = false}) async {
    if (!_isRecording || _isFinishingRecording) return;
    _isFinishingRecording = true;
    _recordingTimer?.cancel();
    try {
      await _audioRecorder.stop();
      await _audioStreamDone?.future.timeout(const Duration(seconds: 2));
    } catch (_) {}
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    final pcm = _recordedAudio.takeBytes();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isFinishingRecording = false;
      });
    } else {
      _isRecording = false;
      _isFinishingRecording = false;
    }
    if (reachedSizeLimit) {
      if (mounted) _showMessage('La nota de voz alcanzó el límite de tamaño.');
      return;
    }
    if (!send) return;
    if (pcm.isEmpty) {
      if (mounted) _showMessage('No se grabó audio.');
      return;
    }
    final wav = _wrapPcmAsWav(pcm);
    if (!mounted) return;
    await context.read<ChatCubit>().sendAttachment(PlatformFile(name: 'nota-de-voz.wav', size: wav.length, bytes: wav));
  }

  Uint8List _wrapPcmAsWav(Uint8List pcm) {
    const sampleRate = 16000;
    const channels = 1;
    const bitsPerSample = 16;
    final header = ByteData(44);
    const bytesPerSecond = sampleRate * channels * bitsPerSample ~/ 8;
    header.setUint32(0, 0x46464952, Endian.little);
    header.setUint32(4, 36 + pcm.length, Endian.little);
    header.setUint32(8, 0x45564157, Endian.little);
    header.setUint32(12, 0x20746d66, Endian.little);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, bytesPerSecond, Endian.little);
    header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint32(36, 0x61746164, Endian.little);
    header.setUint32(40, pcm.length, Endian.little);
    return (BytesBuilder(copy: false)..add(header.buffer.asUint8List())..add(pcm)).takeBytes();
  }

  String _recordingTime() {
    final minutes = _recordingElapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (_recordingElapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _RealtimeIndicator extends StatelessWidget {
  const _RealtimeIndicator(this.state);

  final ChatRealtimeConnectionState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      ChatRealtimeConnectionState.connecting => AppLocalizations.chatConnecting,
      ChatRealtimeConnectionState.reconnecting => AppLocalizations.chatReconnecting,
      ChatRealtimeConnectionState.disconnected || ChatRealtimeConnectionState.failed => AppLocalizations.chatOffline,
      ChatRealtimeConnectionState.connected => null,
    };
    if (label == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
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
