class AudioData {
  final String name;
  final String path;
  AudioData({
    required this.name,
    required this.path,
  });

  List<T> mapIndexed<T>(T Function(int index, String e) toElement) {
    return [
      toElement(0, name),
      toElement(1, path),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is AudioData && other.hashCode == hashCode;
  }

  @override
  int get hashCode => Object.hash(name, path);
}
