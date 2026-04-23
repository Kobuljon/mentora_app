enum ChatAuthor { user, mentor }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.isStreaming = false,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final bool isStreaming;

  ChatMessage copyWith({
    String? id,
    ChatAuthor? author,
    String? text,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
