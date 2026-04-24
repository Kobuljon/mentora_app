import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;

import '../models/chat_message.dart';
import '../providers/ai_chat_provider.dart';

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax() : super(r'\$\$([^$]+?)\$\$|\$([^$]+?)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final isBlock = match[1] != null;
    final content = (match[1] ?? match[2]!).trim();
    final el = md.Element.text(isBlock ? 'math-block' : 'math-inline', content);
    parser.addNode(el);
    return true;
  }
}

class _MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final isBlock = element.tag == 'math-block';
    return Math.tex(
      element.textContent,
      mathStyle: isBlock ? MathStyle.display : MathStyle.text,
      onErrorFallback: (e) => Text(element.textContent),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  XFile? _pendingImage;
  final _imagePicker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _pendingImage = picked);
  }

  void _clearPendingImage() => setState(() => _pendingImage = null);

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(aiChatProvider.notifier).initialize());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiChatProvider);
    _scheduleScrollToBottom();

    return Scaffold(
      appBar: AppBar(title: const Text('Mentora Chat')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyChatState(isLoading: state.isInitializing)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ChatBubble(message: message),
                        );
                      },
                    ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _ChatComposer(
              controller: _textController,
              isSending: state.isSending,
              pendingImage: _pendingImage,
              onPickImage: _pickImage,
              onClearImage: _clearPendingImage,
              onSend: _handleSend,
              onStop: () => ref.read(aiChatProvider.notifier).stopGeneration(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _textController.text;
    if (text.trim().isEmpty && _pendingImage == null) return;

    final imagePath = _pendingImage?.path;
    _textController.clear();
    _clearPendingImage();
    FocusScope.of(context).unfocus();
    await ref
        .read(aiChatProvider.notifier)
        .sendMessage(text, imagePath: imagePath);
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onStop,
    required this.onPickImage,
    required this.onClearImage,
    this.pendingImage,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;
  final VoidCallback onStop;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final XFile? pendingImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pendingImage != null)
            _ImagePreview(file: pendingImage!, onRemove: onClearImage),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: isSending ? null : onPickImage,
                icon: const Icon(Icons.image_outlined),
                tooltip: 'Attach image',
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText:
                        'Ask Mentora about grammar, vocabulary, or writing...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 52,
                width: 52,
                child: isSending
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          const SizedBox(
                            height: 52,
                            width: 52,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          IconButton(
                            onPressed: onStop,
                            icon: const Icon(Icons.stop_rounded),
                            iconSize: 22,
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: onSend,
                        style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Icon(Icons.send_rounded),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(file.path),
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.author == ChatAuthor.user;
    final bubbleColor = isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 20),
    );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(isUser ? 'You' : 'Mentora', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imagePath != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(message.imagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                  if (_bubbleText.isNotEmpty)
                    isUser
                        ? Text(_bubbleText, style: theme.textTheme.bodyLarge)
                        : MarkdownBody(
                            data: _bubbleText,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              theme,
                            ).copyWith(p: theme.textTheme.bodyLarge),
                            inlineSyntaxes: [_MathInlineSyntax()],
                            builders: {
                              'math-inline': _MathElementBuilder(),
                              'math-block': _MathElementBuilder(),
                            },
                          ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String get _bubbleText {
    if (message.isStreaming && message.text.isEmpty) {
      return 'Mentora is thinking...';
    }
    return message.text;
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.chat_bubble_outline,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLoading
                  ? 'Preparing Mentora...'
                  : 'Start chatting with Mentora',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about vocabulary, grammar, reading, or writing in everyday English.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
