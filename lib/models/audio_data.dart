class AudioData {
  final String name;
  final String path;
  AudioData({
    required this.name,
    required this.path,
  });

  List<T> map<T>(T Function(String e) toElement) {
    return [
      toElement(name),
      toElement(path),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is AudioData && other.hashCode == hashCode;
  }

  @override
  int get hashCode => Object.hash(name, path);
}
