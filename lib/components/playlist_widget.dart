import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:kikimasu/models/audio_data.dart';
import 'package:kikimasu/models/double_tap_checker.dart';

const _minimumWidth = 50.0;

class _ColumnInfo {
  final String label;
  double width;
  _ColumnInfo(
    this.label, {
    this.width = _minimumWidth,
  });
}

class PlayListWidget extends StatefulWidget {
  final String title;

  const PlayListWidget({
    super.key,
    this.title = "Undefined",
  });

  @override
  State<StatefulWidget> createState() {
    return _PlayListWidgetState();
  }
}

class _PlayListWidgetState extends State<PlayListWidget> {
  List<AudioData> _list = [];
  bool _dragging = false;
  final columnList = [_ColumnInfo("Name"), _ColumnInfo("Path")];
  final verticalScrollController = ScrollController();
  final horizontalScrollController = ScrollController();
  final doubleTapChecker = DoubleTapChecker<AudioData>();
  double columnInitX = 0;
  bool isAsc = true;
  int sortColumnIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        final notExistedFiles = detail.files.where(
            (element) => !_list.any((file) => file.path == element.path));
        if (notExistedFiles.isNotEmpty) {
          setState(() {
            _list.addAll(
              notExistedFiles.map((e) =>
                  AudioData(name: e.name, path: File(e.path).parent.path)),
            );
          });
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
      child: Container(
        width: double.infinity,
        color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.cyan[100],
        child: Stack(
          children: [
            if (_list.isEmpty)
              const Center(child: Text("Drop here"))
            else
              _generateCrossScrollbars(_generateDataTable()),
          ],
        ),
      ),
    );
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

  DataColumn _generateDataColumn(_ColumnInfo columnInfo) {
    return DataColumn(
      onSort: (columnIndex, ascending) {
        setState(() {
          sortColumnIndex = columnIndex;
          isAsc = ascending;

          if (columnIndex == 0) {
            debugPrint("0, $ascending, $isAsc");
            _list.sort((a, b) => ascending
                ? a.name.compareTo(b.name)
                : b.name.compareTo(a.name));
          } else if (columnIndex == 1) {
            debugPrint("1, $ascending, $isAsc");
            _list.sort((a, b) => ascending
                ? a.path.compareTo(b.path)
                : b.path.compareTo(a.path));
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
                width: 10.0,
                height: 50.0,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(1),
                  shape: BoxShape.rectangle,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  DataRow _generateDataRow(AudioData audioData) {
    return DataRow(
      onSelectChanged: (bool? selected) {
        setState(() {
          if (doubleTapChecker.isDoubleTap(audioData)) {
            debugPrint("Double tapped ${audioData.name}, ${audioData.path}");
            return;
          }
        });
      },
      cells: audioData.mapIndexed(
        (index, e) => DataCell(
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: columnList[index].width),
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

  Widget _generateDataTable() {
    return DataTable(
      sortAscending: isAsc,
      sortColumnIndex: sortColumnIndex,
      showCheckboxColumn: false,
      columns: columnList.map((e) => _generateDataColumn(e)).toList(),
      rows: _list.map((e) => _generateDataRow(e)).toList(),
    );
  }
}
