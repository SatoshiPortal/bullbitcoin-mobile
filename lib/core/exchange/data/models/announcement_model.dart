import 'package:bb_mobile/core/exchange/domain/entity/announcement.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement_model.freezed.dart';
part 'announcement_model.g.dart';

@freezed
sealed class AnnouncementModel with _$AnnouncementModel {
  const factory AnnouncementModel({
    required String title,
    required String description,
    required String updatedAt,
  }) = _AnnouncementModel;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementModelFromJson(json);

  const AnnouncementModel._();

  Announcement toEntity() {
    return Announcement(
      title: title,
      description: description,
      updatedAt: DateTime.parse(updatedAt),
    );
  }
}

