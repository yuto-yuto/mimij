import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackIntent extends Intent {}

class BigBackIntent extends Intent {}

class SkipIntent extends Intent {}

class BigSkipIntent extends Intent {}

class ResumeIntent extends Intent {}

class PlayerWidget extends StatefulWidget {
  final AudioPlayer player;

  const PlayerWidget({
    super.key,
    required this.player,
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

  get isNull => currentDuration == null;

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
  bool isAPressed = false;
  bool isBPressed = false;
  double volume = 1;
  late Future<double> initialVolume;
  bool isInitialVolumeSet = false;
  bool isCurrentAudioLoop = false;
  final volumeStoreKey = "VolumeStoreKey";

  PlayerState? _audioPlayerState;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  bool get _isPlaying => _audioPlayerState == PlayerState.playing;
  bool get _isPaused => _audioPlayerState == PlayerState.paused;
  bool get _isStopped => _audioPlayerState == PlayerState.stopped;

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
    initialVolume = SharedPreferences.getInstance().then((value) {
      return value.getDouble(volumeStoreKey) ?? 1;
    });
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
        // IconButton(
        //   key: const Key("previous_button"),
        //   onPressed: () => {},
        //   iconSize: _iconSize,
        //   icon: const Icon(Icons.keyboard_double_arrow_left),
        //   color: Colors.cyan,
        // ),
        IconButton(
          key: const Key('play_button'),
          onPressed: _isPlaying ? null : _play,
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
        // IconButton(
        //   key: const Key("next_button"),
        //   onPressed: () => {},
        //   iconSize: _iconSize,
        //   icon: const Icon(Icons.keyboard_double_arrow_right),
        //   color: Colors.cyan,
        // ),
        IconButton(
          key: const Key("from_here_button"),
          onPressed: () {
            if (audioLength == null) {
              return;
            }
            if (endRelativeX.isNull) {
              if (startRelativeX.isNull) {
                setState(() {
                  startRelativeX.sliderPosition = sliderPosition;
                  startRelativeX.currentDuration = currentPositionDuration ?? Duration.zero;
                  leftGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = sliderWidth * (1 - sliderPosition);
                  isAPressed = !isAPressed;
                });
              } else {
                setState(() {
                  startRelativeX.clear();
                  leftGlobalX = null;
                  selectedAreaWidth = null;
                  isAPressed = !isAPressed;
                });
              }
            } else if (startRelativeX.isNull) {
              setState(() {
                startRelativeX.sliderPosition = sliderPosition;
                startRelativeX.currentDuration = currentPositionDuration;
                leftGlobalX = sliderWidth * sliderPosition;
                selectedAreaWidth = rightGlobalX! - leftGlobalX!;
                isAPressed = !isAPressed;
              });
            } else {
              setState(() {
                startRelativeX.clear();
                leftGlobalX = null;
                selectedAreaWidth = rightGlobalX!;
                isAPressed = !isAPressed;
              });
            }
          },
          iconSize: _iconSize,
          icon: const Icon(Icons.subdirectory_arrow_right),
          color: isAPressed ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
        ),
        IconButton(
          key: const Key("to_here_button"),
          onPressed: () {
            if (audioLength == null) {
              return;
            }
            if (startRelativeX.isNull) {
              if (endRelativeX.isNull) {
                setState(() {
                  endRelativeX.sliderPosition = sliderPosition;
                  endRelativeX.currentDuration = currentPositionDuration;
                  rightGlobalX = sliderWidth * sliderPosition;
                  selectedAreaWidth = rightGlobalX;
                  isBPressed = !isBPressed;
                });
              } else {
                setState(() {
                  endRelativeX.clear();
                  rightGlobalX = null;
                  selectedAreaWidth = null;
                  isBPressed = !isBPressed;
                });
              }
            } else if (endRelativeX.isNull) {
              setState(() {
                endRelativeX.sliderPosition = sliderPosition;
                endRelativeX.currentDuration = currentPositionDuration;
                rightGlobalX = sliderWidth * sliderPosition;
                selectedAreaWidth = rightGlobalX! - leftGlobalX!;
                isBPressed = !isBPressed;
              });
            } else {
              setState(() {
                endRelativeX.clear();
                rightGlobalX = null;
                selectedAreaWidth = sliderWidth * (1 - startRelativeX.sliderPosition!);
                isBPressed = !isBPressed;
              });
            }
          },
          iconSize: _iconSize,
          icon: const Icon(Icons.subdirectory_arrow_left),
          color: isBPressed ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
        ),
        IconButton(
          key: const Key("one_loop_button"),
          onPressed: () => setState(() => isCurrentAudioLoop = !isCurrentAudioLoop),
          iconSize: _iconSize,
          icon: const Icon(Icons.loop),
          color: isCurrentAudioLoop ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
        ),
      ],
    );

    final slider = Slider(
      key: _keyForSlider,
      onChanged: _onChangedAudioSlider,
      value: sliderPosition,
    );

    final currentPosition = Text(
      '$_positionText / $_durationText',
      style: const TextStyle(fontSize: 16.0),
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.keyA): BigBackIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): BackIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyD): SkipIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): BigSkipIntent(),
        LogicalKeySet(LogicalKeyboardKey.space): ResumeIntent(),
      },
      child: Actions(
        actions: {
          BigBackIntent: CallbackAction(onInvoke: (intent) => _backInSec(5)),
          BackIntent: CallbackAction(onInvoke: (intent) => _backInSec(2)),
          SkipIntent: CallbackAction(onInvoke: (intent) => _skipInSec(2)),
          BigSkipIntent: CallbackAction(onInvoke: (intent) => _skipInSec(5)),
          ResumeIntent: CallbackAction(onInvoke: (intent) {
            if (_isPaused || _isStopped) {
              widget.player.resume();
            } else {
              widget.player.pause();
            }
            return null;
          }),
        },
        child: Column(
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
                      width: selectedAreaWidth,
                    ),
                  ),
                ),
                slider,
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 70, child: Center(child: Text("Volume"))),
                Expanded(
                  child: FutureBuilder(
                    future: initialVolume,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && !isInitialVolumeSet) {
                        volume = snapshot.data!;
                        isInitialVolumeSet = true;
                      }
                      final volumeSlider = Slider(
                        onChanged: (double v) async {
                          widget.player.setVolume(v);
                          setState(() => volume = v);
                          final shared = await SharedPreferences.getInstance();
                          shared.setDouble(volumeStoreKey, v);
                        },
                        value: volume,
                      );
                      return volumeSlider;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _initStreams() {
    _durationSubscription = widget.player.onDurationChanged.listen((duration) {
      setState(() => audioLength = duration);
    });

    _positionSubscription = widget.player.onPositionChanged.listen((p) {
      if (audioLength == null) {
        return;
      }
      currentPositionDuration = p;

      final isEndPositionOver = endRelativeX.currentDuration != null && endRelativeX.currentDuration! <= p;

      if (isEndPositionOver) {
        widget.player.seek(startRelativeX.currentDuration ?? Duration.zero);
        setState(() => sliderPosition = 0);
        return;
      }
      // loop when the audio almost finishes
      final rest = audioLength!.inMilliseconds - p.inMilliseconds;
      if (rest <= 1000) {
        if (startRelativeX.currentDuration != null) {
          setState(() {
            sliderPosition = startRelativeX.sliderPosition!;
            currentPositionDuration = startRelativeX.currentDuration;
          });
          widget.player.seek(startRelativeX.currentDuration!);
        } else if (isCurrentAudioLoop) {
          widget.player.seek(Duration.zero);
          setState(() => sliderPosition = 0);
        }
      }

      if (audioLength != null && p.inMilliseconds > 0) {
        final value = p.inMilliseconds / audioLength!.inMilliseconds;

        if (value > 1) {
          setState(() {
            currentPositionDuration = audioLength;
            sliderPosition = 1;
          });
        } else {
          setState(() => sliderPosition = value);
        }
        return;
      }
      setState(() => sliderPosition = 0);
    });

    _playerCompleteSubscription = widget.player.onPlayerComplete.listen(
      (event) {
        setState(() {
          _audioPlayerState = PlayerState.stopped;
          currentPositionDuration = Duration.zero;
          sliderPosition = 0;
        });
      },
    );

    _playerStateChangeSubscription = widget.player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        return;
      }

      debugPrint(state.name);
      setState(() {
        _audioPlayerState = state;
      });
    });
  }

  void _onChangedAudioSlider(double v) {
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
  }

  Future<void> _play() async {
    final position = currentPositionDuration;
    if (position != null && position.inMilliseconds > 0) {
      await widget.player.seek(position);
    }
    await widget.player.resume();
    setState(() => _audioPlayerState = PlayerState.playing);
  }

  Future<void> _pause() async {
    await widget.player.pause();
    setState(() => _audioPlayerState = PlayerState.paused);
  }

  Future<void> _stop() async {
    await widget.player.stop();
    setState(() {
      _audioPlayerState = PlayerState.stopped;
      currentPositionDuration = Duration.zero;
      startRelativeX.clear();
      endRelativeX.clear();
      isAPressed = false;
      isBPressed = false;
      leftGlobalX = null;
      rightGlobalX = null;
      selectedAreaWidth = null;
    });
  }

  void _backInSec(int sec) {
    if (currentPositionDuration == null || audioLength == null) {
      return;
    }
    final minusSec = currentPositionDuration!.inSeconds < sec ? 0 : currentPositionDuration!.inSeconds - sec;
    widget.player.seek(Duration(seconds: minusSec));
  }

  void _skipInSec(int sec) {
    if (currentPositionDuration == null || audioLength == null) {
      return;
    }
    final plusSec = audioLength!.inSeconds - currentPositionDuration!.inSeconds < sec
        ? audioLength!.inSeconds
        : currentPositionDuration!.inSeconds + sec;
    widget.player.seek(Duration(seconds: plusSec));
  }
}
