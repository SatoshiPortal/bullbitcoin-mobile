import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class LimitOrdersNavigation {
  static const root = '/limit-orders';
  static const createName = 'create';
  static const createPath = '$root/create';
  static const detailsName = 'details';
  static const detailsPath = '$root/:orderId';

  /// The details of [orderId]; answers true when the order changed there
  /// (it was cancelled).
  static Future<bool?> openDetails(BuildContext context, String orderId) =>
      context.pushNamed<bool>(
        detailsName,
        pathParameters: {'orderId': orderId},
      );

  /// The create flow; answers the order it created, if any.
  static Future<LimitOrderCreated?> openCreate(BuildContext context) =>
      context.pushNamed<LimitOrderCreated>(createName);
}

/// What the create flow answers when it created an order: its id, and
/// whether the user asked to see it.
@immutable
final class LimitOrderCreated {
  final String orderId;
  final bool openDetails;

  const LimitOrderCreated(this.orderId, {required this.openDetails});
}
