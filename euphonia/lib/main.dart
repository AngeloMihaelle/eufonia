import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const EuphoniaApp());
}

class EuphoniaApp extends StatelessWidget {
  const EuphoniaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Euphonia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 14, 233, 105)),
        useMaterial3: true,
      ),
      home: const FileBrowserScreen(),
    );
  }
}

class FileBrowserScreen extends StatefulWidget {
  const FileBrowserScreen({super.key});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  String? selectedPath;
  List<File> files = [];

  Future<void> _pickFilesOrFolder() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      // Desktop o Web: elige carpeta
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        final dir = Directory(path);
        final allFiles = dir.listSync(recursive: true, followLinks: false);
        setState(() {
          selectedPath = path;
          files = allFiles
              .whereType<File>()
              .where((f) => f.path.toLowerCase().endsWith('.mp3'))
              .toList();
        });
      }
    } else if (Platform.isAndroid) {
      // Pedir permiso de almacenamiento
      PermissionStatus status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
        // Android 11+ requiere usar FilePicker para elegir carpeta
        String? path = await FilePicker.platform.getDirectoryPath();
        if (path != null) {
          final dir = Directory(path);
          final allFiles = dir.listSync(recursive: true, followLinks: false);
          setState(() {
            selectedPath = path;
            files = allFiles
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp3'))
                .toList();
          });
        }
      } else {
        // Usuario no dio permisos
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Euphonia'),
      ),
      body: Column(
        children: [
          ElevatedButton.icon(
            onPressed: _pickFilesOrFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select Folder / Files'),
          ),
          if (selectedPath != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Selected:\n$selectedPath'),
            ),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text('No MP3 files found'))
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(
                          file.path.split(Platform.pathSeparator).last,
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Selected: ${file.path}')),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
