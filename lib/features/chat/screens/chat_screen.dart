import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/services/tts_service.dart';
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
  bool _autoReadEnabled = false;
  String? _lastAutoReadMessageId;

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
    _scheduleAutoRead(state);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 16,
        title: const _ChatTitle(),
        actions: [
          _AutoReadToggle(
            enabled: _autoReadEnabled,
            onPressed: () {
              setState(() => _autoReadEnabled = !_autoReadEnabled);
              if (!_autoReadEnabled) TtsService.instance.stop();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.messages.isEmpty
                  ? _EmptyChatState(
                      isLoading: state.isInitializing,
                      onPromptSelected: _handleSuggestion,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              isPreparing: state.isInitializing,
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
    final state = ref.read(aiChatProvider);
    if (state.isInitializing || state.isSending) return;

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

  Future<void> _handleSuggestion(String prompt) async {
    if (ref.read(aiChatProvider).isBusy) return;
    _textController.text = prompt;
    await _handleSend();
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

  void _scheduleAutoRead(AiChatState state) {
    if (!_autoReadEnabled || state.messages.isEmpty) return;

    final lastMessage = state.messages.last;
    if (lastMessage.author != ChatAuthor.mentor ||
        lastMessage.isStreaming ||
        lastMessage.text.trim().isEmpty ||
        lastMessage.id == _lastAutoReadMessageId) {
      return;
    }

    _lastAutoReadMessageId = lastMessage.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoReadEnabled) return;
      TtsService.instance.speak(lastMessage.id, lastMessage.text);
    });
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isPreparing,
    required this.isSending,
    required this.onSend,
    required this.onStop,
    required this.onPickImage,
    required this.onClearImage,
    this.pendingImage,
  });

  final TextEditingController controller;
  final bool isPreparing;
  final bool isSending;
  final Future<void> Function() onSend;
  final VoidCallback onStop;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final XFile? pendingImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canCompose = !isPreparing && !isSending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pendingImage != null)
                _ImagePreview(file: pendingImage!, onRemove: onClearImage),
              TextField(
                controller: controller,
                enabled: canCompose,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: canCompose ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: isPreparing
                      ? 'Preparing Mentora...'
                      : 'Ask anything about English',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _ComposerIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Attach image',
                    onPressed: canCompose ? onPickImage : null,
                  ),
                  _ComposerIconButton(
                    icon: Icons.image_outlined,
                    tooltip: 'Image',
                    onPressed: canCompose ? onPickImage : null,
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 42,
                    width: 42,
                    child: isSending
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colorScheme.primary,
                              ),
                              IconButton(
                                onPressed: onStop,
                                icon: const Icon(Icons.stop_rounded),
                                iconSize: 20,
                              ),
                            ],
                          )
                        : FilledButton(
                            onPressed: canCompose ? onSend : null,
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.arrow_upward_rounded),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ChatTitle extends StatelessWidget {
  const _ChatTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mentora',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'English tutor',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AutoReadToggle extends StatelessWidget {
  const _AutoReadToggle({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final background = enabled
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tooltip(
        message: enabled ? 'Auto-read is on' : 'Auto-read is off',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: enabled
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _VolumeStatusIcon(enabled: enabled),
                const SizedBox(width: 6),
                Text(
                  'Auto-read',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeStatusIcon extends StatelessWidget {
  const _VolumeStatusIcon({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.center,
            child: Icon(
              enabled ? Icons.volume_up_rounded : Icons.volume_up_outlined,
              size: 20,
              color: enabled
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
          if (!enabled)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 10,
                  color: colorScheme.onError,
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
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(isUser ? 'You' : 'Mentora', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.9),
          ),
          child: Container(
            decoration: isUser
                ? BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                      bottomLeft: Radius.circular(22),
                      bottomRight: Radius.circular(6),
                    ),
                  )
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 14 : 0,
                vertical: isUser ? 12 : 4,
              ),
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
                  if (message.isStreaming && message.text.isEmpty)
                    const _ThinkingIndicator()
                  else if (message.text.isNotEmpty)
                    isUser
                        ? Text(message.text, style: theme.textTheme.bodyLarge)
                        : MarkdownBody(
                            data: message.text,
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
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              _ThinkingDot(opacity: _dotOpacity(i), color: colorScheme.primary),
              if (i < 2) const SizedBox(width: 5),
            ],
          ],
        );
      },
    );
  }

  double _dotOpacity(int index) {
    final phase = (_controller.value + index * 0.18) % 1.0;
    return 0.35 + (0.65 * (1 - (phase - 0.5).abs() * 2));
  }
}

class _ThinkingDot extends StatelessWidget {
  const _ThinkingDot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.35, 1.0),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({
    required this.isLoading,
    required this.onPromptSelected,
  });

  final bool isLoading;
  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prompts = const [
      'Help me practice past tense',
      'Explain this word with examples',
      'Make a short vocabulary quiz',
      'Check my sentence for grammar',
    ];

    return Align(
      alignment: Alignment.center,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.tertiary,
                  colorScheme.secondary,
                ],
              ).createShader(bounds),
              child: Text(
                isLoading ? 'Preparing Mentora' : 'Where should we start?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask about vocabulary, grammar, reading, or writing.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (isLoading)
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            else
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final prompt in prompts)
                    ActionChip(
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 17),
                      label: Text(prompt),
                      onPressed: () => onPromptSelected(prompt),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
