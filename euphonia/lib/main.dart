import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Green = Color.fromARGB(255, 38, 86, 41);
const IconSize = 24.0;

enum PlaybackMode {
  normal,    // Reproduce la lista y se detiene al final
  loopOne,   // Repite la canción actual
  loopAll,   // Repite toda la lista
  shuffle    // Reproduce aleatorio sin repetir hasta agotar lista
}

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
          seedColor: Green
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
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.normal;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    loadPlaybackMode();

    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && files.isNotEmpty) {
        final nextIndex = (_currentIndex + 1) % files.length;
        _playAtIndex(nextIndex);
      }
    });
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

  // Guardar la carpeta seleccionada
  Future<void> saveLastFolder(String path) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_folder', path);
  }

  // Cargar la última carpeta
  Future<String?> loadLastFolder() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('last_folder');
  }

  // Guardar el modo de reproducción (ej: 0=normal, 1=loop1, 2=loopAll, 3=random)
  Future<void> savePlaybackMode(PlaybackMode mode) async {
  final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('playback_mode', mode.index);
  }

  // Cargar el modo de reproducción
  Future<void> loadPlaybackMode() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('playback_mode') ?? 0;
    setState(() {
      _playbackMode = PlaybackMode.values[index];
    });
  }

  Widget _buildLoopButton() {
    IconData icon;
    String tooltip;

    switch (_playbackMode) {
      case PlaybackMode.normal:
        icon = Icons.repeat; // normal sin highlight
        tooltip = "Normal (sin loop)";
        break;
      case PlaybackMode.loopOne:
        icon = Icons.repeat_one;
        tooltip = "Repetir canción";
        break;
      case PlaybackMode.loopAll:
        icon = Icons.repeat;
        tooltip = "Repetir toda la lista";
        break;
      case PlaybackMode.shuffle:
        icon = Icons.shuffle;
        tooltip = "Reproducción aleatoria";
        break;
    }

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 32, color: Colors.green),
        onPressed: () {
          setState(() {
            // cambiar al siguiente modo
            _playbackMode = PlaybackMode.values[
                (_playbackMode.index + 1) % PlaybackMode.values.length
            ];
            savePlaybackMode(_playbackMode);
          });
        },
      ),
    );
  }


  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= files.length) return;
    try {
      // Asegura estado limpio antes de cambiar de pista (evita "hay que presionar play otra vez")
      await _player.stop();
      await _player.setFilePath(files[index].path);
      await _player.play(); // arranca de inmediato
      setState(() {
        _currentIndex = index;
        _currentFile = files[index];
      });
    } catch (e) {
      debugPrint("Error playing file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing file: $e')),
      );
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
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;

          // Play / Pause con K
          if (key == LogicalKeyboardKey.keyK || key == LogicalKeyboardKey.space) {
            if (_player.playing) {
              _player.pause();
            } else {
              _player.play();
            }
          }

          // Adelantar 10s con L
          else if (key == LogicalKeyboardKey.keyL) {
            final pos = _player.position + Duration(seconds: 10);
            _player.seek(pos);
          }

          // Retroceder 10s con J
          else if (key == LogicalKeyboardKey.keyJ) {
            final pos = _player.position - Duration(seconds: 10);
            _player.seek(pos < Duration.zero ? Duration.zero : pos);
          }

          // Adelantar 5s con flecha derecha
          else if (key == LogicalKeyboardKey.arrowRight) {
            final pos = _player.position + Duration(seconds: 5);
            _player.seek(pos);
          }

          // Retroceder 5s con flecha izquierda
          else if (key == LogicalKeyboardKey.arrowLeft) {
            final pos = _player.position - Duration(seconds: 5);
            _player.seek(pos < Duration.zero ? Duration.zero : pos);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text("Euphonia")),
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
                          subtitle: index == _currentIndex
                              ? const Text("▶ Now Playing")
                              : null,
                          onTap: () {
                            if (_currentIndex == index) {
                              // toggle play/pause
                              if (_player.playing) {
                                _player.pause();
                              } else {
                                _player.play();
                              }
                            } else {
                              _playAtIndex(index);
                            }
                          },
                        );
                      },
                    ),
            ),
            if (_currentFile != null) ...[
              // 🎵 Nombre de la canción actual
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "Now playing: ${_currentFile!.path.split(Platform.pathSeparator).last}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              // 📊 Barra de progreso
              StreamBuilder<Duration>(
                stream: _player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final total = _player.duration ?? Duration.zero;
                  return Column(
                    children: [
                      Slider(
                        min: 0,
                        max: total.inMilliseconds.toDouble(),
                        value: position.inMilliseconds
                            .clamp(0, total.inMilliseconds)
                            .toDouble(),
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

              // 🎛️ Controles de reproducción
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Canción anterior
                  Tooltip(
                    message: "Canción anterior",
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6), // espacio entre botones
                      decoration: BoxDecoration(
                        color: Green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: IconSize,
                        color: Colors.white,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () {
                          if (files.isNotEmpty) {
                            final prevIndex = (_currentIndex - 1 + files.length) % files.length;
                            _playAtIndex(prevIndex);
                          }
                        },
                      ),
                    ),
                  ),
                  // Retroceder 10s
                  Tooltip(
                    message: "Presiona J",
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6), // espacio entre botones
                      decoration: BoxDecoration(
                        color: Green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: IconSize,
                        color: Colors.white,
                        icon: const Icon(Icons.replay_10),
                        onPressed: () {
                          final pos = _player.position - const Duration(seconds: 10);
                          _player.seek(pos < Duration.zero ? Duration.zero : pos);
                        },
                      ),
                    ),
                  ),
                  // Play / Pause
                  StreamBuilder<PlayerState>(
                    stream: _player.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;
                      final isLoading = playerState?.processingState == ProcessingState.loading ||
                                        playerState?.processingState == ProcessingState.buffering;

                      return Tooltip(
                        message: "Presiona K o espacio",
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: Green,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: IconSize,
                            color: Colors.white,
                            icon: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: (_currentFile == null || isLoading)
                                ? null
                                : () {
                                    if (isPlaying) {
                                      _player.pause();
                                    } else {
                                      _player.play();
                                    }
                                  },
                          ),
                        ),
                      );
                    },
                  ),

                  // Avanzar 10s
                  Tooltip(
                    message: "Presiona L",
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6), // espacio entre botones
                      decoration: BoxDecoration(
                        color: Green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: IconSize,
                        color: Colors.white,
                        icon: const Icon(Icons.forward_10),
                        onPressed: () {
                          final pos = _player.position + const Duration(seconds: 10);
                          _player.seek(pos);
                        },
                      ),
                    ),
                  ),
                  // Canción siguiente
                  Tooltip(
                    message: "Canción siguiente",
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6), // espacio entre botones
                      decoration: BoxDecoration(
                        color: Green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        iconSize: IconSize,
                        color: Colors.white,
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          if (files.isNotEmpty) {
                            final nextIndex = (_currentIndex + 1) % files.length;
                            _playAtIndex(nextIndex);
                          }
                        },
                      ),
                    ),
                  ),
                  // Botón de loop / shuffle
                  _buildLoopButton(),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}