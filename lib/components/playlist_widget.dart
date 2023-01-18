import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:kikimasu/models/audio_data.dart';
import 'package:kikimasu/models/double_tap_checker.dart';

class _ColumnInfo {
  final String label;
  double width;
  _ColumnInfo(
    this.label, {
    this.width = 50.0,
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
  final List<AudioData> _list = [];
  bool _dragging = false;
  final columnList = [_ColumnInfo("Name"), _ColumnInfo("Path")];
  final verticalScrollController = ScrollController();
  final horizontalScrollController = ScrollController();
  final doubleTapChecker = DoubleTapChecker<AudioData>();
  double columnWidth = 200;
  double initX = 0;

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

  DataColumn _generateColumn(_ColumnInfo columnInfo) {
    return DataColumn(
      onSort: (columnIndex, ascending) {
        if (columnInfo.label == "Name") {
          return _list.sort((a, b) =>
              ascending ? a.name.compareTo(b.name) : b.name.compareTo(a.name));
        }

        if (columnInfo.label == "Path") {
          return _list.sort(((a, b) =>
              ascending ? a.path.compareTo(b.path) : b.path.compareTo(a.path)));
        }
        debugPrint("Sort on undefined label ${columnInfo.label}");
      },
      label: Stack(
        children: [
          Container(
            width: columnInfo.width,
            constraints: const BoxConstraints(minWidth: 200),
            child: Text(columnInfo.label),
          ),
          Positioned(
            right: 0,
            child: GestureDetector(
              child: Container(
                width: 5,
                height: 60.0,
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
      cells: audioData.map((e) => DataCell(
            Text(
              e,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          )),
    );
  }

  Widget _generateDataTable() {
    return DataTable(
      showCheckboxColumn: false,
      columns: columnList.map((e) => _generateColumn(e)).toList(),
      rows: _list.map((e) => _generateDataRow(e)).toList(),
    );
  }
}
