class DoubleTapChecker<T> {
  T? _lastSelectedItem;
  DateTime _lastTimestamp = DateTime.now();
  final double doubleTapDuration;

  DoubleTapChecker({this.doubleTapDuration = 400});

  bool isDoubleTap(T item) {
    if (_lastSelectedItem == null || _lastSelectedItem != item) {
      _lastSelectedItem = item;
      _lastTimestamp = DateTime.now();
      return false;
    }

    final currentTimestamp = DateTime.now();
    final duration = currentTimestamp.difference(_lastTimestamp).inMilliseconds;
    _lastTimestamp = DateTime.now();
    return duration < doubleTapDuration;
  }
}
