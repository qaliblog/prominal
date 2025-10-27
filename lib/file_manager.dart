import 'dart:io';
import 'package:flutter/material.dart';

class FileManagerView extends StatefulWidget {
  const FileManagerView({Key? key}) : super(key: key);

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  late Directory _currentDir;
  List<FileSystemEntity> _entries = const [];

  @override
  void initState() {
    super.initState();
    final home = Platform.environment['HOME'] ?? Directory.current.path;
    _currentDir = Directory(home);
    _refresh();
  }

  void _refresh() {
    try {
      _entries = _currentDir.listSync()..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    } catch (_) {
      _entries = const [];
    }
    setState(() {});
  }

  void _enter(Directory dir) {
    _currentDir = dir;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.black54,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                onPressed: () {
                  final parent = _currentDir.parent;
                  if (parent.path != _currentDir.path) _enter(parent);
                },
              ),
              Expanded(
                child: Text(
                  _currentDir.path,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entity = _entries[index];
              final isDir = FileSystemEntity.isDirectorySync(entity.path);
              return ListTile(
                dense: true,
                leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                title: Text(entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last),
                onTap: isDir ? () => _enter(Directory(entity.path)) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

