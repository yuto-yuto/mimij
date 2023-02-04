import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
const _kPadding = 8.0;
const _sliderPadding = CupertinoThumbPainter.radius + _kPadding;

class _PlayerWidgetState extends State<PlayerWidget> with WidgetsBindingObserver {
  Duration? audioLength;
  Duration? currentPositionDuration;
  double? startRelativeX;
  double? endRelativeX;
  double? selectedAreaWidth;
  final _keyForSlider = GlobalKey();
  double? _leftGlobalX;
  double? _rightGlobalX;
  double sliderPosition = 0;

  PlayerState? _audioPlayerState;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => widget.playerState == PlayerState.playing;
  bool get _isPaused => widget.playerState == PlayerState.paused;
  bool get _isCompleted => widget.playerState == PlayerState.completed;

  String get _durationText => audioLength?.toString().split('.').first.padLeft(8, "0") ?? '00:00:00';
  String get _positionText => currentPositionDuration?.toString().split('.').first.padLeft(8, "0") ?? '00:00:00';

  double get sliderWidth {
    final renderBox = _keyForSlider.currentContext?.findRenderObject() as RenderBox;
    return renderBox.size.width - _sliderPadding * 2;
    ;
  }

  void set leftGlobalX(double? value) {
    if (value != null) {
      _leftGlobalX = value + _sliderPadding;
    } else {
      _leftGlobalX = null;
    }
  }

  double? get leftGlobalX => _leftGlobalX;

  void set rightGlobalX(double? value) {
    if (value != null) {
      _rightGlobalX = value + _sliderPadding;
    } else {
      _rightGlobalX = null;
    }
  }

  double? get rightGlobalX => _rightGlobalX;
  @override
  void initState() {
    super.initState();
    _initStreams();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_leftGlobalX != null && _rightGlobalX == null) {
      setState(() {
        leftGlobalX = startRelativeX! * sliderWidth;
        selectedAreaWidth = sliderWidth * (1 - startRelativeX!);
      });
    } else if (_leftGlobalX == null && _rightGlobalX != null) {
      setState(() {
        rightGlobalX = endRelativeX! * sliderWidth;
        selectedAreaWidth = _rightGlobalX!;
      });
    } else if (_leftGlobalX != null && _rightGlobalX != null) {
      setState(() {
        leftGlobalX = startRelativeX! * sliderWidth;
        rightGlobalX = endRelativeX! * sliderWidth;
        selectedAreaWidth = _rightGlobalX! - leftGlobalX!;
      });
    }
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
          onPressed: () => setState(() {
            if (endRelativeX == null) {
              if (startRelativeX == sliderPosition) {
                setState(() {
                  startRelativeX = null;
                  leftGlobalX = null;
                  selectedAreaWidth = null;
                });
              } else {
                setState(() {
                  startRelativeX = sliderPosition;
                  leftGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = sliderWidth * (1 - sliderPosition);
                });
              }
              return;
            }

            if (endRelativeX! <= sliderPosition) {
              if (startRelativeX != null) {
                setState(() {
                  startRelativeX = null;
                  leftGlobalX = null;
                  selectedAreaWidth = rightGlobalX!;
                });
              }
              return;
            }

            if (startRelativeX == sliderPosition) {
              setState(() {
                startRelativeX = null;
                leftGlobalX = null;
                selectedAreaWidth = rightGlobalX!;
              });
              return;
            }

            if (endRelativeX! > sliderPosition) {
              setState(() {
                startRelativeX = sliderPosition;
                leftGlobalX = sliderWidth * sliderPosition;
                selectedAreaWidth = rightGlobalX! - leftGlobalX!;
              });
            }
          }),
          iconSize: _iconSize,
          icon: const Icon(Icons.subdirectory_arrow_right),
          color: Colors.cyan,
        ),
        IconButton(
          key: const Key("to_here_button"),
          onPressed: () {
            if (startRelativeX == null) {
              setState(() {
                if (endRelativeX == sliderPosition) {
                  endRelativeX = null;
                  rightGlobalX = null;
                  selectedAreaWidth = null;
                } else {
                  endRelativeX = sliderPosition;
                  rightGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = rightGlobalX;
                }
              });
              return;
            }

            if (startRelativeX! >= sliderPosition || endRelativeX == sliderPosition) {
              if (endRelativeX != null) {
                setState(() {
                  endRelativeX = null;
                  rightGlobalX = null;
                  selectedAreaWidth = sliderWidth * (1 - startRelativeX!);
                });
              }
              return;
            }

            if (startRelativeX! < sliderPosition) {
              setState(() {
                endRelativeX = sliderPosition;
                rightGlobalX = sliderWidth * sliderPosition;
                selectedAreaWidth = rightGlobalX! - leftGlobalX!;
              });
            }
          },
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
      key: _keyForSlider,
      onChanged: (double v) {
        final duration = audioLength;
        if (duration == null) {
          return;
        }
        final position = v * duration.inMilliseconds;
        widget.player.seek(Duration(milliseconds: position.round()));
      },
      value: sliderPosition,
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
        Stack(
          children: [
            Positioned(
              top: 10,
              left: leftGlobalX,
              child: ColoredBox(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                child: SizedBox(
                  height: 30,
                  width: selectedAreaWidth ?? 10,
                ),
              ),
            ),
            slider,
          ],
        ),
        Text(_audioPlayerState.toString()),
      ],
    );
  }

  void _initStreams() {
    _durationSubscription = widget.player.onDurationChanged.listen((duration) {
      setState(() => audioLength = duration);
    });

    _positionSubscription = widget.player.onPositionChanged.listen((p) {
      currentPositionDuration = p;

      if (audioLength != null && p.inMilliseconds > 0) {
        final value = p.inMilliseconds / audioLength!.inMilliseconds;
        if (value > 1) {
          setState(() {
            currentPositionDuration = audioLength;
            sliderPosition = 1;
          });
          return;
        }
        setState(() => sliderPosition = value);
        return;
      }
      setState(() => sliderPosition = 0);
    });

    _playerCompleteSubscription = widget.player.onPlayerComplete.listen(
      (event) {
        setState(() {
          widget.playerState = PlayerState.stopped;
          currentPositionDuration = Duration.zero;
        });
      },
    );

    _playerStateChangeSubscription = widget.player.onPlayerStateChanged.listen((state) {
      setState(() {
        _audioPlayerState = state;
      });
    });
  }

  // double _positionValue() {
  //   if (currentPositionDuration != null && audioLength != null && currentPositionDuration!.inMilliseconds > 0) {
  //     final value = currentPositionDuration!.inMilliseconds / audioLength!.inMilliseconds;
  //     if (value > 1) {
  //       currentPositionDuration = audioLength;
  //       return 1;
  //     }
  //     return value;
  //   }
  //   return 0;
  // }

  Future<void> _play() async {
    final position = currentPositionDuration;
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
      currentPositionDuration = Duration.zero;
    });
  }
}
