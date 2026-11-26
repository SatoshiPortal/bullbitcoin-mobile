import 'package:meta/meta.dart';

/// An entry of `listAnnouncements`.
@immutable
class Announcement {
  final String title;
  final String description;
  final DateTime updatedAt;

  const Announcement({
    required this.title,
    required this.description,
    required this.updatedAt,
  });
}
