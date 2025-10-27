import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'settings.dart';

class ChatView extends StatefulWidget {
  ChatView({Key? key}) : super(key: key);

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final List<_Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _isSending = true;
      _inputController.clear();
    });
    try {
      final settings = await Settings.load();
      if (settings.apiEndpoint == null || settings.apiKey == null) {
        setState(() {
          _messages.add(_Message(role: 'system', content: 'AI provider not configured in Settings.'));
        });
      } else {
        final reply = await _invokeApi(settings, text);
        setState(() {
          _messages.add(_Message(role: 'assistant', content: reply ?? 'No response'));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_Message(role: 'system', content: 'Error: $e'));
      });
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<String?> _invokeApi(Settings settings, String prompt) async {
    final uri = Uri.parse(settings.apiEndpoint!);
    final headers = {
      'Content-Type': 'application/json',
      if (settings.apiKey != null) 'Authorization': 'Bearer ${settings.apiKey}',
    };
    final body = jsonEncode({
      'model': settings.model ?? 'gpt-3.5-turbo',
      'messages': [
        for (final m in _messages) {'role': m.role, 'content': m.content},
        {'role': 'user', 'content': prompt}
      ],
      'stream': false,
    });
    final res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Try OpenAI-like response
      try {
        final map = jsonDecode(res.body) as Map<String, dynamic>;
        final choices = map['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final msg = choices.first['message'];
          if (msg is Map && msg['content'] is String) return msg['content'] as String;
        }
      } catch (_) {}
      return res.body;
    }
    throw Exception('API error ${res.statusCode}: ${res.body}');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final bg = m.role == 'user'
                  ? Colors.blueGrey.shade800
                  : (m.role == 'assistant' ? Colors.green.shade800 : Colors.black54);
              return Align(
                alignment: m.role == 'user' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Text(m.content),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Ask...'),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _isSending ? null : _send, child: const Text('Send')),
            ],
          ),
        ),
      ],
    );
  }
}

class _Message {
  final String role;
  final String content;
  _Message({required this.role, required this.content});
}

