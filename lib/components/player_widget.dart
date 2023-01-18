import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class PlayerWidget extends StatefulWidget {
  final AudioPlayer player;
  PlayerState playerState;

  PlayerWidget({
    super.key,
    required this.player,
    this.playerState = PlayerState.stopped,
  });

  @override
  State<StatefulWidget> createState() {
    return _PlayerWidgetState();
  }
}

const _iconSize = 30.0;

class _PlayerWidgetState extends State<PlayerWidget> {
  Duration? _duration;
  Duration? _position;

  PlayerState? _audioPlayerState;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => widget.playerState == PlayerState.playing;
  bool get _isPaused => widget.playerState == PlayerState.paused;
  bool get _isCompleted => widget.playerState == PlayerState.completed;

  String get _durationText =>
      _duration?.toString().split('.').first.padLeft(8, "0") ?? '00:00:00';
  String get _positionText =>
      _position?.toString().split('.').first.padLeft(8, "0") ?? '00:00:00';

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key("previous_button"),
          onPressed: () => {},
          iconSize: _iconSize,
          icon: const Icon(Icons.keyboard_double_arrow_left),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key('play_button'),
          onPressed: _isPlaying || _isCompleted ? null : _play,
          iconSize: _iconSize,
          icon: const Icon(Icons.play_arrow),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key('pause_button'),
          onPressed: _isPlaying ? _pause : null,
          iconSize: _iconSize,
          icon: const Icon(Icons.pause),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key('stop_button'),
          onPressed: _isPlaying || _isPaused ? _stop : null,
          iconSize: _iconSize,
          icon: const Icon(Icons.stop),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key("next_button"),
          onPressed: () => {},
          iconSize: _iconSize,
          icon: const Icon(Icons.keyboard_double_arrow_right),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key("from_here_button"),
          onPressed: () => {},
          iconSize: _iconSize,
          icon: const Icon(Icons.subdirectory_arrow_right),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key("to_here_button"),
          onPressed: () => {},
          iconSize: _iconSize,
          icon: const Icon(Icons.subdirectory_arrow_left),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key("one_loop_button"),
          onPressed: () => {},
          iconSize: _iconSize,
          icon: const Icon(Icons.loop),
          color: Colors.cyan,
        ),
      ],
    );

    final slider = Slider(
      onChanged: (double v) {
        final duration = _duration;
        if (duration == null) {
          return;
        }
        final position = v * duration.inMilliseconds;
        widget.player.seek(Duration(milliseconds: position.round()));
      },
      value: _positionValue(),
    );

    final currentPosition = Text(
      '$_positionText / $_durationText',
      style: const TextStyle(fontSize: 16.0),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: [
            buttons,
            const Expanded(child: SizedBox()),
            Padding(
              padding: const EdgeInsets.only(right: 30.0),
              child: currentPosition,
            ),
          ],
        ),
        slider,
        Text(_audioPlayerState.toString()),
      ],
    );
  }

  void _initStreams() {
    _durationSubscription = widget.player.onDurationChanged.listen((duration) {
      setState(() => _duration = duration);
    });

    _positionSubscription = widget.player.onPositionChanged.listen(
      (p) => setState(() => _position = p),
    );

    _playerCompleteSubscription = widget.player.onPlayerComplete.listen(
      (event) {
        setState(() {
          widget.playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      },
    );

    _playerStateChangeSubscription =
        widget.player.onPlayerStateChanged.listen((state) {
      setState(() {
        _audioPlayerState = state;
      });
    });
  }

  double _positionValue() {
    if (_position != null &&
        _duration != null &&
        _position!.inMilliseconds > 0) {
      final value = _position!.inMilliseconds / _duration!.inMilliseconds;
      if (value > 1) {
        _position = _duration;
        return 1;
      }
      return value;
    }
    return 0;
  }

  Future<void> _play() async {
    final position = _position;
    if (position != null && position.inMilliseconds > 0) {
      await widget.player.seek(position);
    }
    await widget.player.resume();
    setState(() => widget.playerState = PlayerState.playing);
  }

  Future<void> _pause() async {
    await widget.player.pause();
    setState(() => widget.playerState = PlayerState.paused);
  }

  Future<void> _stop() async {
    await widget.player.stop();
    setState(() {
      widget.playerState = PlayerState.stopped;
      _position = Duration.zero;
    });
  }
}
