import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class LimitOrdersNavigation {
  static const createName = 'create';
  static const createPath = '/limit-orders/create';
  static const detailsName = 'details';
  static const detailsPath = '/limit-orders/:orderId';

  static Future<bool?> openDetails(BuildContext context, String orderId) =>
      context.pushNamed<bool>(
        detailsName,
        pathParameters: {'orderId': orderId},
      );
}
