import 'package:flutter/material.dart';
import 'settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController(text: 'gpt-3.5-turbo');
  bool _loading = true;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await Settings.load();
    _endpointController.text = s.apiEndpoint ?? '';
    _apiKeyController.text = s.apiKey ?? '';
    _modelController.text = s.model ?? 'gpt-3.5-turbo';
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _status = null);
    try {
      await Settings(
        apiEndpoint: _endpointController.text.trim().isEmpty ? null : _endpointController.text.trim(),
        apiKey: _apiKeyController.text.trim().isEmpty ? null : _apiKeyController.text.trim(),
        model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
      ).save();
      setState(() => _status = 'Saved');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('AI Provider', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(labelText: 'API Endpoint (OpenAI-compatible)')
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API Key')
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _save, child: const Text('Save')),
          if (_status != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_status!, style: TextStyle(color: _status == 'Saved' ? Colors.green : Colors.red)),
          ),
        ],
      ),
    );
  }
}

