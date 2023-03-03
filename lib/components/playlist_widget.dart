import 'dart:io';
import 'dart:math';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:kikimasu/models/audio_data.dart';
import 'package:kikimasu/models/double_tap_checker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

const _minimumWidth = 50.0;

class _ColumnInfo {
  final String label;
  double width;
  _ColumnInfo(
    this.label, {
    this.width = _minimumWidth,
  });
}

typedef OnDoubleTapCallback = void Function(AudioData data);

class PlayListWidget extends StatefulWidget {
  final String title;
  final OnDoubleTapCallback? onDoubleTap;

  const PlayListWidget({
    super.key,
    this.onDoubleTap,
    this.title = "Undefined",
  });

  @override
  State<StatefulWidget> createState() {
    return _PlayListWidgetState();
  }
}

class _PlayListWidgetState extends State<PlayListWidget> {
  final List<AudioData> _list = [];
  bool _dragging = false;
  final columnList = [_ColumnInfo("Name", width: 200), _ColumnInfo("Path", width: 100)];
  final verticalScrollController = ScrollController();
  final horizontalScrollController = ScrollController();
  final doubleTapChecker = DoubleTapChecker<AudioData>();
  double columnInitX = 0;
  bool isAsc = true;
  int sortColumnIndex = 0;
  final Map<AudioData, bool> selectedList = <AudioData, bool>{};
  late Future<bool> hasReadSharedPref;
  final dataStoreKey = "audioPath";
  final focusNodeForDataTable = FocusNode();
  bool isControlPressed = false;
  bool isShiftPressed = false;
  int? lastSelectedRowIndex;

  @override
  void initState() {
    super.initState();
    hasReadSharedPref = SharedPreferences.getInstance().then((value) {
      final list = value.getStringList(dataStoreKey) ?? [];
      _list.addAll(list.map((e) {
        final audioData = AudioData(name: path.basename(e), path: File(e).parent.path);
        selectedList[audioData] = false;
        return audioData;
      }).toList());
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        final notExistedFiles = detail.files
            .where((element) => !_list.any((audio) => path.join(audio.path, audio.name) == element.path))
            .toList();
        if (notExistedFiles.isNotEmpty) {
          setState(() {
            _list.addAll(
              notExistedFiles.map((e) => AudioData(name: e.name, path: File(e.path).parent.path)),
            );
            for (var element in _list) {
              selectedList[element] = false;
            }
          });
          final shared = await SharedPreferences.getInstance();
          final currentList = shared.getStringList(dataStoreKey) ?? [];
          currentList.addAll(notExistedFiles.map((e) => e.path).toList());
          await shared.setStringList(dataStoreKey, currentList);
        }

        debugPrint('onDragDone:');
        for (final file in detail.files) {
          debugPrint('  ${file.path} ${file.name}'
              '  ${await file.lastModified()}'
              '  ${await file.length()}'
              '  ${file.mimeType}');
        }
      },
      onDragEntered: (detail) {
        setState(() => _dragging = true);
      },
      onDragExited: (detail) {
        setState(() => _dragging = false);
      },
      child: KeyboardListener(
        autofocus: true,
        focusNode: focusNodeForDataTable,
        onKeyEvent: _bindShiftCtrlKey,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(color: Theme.of(context).primaryColorDark.withOpacity(0.6)),
              BoxShadow(
                spreadRadius: -4.0,
                blurRadius: 3.0,
                color:
                    _dragging ? Theme.of(context).primaryColorDark.withAlpha(5) : Theme.of(context).primaryColorLight,
              ),
            ],
            shape: BoxShape.rectangle,
            borderRadius: const BorderRadius.all(
              Radius.circular(10),
            ),
          ),
          child: FutureBuilder(
            future: hasReadSharedPref,
            builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
              if (!snapshot.hasData || _list.isEmpty) {
                return const Center(child: Text("Drop here"));
              }
              return _generateCrossScrollbars(_generateDataTable(context));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _bindShiftCtrlKey(KeyEvent value) async {
    if (value.logicalKey == LogicalKeyboardKey.controlLeft || value.logicalKey == LogicalKeyboardKey.controlRight) {
      setState(() {
        isControlPressed = value is KeyDownEvent ? true : false;
      });
    } else if (value.logicalKey == LogicalKeyboardKey.shiftLeft || value.logicalKey == LogicalKeyboardKey.shiftRight) {
      setState(() {
        isShiftPressed = value is KeyDownEvent
            ? true
            : value is KeyUpEvent
                ? false
                : isShiftPressed;
      });
    } else if (value.logicalKey == LogicalKeyboardKey.delete) {
      if (value is! KeyDownEvent) {
        return;
      }

      final selectedRows = selectedList.entries.where((element) => element.value);
      if (selectedRows.isEmpty) {
        return;
      }

      final shared = await SharedPreferences.getInstance();
      final currentList = shared.getStringList(dataStoreKey) ?? [];
      setState(() {
        for (final entry in selectedRows) {
          selectedList.remove(entry);
          _list.remove(entry.key);
          final fullpath = path.join(entry.key.path, entry.key.name);
          currentList.remove(fullpath);
        }
      });
      await shared.setStringList(dataStoreKey, currentList);
    }
  }

  Widget _generateCrossScrollbars(Widget child) {
    return Scrollbar(
      controller: verticalScrollController,
      thumbVisibility: true,
      trackVisibility: true,
      child: Scrollbar(
        controller: horizontalScrollController,
        thumbVisibility: true,
        trackVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: verticalScrollController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: child,
          ),
        ),
      ),
    );
  }

  DataColumn _generateDataColumn(BuildContext context, _ColumnInfo columnInfo) {
    return DataColumn(
      onSort: (columnIndex, ascending) {
        setState(() {
          sortColumnIndex = columnIndex;
          isAsc = ascending;

          if (columnIndex == 0) {
            debugPrint("0, $ascending, $isAsc");
            _list.sort((a, b) => ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
          } else if (columnIndex == 1) {
            debugPrint("1, $ascending, $isAsc");
            _list.sort((a, b) => ascending ? a.path.compareTo(b.path) : b.path.compareTo(a.path));
          }
        });
      },
      label: Stack(
        children: [
          Container(
            width: columnInfo.width,
            constraints: const BoxConstraints(minWidth: _minimumWidth),
            child: Text(
              columnInfo.label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          Positioned(
            right: 0,
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  columnInitX = details.globalPosition.dx;
                });
              },
              onPanUpdate: (details) {
                final increment = details.globalPosition.dx - columnInitX;
                final newWidth = columnInfo.width + increment;
                debugPrint(newWidth.toString());
                setState(() {
                  if (newWidth > _minimumWidth) {
                    columnInitX = details.globalPosition.dx;
                    columnInfo.width = newWidth;
                  } else {
                    columnInfo.width = _minimumWidth;
                  }
                });
              },
              child: Container(
                width: 22.0,
                height: 22.0,
                decoration: BoxDecoration(
                  color: Theme.of(context).indicatorColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    "<>",
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  DataRow _generateDataRow(BuildContext context, AudioData audioData) {
    return DataRow(
      color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
        if (states.contains(MaterialState.selected)) {
          return Theme.of(context).primaryColor.withOpacity(0.3);
        }
        return null; // Use the default value.
      }),
      selected: selectedList[audioData]!,
      onSelectChanged: (bool? selected) {
        final isDoubleTap = doubleTapChecker.isDoubleTap(audioData);
        if (widget.onDoubleTap != null && isDoubleTap) {
          final selectedRows = _list.where((element) => selectedList[element]!);
          setState(() {
            for (final row in selectedRows) {
              selectedList[row] = false;
            }
            selectedList[audioData] = selected ?? false;
            widget.onDoubleTap!(audioData);
          });
          return;
        }

        final currentIndex = _list.indexOf(audioData);

        if (!isControlPressed && !isShiftPressed) {
          final selectedRows = _list.where((element) => selectedList[element]!);
          setState(() {
            for (final row in selectedRows) {
              selectedList[row] = false;
            }
            selectedList[audioData] = selected ?? false;
          });
        } else if (isControlPressed) {
          setState(() {
            selectedList[audioData] = selected ?? false;
          });
        } else {
          if (lastSelectedRowIndex == null) {
            setState(() {
              selectedList[audioData] = selected ?? false;
            });
          } else {
            final diff = lastSelectedRowIndex! - currentIndex;
            final selectedIndexes = List.generate(
              diff.abs() + 1,
              (index) => index + min(lastSelectedRowIndex!, currentIndex),
            );
            setState(() {
              for (int i = 0; i < selectedList.length; i++) {
                selectedList[_list[i]] = selectedIndexes.contains(i) ? true : false;
              }
            });
            return;
          }
        }
      },
      cells: audioData.mapIndexed(
        (index, e) => DataCell(
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: _minimumWidth,
              maxWidth: columnList[index].width,
            ),
            child: Text(
              e,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }

  Widget _generateDataTable(BuildContext context) {
    return DataTable(
      sortAscending: isAsc,
      sortColumnIndex: sortColumnIndex,
      showCheckboxColumn: false,
      columns: columnList.map((e) => _generateDataColumn(context, e)).toList(),
      rows: _list.map((e) => _generateDataRow(context, e)).toList(),
    );
  }
}
