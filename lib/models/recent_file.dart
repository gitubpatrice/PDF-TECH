import 'dart:convert';

class RecentFile {
  final String path;
  final String name;
  final DateTime lastOpened;
  final int sizeBytes;

  const RecentFile({
    required this.path,
    required this.name,
    required this.lastOpened,
    required this.sizeBytes,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpened': lastOpened.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory RecentFile.fromJson(Map<String, dynamic> json) => RecentFile(
        path: json['path'] as String,
        name: json['name'] as String,
        lastOpened: DateTime.parse(json['lastOpened'] as String),
        sizeBytes: json['sizeBytes'] as int,
      );

  String toJsonString() => jsonEncode(toJson());
  factory RecentFile.fromJsonString(String s) =>
      RecentFile.fromJson(jsonDecode(s) as Map<String, dynamic>);

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}
