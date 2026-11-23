import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart' show Outpoint;
import 'package:sync/sync.dart' show WalletKey;

import 'send_route_args.dart';

enum SendRoute {
  send('/send');

  const SendRoute(this.path);

  final String path;
}

abstract final class SendNavigation {
  static Future<void> open(BuildContext context, {WalletKey? wallet}) =>
      context.pushNamed<void>(
        SendRoute.send.name,
        extra: SendRouteArgs(wallet: wallet),
      );

  static Future<void> openSilent(BuildContext context) => context
      .pushNamed<void>(SendRoute.send.name, extra: const SendRouteArgs.sp());

  static Future<void> openSelected(
    BuildContext context,
    WalletKey wallet,
    Set<Outpoint> outpoints,
  ) => context.pushNamed<void>(
    SendRoute.send.name,
    extra: SendRouteArgs.selected(wallet: wallet, outpoints: outpoints),
  );

  static Future<void> openSweep(
    BuildContext context,
    WalletKey wallet,
    Set<Outpoint> outpoints,
  ) => context.pushNamed<void>(
    SendRoute.send.name,
    extra: SendRouteArgs.sweep(wallet: wallet, outpoints: outpoints),
  );
}
