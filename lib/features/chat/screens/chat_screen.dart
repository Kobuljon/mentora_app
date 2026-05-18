import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/services/tts_service.dart';
import '../../models/screens/downloaded_models_screen.dart';
import '../../onboarding/services/model_download_service.dart';
import '../../settings/providers/settings_provider.dart';
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
  String _activeLocalModelLabel = 'Local model';
  int _lastMessageCount = 0;

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
    Future.microtask(_loadActiveModelLabel);
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
    final settings = ref.watch(settingsProvider);

    if (_lastMessageCount != state.messages.length) {
      _lastMessageCount = state.messages.length;
      _scheduleScrollToBottom();
    }
    _scheduleAutoRead(state);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        titleSpacing: 16,
        title: _ChatTitle(
          modelLabel: settings.aiBackendProvider == AiBackendProvider.local
              ? _activeLocalModelLabel
              : settings.aiBackendProvider.label,
          onModelTap: state.isBusy ? null : _showModelPicker,
        ),
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

  Future<void> _loadActiveModelLabel() async {
    try {
      final active = await ModelDownloadService.instance.getActiveModel();
      if (!mounted || active == null) return;
      setState(() => _activeLocalModelLabel = active.variant.shortLabel);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeLocalModelLabel = 'Local model');
    }
  }

  Future<void> _showModelPicker() async {
    final settings = ref.read(settingsProvider);
    final models = await ModelDownloadService.instance.getDownloadedModels();
    if (!mounted) return;

    final selected = await showModalBottomSheet<_ChatModelSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _ModelPickerSheet(models: models, settings: settings),
    );
    if (selected == null || !mounted) return;

    switch (selected) {
      case _LocalModelSelection(:final model):
        await ModelDownloadService.instance.setActiveModel(model);
        await ref
            .read(settingsProvider.notifier)
            .setAiBackendProvider(AiBackendProvider.local);
        setState(() => _activeLocalModelLabel = model.variant.shortLabel);
        await ref.read(aiChatProvider.notifier).switchLocalModel(model.path);
      case _CloudModelSelection(:final provider):
        await ref
            .read(settingsProvider.notifier)
            .setAiBackendProvider(provider);
        await ref.read(aiChatProvider.notifier).clearChat();
      case _ManageModelsSelection():
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const DownloadedModelsScreen()),
        );
        await _loadActiveModelLabel();
    }
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
    final messageId = lastMessage.id;
    if (lastMessage.author != ChatAuthor.mentor ||
        lastMessage.isStreaming ||
        lastMessage.text.trim().isEmpty ||
        messageId == _lastAutoReadMessageId) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoReadEnabled) return;
      if (_lastAutoReadMessageId == messageId) return;
      _lastAutoReadMessageId = messageId;
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
  const _ChatTitle({required this.modelLabel, required this.onModelTap});

  final String modelLabel;
  final VoidCallback? onModelTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mentora',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phonelink_lock_rounded,
                            size: 12,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'On-device Gemma 4',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: InkWell(
                      onTap: onModelTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                modelLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

sealed class _ChatModelSelection {
  const _ChatModelSelection();
}

class _LocalModelSelection extends _ChatModelSelection {
  const _LocalModelSelection(this.model);

  final DownloadedModelInfo model;
}

class _CloudModelSelection extends _ChatModelSelection {
  const _CloudModelSelection(this.provider);

  final AiBackendProvider provider;
}

class _ManageModelsSelection extends _ChatModelSelection {
  const _ManageModelsSelection();
}

class _ModelPickerSheet extends StatelessWidget {
  const _ModelPickerSheet({required this.models, required this.settings});

  final List<DownloadedModelInfo> models;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final cloudProviders = AiBackendProvider.values
        .where((provider) => provider != AiBackendProvider.local)
        .where(settings.isCloudBackendConfigured)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Switch model',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Changing models starts a clean chat.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (cloudProviders.isNotEmpty) ...[
              const _SheetLabel('BYOK providers'),
              for (final provider in cloudProviders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(provider.label),
                  subtitle: Text(settings.cloudModelLabel(provider)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      Navigator.pop(context, _CloudModelSelection(provider)),
                ),
              const SizedBox(height: 8),
            ],
            const _SheetLabel('Local models'),
            for (final model in models)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.memory_rounded),
                title: Text(model.variant.displayName),
                subtitle: Text(model.sizeLabel),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.pop(context, _LocalModelSelection(model)),
              ),
            if (models.isEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('No local models downloaded'),
                subtitle: const Text('Download or import one'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.pop(context, const _ManageModelsSelection()),
              ),
            if (models.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Manage local models'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    Navigator.pop(context, const _ManageModelsSelection()),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
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
    final colorScheme = theme.colorScheme;
    final isUser = message.author == ChatAuthor.user;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final userBubbleColor = colorScheme.surfaceContainerHighest;
    final userTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
    );
    final assistantTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          isUser ? 'You' : 'Mentora',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * (isUser ? 0.78 : 0.9),
          ),
          child: Container(
            decoration: isUser
                ? BoxDecoration(
                    color: userBubbleColor,
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
                        ? Text(message.text, style: userTextStyle)
                        : MarkdownBody(
                            data: message.text,
                            styleSheet: MarkdownStyleSheet.fromTheme(theme)
                                .copyWith(
                                  p: assistantTextStyle,
                                  code: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                ),
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
      'Answer from my uploaded materials: what should I review first?',
      'Quiz me on my uploaded notes',
      'Summarize the key ideas from my training data',
      'Ask me 5 questions from my uploaded materials',
      'Explain a difficult topic from my notes',
      'Make flashcards from my uploaded lessons',
      'Help me practice past tense',
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
              'Ask about uploaded lessons, vocabulary, grammar, reading, or writing.',
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
