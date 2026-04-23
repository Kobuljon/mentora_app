import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../services/ai_chat_service.dart';

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isInitializing = false,
    this.isSending = false,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isInitializing;
  final bool isSending;
  final String? errorMessage;

  bool get isBusy => isInitializing || isSending;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isInitializing,
    bool? isSending,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isInitializing: isInitializing ?? this.isInitializing,
      isSending: isSending ?? this.isSending,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final aiChatServiceProvider = Provider<AiChatService>((ref) {
  final service = AiChatService();
  ref.onDispose(service.dispose);
  return service;
});

final aiChatProvider = StateNotifierProvider<AiChatNotifier, AiChatState>((
  ref,
) {
  return AiChatNotifier(ref.read(aiChatServiceProvider));
});

class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier(this._chatService) : super(const AiChatState());

  final AiChatService _chatService;

  Future<void> initialize() async {
    if (state.isInitializing) return;

    state = state.copyWith(isInitializing: true, clearError: true);
    try {
      await _chatService.initialize();
      state = state.copyWith(isInitializing: false, clearError: true);
    } catch (error) {
      state = state.copyWith(
        isInitializing: false,
        errorMessage:
            'Unable to load Mentora right now. Check the local model path and try again.',
      );
    }
  }

  Future<void> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || state.isBusy) return;

    if (state.messages.isEmpty && !state.isInitializing) {
      await initialize();
    }

    final userMessage = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.user,
      text: text,
    );
    final aiMessage = ChatMessage(
      id: _nextId(),
      author: ChatAuthor.mentor,
      text: '',
      isStreaming: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage, aiMessage],
      isSending: true,
      clearError: true,
    );

    try {
      await for (final partialText in _chatService.sendMessage(text)) {
        state = state.copyWith(
          messages: _replaceMessage(
            aiMessage.id,
            aiMessage.copyWith(text: partialText, isStreaming: true),
          ),
          isSending: true,
        );
      }

      state = state.copyWith(
        messages: _replaceMessage(
          aiMessage.id,
          _findMessage(aiMessage.id).copyWith(isStreaming: false),
        ),
        isSending: false,
      );
    } catch (error) {
      state = state.copyWith(
        messages: _replaceMessage(
          aiMessage.id,
          aiMessage.copyWith(
            text: 'I hit a problem while answering. Please try again.',
            isStreaming: false,
          ),
        ),
        isSending: false,
        errorMessage: 'Message failed to send.',
      );
    }
  }

  List<ChatMessage> _replaceMessage(String id, ChatMessage updatedMessage) {
    return [
      for (final message in state.messages)
        if (message.id == id) updatedMessage else message,
    ];
  }

  ChatMessage _findMessage(String id) {
    return state.messages.firstWhere((message) => message.id == id);
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();
}
