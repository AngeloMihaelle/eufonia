import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class MusicPickerScreen extends StatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  List<String> _files = [];

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav'],
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _files = result.paths.whereType<String>().toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Seleccionar Música")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _pickFiles,
            child: const Text("Abrir carpeta de música"),
          ),
          Expanded(
            child: _files.isEmpty
                ? const Center(child: Text("No has seleccionado archivos 🎵"))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(_files[index].split("/").last),
                        subtitle: Text(_files[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
