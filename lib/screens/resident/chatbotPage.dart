import 'package:flutter/material.dart';

class Chatbot extends StatefulWidget {
  const Chatbot({super.key});

  @override
  State<Chatbot> createState() =>
      _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {

  final messageController =
      TextEditingController();

  final List<Map<String, String>> messages = [
    {
      'sender': 'bot',
      'message':
          'Hey! How can I help you?'
    },
  ];

  void sendMessage() {
    final text =
        messageController.text.trim();

    if (text.isEmpty) return;

    setState(() {
      messages.add({
        'sender': 'user',
        'message': text,
      });

      messages.add({
        'sender': 'bot',
        'message':
            'Thank you for your message. I can help you with CitiFix reporting and common questions.',
      });
    });

    messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EEF7),

      appBar: AppBar(
        title: const Text('Chatbot'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      body: Column(
        children: [

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,

              itemBuilder: (context, index) {

                final message =
                    messages[index];

                final isUser =
                    message['sender'] == 'user';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,

                  child: Container(
                    margin:
                        const EdgeInsets.only(
                      bottom: 10,
                    ),

                    padding:
                        const EdgeInsets.all(12),

                    constraints:
                        const BoxConstraints(
                      maxWidth: 280,
                    ),

                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.blue
                          : Colors.grey.shade300,
                      borderRadius:
                          BorderRadius.circular(12),
                    ),

                    child: Text(
                      message['message'] ?? '',
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,

            child: Row(
              children: [

                const Icon(
                  Icons.add_circle_outline,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: TextField(
                    controller:
                        messageController,

                    decoration:
                        const InputDecoration(
                      hintText:
                          'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.all(
                          Radius.circular(20),
                        ),
                      ),
                    ),

                    onSubmitted: (_) {
                      sendMessage();
                    },
                  ),
                ),

                IconButton(
                  onPressed: sendMessage,
                  icon: const Icon(
                    Icons.send,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}