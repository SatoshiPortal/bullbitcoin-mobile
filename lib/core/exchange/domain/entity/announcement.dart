import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';

@freezed
sealed class Announcement with _$Announcement {
  const factory Announcement({
    required String title,
    required String description,
    required DateTime updatedAt,
  }) = _Announcement;

  const Announcement._();
}

