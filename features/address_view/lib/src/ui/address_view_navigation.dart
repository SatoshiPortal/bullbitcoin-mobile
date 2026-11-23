import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'address_view_route.dart';

abstract final class AddressViewNavigation {
  static Future<void> open(BuildContext context, {required String walletId}) =>
      context.pushNamed<void>(
        AddressViewRoute.name,
        pathParameters: {'walletId': walletId},
      );
}
