import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
          seedColor: const Color.fromARGB(255, 14, 233, 105),
        ),
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
  final AudioPlayer _player = AudioPlayer();
  File? _currentFile;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  Future<void> _pickFilesOrFolder() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        try {
          final dir = Directory(path);
          final allFiles = dir.listSync(recursive: true, followLinks: false);
          setState(() {
            selectedPath = path;
            files = allFiles
                .whereType<File>()
                .where((f) => f.path.toLowerCase().endsWith('.mp3'))
                .toList();
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading folder: $e')),
          );
        }
      }
    } else if (Platform.isAndroid) {
      // Pedir permiso de almacenamiento
      PermissionStatus status = await Permission.manageExternalStorage.request();
      if (status.isGranted) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission denied')),
        );
      }
    }
  }

  Future<void> _togglePlayPause(File file) async {
    if (_currentFile == file) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
    } else {
      try {
        await _player.setFilePath(file.path);
        await _player.play();
        setState(() {
          _currentFile = file;
        });
      } catch (e) {
        debugPrint("Error playing file: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing file: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
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
                      final filename =
                          file.path.split(Platform.pathSeparator).last;
                      return ListTile(
                        leading: const Icon(Icons.music_note),
                        title: Text(filename),
                        subtitle: file == _currentFile
                            ? const Text("▶ Now Playing")
                            : null,
                        onTap: () => _togglePlayPause(file),
                      );
                    },
                  ),
          ),
          if (_currentFile != null)
            StreamBuilder<Duration>(
              stream: _player.positionStream,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final total = _player.duration ?? Duration.zero;
                return Column(
                  children: [
                    Text(
                      _currentFile!.path.split(Platform.pathSeparator).last,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Slider(
                      min: 0,
                      max: total.inMilliseconds.toDouble(),
                      value: position.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                      onChanged: (value) {
                        _player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position)),
                        Text(_formatDuration(total)),
                      ],
                    ),
                  ],
                );
              },
            ),
        ], // Children
      ),
    );
  }
}
