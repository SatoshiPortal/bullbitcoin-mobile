import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';

class NotificationMessageModel {
  static const _kinds = <String, NotificationMessageKind>{
    'balance': NotificationMessageKind.balance,
    'group': NotificationMessageKind.group,
    'kyc': NotificationMessageKind.kyc,
    'userPreferences': NotificationMessageKind.userPreferences,
    'message': NotificationMessageKind.message,
    'order': NotificationMessageKind.order,
    'limitOrder': NotificationMessageKind.limitOrder,
    'user': NotificationMessageKind.user,
  };

  final String type;
  final String? orderId;
  final Map<String, dynamic> rawData;

  NotificationMessageModel.fromJson(Map<String, dynamic> json)
    : type = json['type'] as String? ?? '',
      orderId = json['orderId'] as String?,
      rawData = json;

  NotificationMessage toEntity() => NotificationMessage(
    kind: _kinds[type] ?? NotificationMessageKind.unknown,
    orderId: orderId,
    rawData: rawData,
  );
}
