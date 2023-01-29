import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:kikimasu/components/player_widget.dart';
import 'package:kikimasu/components/playlist_widget.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kikimasu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Kikimasu top'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final player = AudioPlayer();
  PlayerState playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          PlayerWidget(
            player: player,
            playerState: playerState,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: PlayListWidget(
                onDoubleTap: (data) async {
                  final fullPath = path.join(data.path, data.name);
                  await player.play(DeviceFileSource(fullPath));
                  setState(() {
                    playerState = PlayerState.playing;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
