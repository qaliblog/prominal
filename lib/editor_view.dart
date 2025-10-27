import 'dart:io';
import 'package:flutter/material.dart';

class EditorView extends StatefulWidget {
  const EditorView({Key? key}) : super(key: key);

  @override
  State<EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pathController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final file = File(_pathController.text.trim());
      final exists = await file.exists();
      if (!exists) {
        setState(() => _error = 'File not found');
        return;
      }
      final text = await file.readAsString();
      _contentController.text = text;
    } catch (e) {
      setState(() => _error = 'Load failed: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _error = null);
    try {
      final file = File(_pathController.text.trim());
      await file.create(recursive: true);
      await file.writeAsString(_contentController.text);
    } catch (e) {
      setState(() => _error = 'Save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathController,
                  decoration: const InputDecoration(
                    hintText: 'Path to file (e.g., /storage/emulated/0/Notes/note.txt)',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _load, child: const Text('Open')),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
        if (_error != null)
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ),
        const Divider(height: 1),
        Expanded(
          child: TextField(
            controller: _contentController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(8)),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

