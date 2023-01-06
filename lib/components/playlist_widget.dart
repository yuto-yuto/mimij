import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';

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
  final List<XFile> _list = [];
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        final notExistedFiles = detail.files.where(
            (element) => !_list.any((file) => file.path == element.path));
        if (notExistedFiles.isNotEmpty) {
          setState(() {
            _list.addAll(notExistedFiles);
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
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: Container(
        width: double.infinity,
        color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.black26,
        child: Stack(
          children: [
            if (_list.isEmpty)
              const Center(child: Text("Drop here"))
            else
              Text(_list.map((e) => e.path).join("\n")),
          ],
        ),
      ),
    );
  }
}
