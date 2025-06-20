// lib/recap_model.dart
enum RecapType { weekly, monthly }

class Recap {
  final String id;
  final String title;
  final String filePath;
  final RecapType type;
  final DateTime dateGenerated;

  Recap({
    required this.id,
    required this.title,
    required this.filePath,
    required this.type,
    required this.dateGenerated,
  });
}
