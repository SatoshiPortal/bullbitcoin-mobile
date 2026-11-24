import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class LimitOrdersNavigation {
  static const root = '/limit-orders';
  static const createName = 'create';
  static const createPath = '$root/create';
  static const detailsName = 'details';
  static const detailsPath = '$root/:orderId';

  static Future<bool?> openDetails(BuildContext context, String orderId) =>
      context.pushNamed<bool>(
        detailsName,
        pathParameters: {'orderId': orderId},
      );
}
