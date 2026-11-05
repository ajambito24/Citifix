import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../constants/chatbot_prompt.dart';

/// Friendly error that the UI can show directly to the user.
class AiServiceException implements Exception {
  const AiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}


/// Keeps one chat session so the model remembers earlier messages.
class AiService {
  static const String modelName = 'gemini-3.5-flash-lite';

  late final GenerativeModel _model = FirebaseAI.googleAI().generativeModel(
    model: modelName,
    systemInstruction: Content.system(chatbotSystemPrompt),
    generationConfig: GenerationConfig(temperature: 0.4),
  );

  late ChatSession _chat = _model.startChat();

  /// Sends one user message and returns the bot's reply.
  /// Throws [AiServiceException] with a readable message on failure.
  Future<String> sendMessage(String text) async {
    try {
      final response = await _chat.sendMessage(Content.text(text));
      final reply = response.text?.trim() ?? '';

      if (reply.isEmpty) {
        throw const AiServiceException(
          "I couldn't come up with a reply. Please try rephrasing your question.",
        );
      }

      return reply;
    } on AiServiceException {
      rethrow;
    } catch (e) {
      debugPrint('AI error: $e');
      throw AiServiceException(_friendlyMessage(e));
    }
  }

  /// Starts a fresh conversation (forgets earlier messages).
  void reset() {
    _chat = _model.startChat();
  }

  String _friendlyMessage(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('failed host lookup') ||
        text.contains('connection') ||
        text.contains('timed out') ||
        text.contains('timeout')) {
      return 'No internet connection. Please check your connection and try again.';
    }

    if (text.contains('quota') ||
        text.contains('429') ||
        text.contains('rate limit') ||
        text.contains('resource exhausted')) {
      return 'The assistant is busy right now. Please wait a moment and try again.';
    }

    if (text.contains('safety') || text.contains('blocked')) {
      return "I can't help with that request. I can help with CitiFix questions instead.";
    }

    if (text.contains('not found') ||
        text.contains('404') ||
        text.contains('permission') ||
        text.contains('403') ||
        text.contains('api has not been used') ||
        text.contains('disabled') ||
        text.contains('api key')) {
      return 'The assistant is not available right now. Please try again later.';
    }

    return 'Something went wrong while contacting the assistant. Please try again.';
  }
}