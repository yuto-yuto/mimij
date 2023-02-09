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

class _CurrentPosition {
  Duration? currentDuration;
  double? sliderPosition;

  void clear() {
    currentDuration = null;
    sliderPosition = null;
  }
}

class _PlayerWidgetState extends State<PlayerWidget> with WidgetsBindingObserver {
  Duration? audioLength;
  Duration? currentPositionDuration;
  _CurrentPosition startRelativeX = _CurrentPosition();
  _CurrentPosition endRelativeX = _CurrentPosition();
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
  }

  set leftGlobalX(double? value) {
    if (value != null) {
      _leftGlobalX = value + _sliderPadding;
    } else {
      _leftGlobalX = null;
    }
  }

  double? get leftGlobalX => _leftGlobalX;

  set rightGlobalX(double? value) {
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
        leftGlobalX = startRelativeX.sliderPosition! * sliderWidth;
        selectedAreaWidth = sliderWidth * (1 - startRelativeX.sliderPosition!);
      });
    } else if (_leftGlobalX == null && _rightGlobalX != null) {
      setState(() {
        rightGlobalX = endRelativeX.sliderPosition! * sliderWidth;
        selectedAreaWidth = _rightGlobalX!;
      });
    } else if (_leftGlobalX != null && _rightGlobalX != null) {
      setState(() {
        leftGlobalX = startRelativeX.sliderPosition! * sliderWidth;
        rightGlobalX = endRelativeX.sliderPosition! * sliderWidth;
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
            if (endRelativeX.sliderPosition == null) {
              if (startRelativeX.sliderPosition == sliderPosition) {
                setState(() {
                  startRelativeX.clear();
                  leftGlobalX = null;
                  selectedAreaWidth = null;
                });
              } else {
                setState(() {
                  startRelativeX.sliderPosition = sliderPosition;
                  startRelativeX.currentDuration = currentPositionDuration ?? Duration.zero;
                  leftGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = sliderWidth * (1 - sliderPosition);
                });
              }
              return;
            }

            if (endRelativeX.sliderPosition! <= sliderPosition) {
              if (startRelativeX.currentDuration != null) {
                setState(() {
                  startRelativeX.clear();
                  leftGlobalX = null;
                  selectedAreaWidth = rightGlobalX!;
                });
              }
              return;
            }

            if (startRelativeX.sliderPosition == sliderPosition) {
              setState(() {
                startRelativeX.clear();
                leftGlobalX = null;
                selectedAreaWidth = rightGlobalX!;
              });
              return;
            }

            if (endRelativeX.sliderPosition! > sliderPosition) {
              setState(() {
                startRelativeX.sliderPosition = sliderPosition;
                startRelativeX.currentDuration = currentPositionDuration;
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
            if (startRelativeX.currentDuration == null) {
              setState(() {
                if (endRelativeX.sliderPosition == sliderPosition) {
                  endRelativeX.clear();
                  rightGlobalX = null;
                  selectedAreaWidth = null;
                } else {
                  endRelativeX.sliderPosition = sliderPosition;
                  endRelativeX.currentDuration = currentPositionDuration;
                  rightGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = rightGlobalX;
                }
              });
              return;
            }

            if (startRelativeX.sliderPosition! >= sliderPosition || endRelativeX.sliderPosition == sliderPosition) {
              if (endRelativeX.currentDuration != null) {
                setState(() {
                  endRelativeX.clear();
                  rightGlobalX = null;
                  selectedAreaWidth = sliderWidth * (1 - startRelativeX.sliderPosition!);
                });
              }
              return;
            }

            if (startRelativeX.sliderPosition! < sliderPosition) {
              setState(() {
                endRelativeX.sliderPosition = sliderPosition;
                endRelativeX.currentDuration = currentPositionDuration;
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
        if (startRelativeX.sliderPosition != null && startRelativeX.sliderPosition! > v) {
          setState(() {
            sliderPosition = startRelativeX.sliderPosition!;
          });
          return;
        }
        if (endRelativeX.sliderPosition != null && endRelativeX.sliderPosition! < v) {
          setState(() {
            sliderPosition = endRelativeX.sliderPosition!;
          });
          return;
        }

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

      if (endRelativeX.currentDuration != null && endRelativeX.currentDuration! < p) {
        widget.player.seek(startRelativeX.currentDuration ?? Duration.zero);
        setState(() => sliderPosition = 0);
        return;
      }
      if (startRelativeX.currentDuration != null) {
        // loop when the audio almost finishes
        final rest = audioLength!.inMilliseconds - p.inMilliseconds;
        if (rest < 100) {
          setState(() {
            sliderPosition = startRelativeX.sliderPosition!;
            currentPositionDuration = startRelativeX.currentDuration;
            widget.player.seek(startRelativeX.currentDuration!);
          });
        }
      }

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
      debugPrint(state.name);
      setState(() {
        _audioPlayerState = state;
      });
    });
  }

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
