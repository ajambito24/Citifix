import 'package:flutter/foundation.dart';

import '../services/ai_service.dart';

enum ChatSender { user, bot }

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.sender,
    this.isError = false,
  });

  final String text;
  final ChatSender sender;
  final bool isError;

  bool get isUser => sender == ChatSender.user;
}

/// Holds the chat state. The page listens to this and never talks to
class ChatController extends ChangeNotifier {
  ChatController({AiService? aiService}) : _ai = aiService ?? AiService();

  final AiService _ai;
  bool _disposed = false;

  static const String welcomeMessage =
      'Hi! I am CitiFix AI. I can help you report issues, understand report '
      'statuses, and use the app. What would you like to know?';

  static const List<String> suggestions = [
    'How do I submit a report?',
    'What do the report statuses mean?',
    'What issues can I report?',
    'Does CitiFix cover my area?',
  ];

  final List<ChatMessage> _messages = [
    const ChatMessage(text: welcomeMessage, sender: ChatSender.bot),
  ];

  bool _isTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;

  /// Suggestion chips only show before the user has sent anything.
  bool get showSuggestions => _messages.length == 1 && !_isTyping;

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _isTyping) return;

    _messages.add(ChatMessage(text: text, sender: ChatSender.user));
    _isTyping = true;
    _notify();

    try {
      final reply = await _ai.sendMessage(text);
      _messages.add(ChatMessage(text: reply, sender: ChatSender.bot));
    } on AiServiceException catch (e) {
      _messages.add(
        ChatMessage(text: e.message, sender: ChatSender.bot, isError: true),
      );
    } catch (_) {
      _messages.add(
        const ChatMessage(
          text: 'Something went wrong. Please try again.',
          sender: ChatSender.bot,
          isError: true,
        ),
      );
    } finally {
      _isTyping = false;
      _notify();
    }
  }

  /// Clears the conversation and starts a new AI session.
  void clear() {
    _ai.reset();
    _messages
      ..clear()
      ..add(const ChatMessage(text: welcomeMessage, sender: ChatSender.bot));
    _isTyping = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}