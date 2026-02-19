import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';

class NotificationMessageModel {
  final String type;
  final String? orderId;
  final Map<String, dynamic> rawData;

  NotificationMessageModel.fromJson(Map<String, dynamic> json)
      : type = json['type'] as String? ?? '',
        orderId = json['orderId'] as String?,
        rawData = json;

  NotificationMessage toEntity() => NotificationMessage(
        type: type,
        orderId: orderId,
        rawData: rawData,
      );
}

