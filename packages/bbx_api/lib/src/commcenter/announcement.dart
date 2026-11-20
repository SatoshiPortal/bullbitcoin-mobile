import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  factory Announcement.fromJson(Map<String, dynamic> json) {
    final updatedAt = DateTime.tryParse(
      read<String>(json['updatedAt'], 'updatedAt'),
    );
    if (updatedAt == null) {
      throw const BbxApiFormatException('invalid updatedAt');
    }
    return Announcement(
      title: read<String>(json['title'], 'title'),
      description: read<String>(json['description'], 'description'),
      updatedAt: updatedAt,
    );
  }
}
