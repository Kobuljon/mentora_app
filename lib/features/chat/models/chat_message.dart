enum ChatAuthor { user, mentor }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.imagePath,
    this.isStreaming = false,
  });

  final String id;
  final ChatAuthor author;
  final String text;
  final String? imagePath;
  final bool isStreaming;

  ChatMessage copyWith({
    String? id,
    ChatAuthor? author,
    String? text,
    String? imagePath,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      author: author ?? this.author,
      text: text ?? this.text,
      imagePath: imagePath ?? this.imagePath,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
