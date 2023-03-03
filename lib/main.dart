import 'dart:io';
import 'package:window_size/window_size.dart' as window_size;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mimij/components/player_widget.dart';
import 'package:mimij/components/playlist_widget.dart';
import 'package:path/path.dart' as path;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    window_size.setWindowMinSize(const Size(640, 360));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mimij',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          PlayerWidget(
            player: player,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: PlayListWidget(
                onDoubleTap: (data) async {
                  final fullPath = path.join(data.path, data.name);
                  await player.play(DeviceFileSource(fullPath));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
