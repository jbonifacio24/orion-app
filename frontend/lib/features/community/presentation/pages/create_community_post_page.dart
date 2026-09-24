import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../cubit/community_feed_cubit.dart';
import '../cubit/community_feed_state.dart';

class CreateCommunityPostPage extends StatefulWidget {
  const CreateCommunityPostPage({super.key});

  @override
  State<CreateCommunityPostPage> createState() => _CreateCommunityPostPageState();
}

class _CreateCommunityPostPageState extends State<CreateCommunityPostPage> {
  static const maxContentLength = CommunityFeedCubit.maxContentLength;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onTextChanged);
    _focusNode = FocusNode();
  }

  void _onTextChanged() => setState(() {});

  Future<void> _submit() async {
    final post = await context.read<CommunityFeedCubit>().createPost(_controller.text);
    if (mounted && post != null) Navigator.of(context).pop(post);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return BlocBuilder<CommunityFeedCubit, CommunityFeedState>(
      builder: (context, state) {
        final canSubmit = _controller.text.trim().isNotEmpty && _controller.text.length <= maxContentLength && !state.isSubmitting;
        return Scaffold(
          appBar: AppBar(title: Text(AppLocalizations.communityCreate(locale))),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    minLines: 6,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.communityContentHint(locale),
                      alignLabelWithHint: true,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(AppLocalizations.communityCharacterCount(locale, _controller.text.length, maxContentLength)),
                  ),
                  if (state.operationFailure != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.operationFailure!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: canSubmit ? _submit : null,
                    icon: state.isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined),
                    label: Text(AppLocalizations.communityPublish(locale)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
