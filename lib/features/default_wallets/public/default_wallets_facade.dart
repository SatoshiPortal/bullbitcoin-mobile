import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/ui/screens/default_wallets_screen.dart';
import 'package:bb_mobile/features/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../ui/default_wallets_router.dart'
    show DefaultWalletsRoute, DefaultWalletsRouter;
export '../ui/widgets/default_wallets_editor.dart'
    show DefaultWalletsFooterBuilder;

class DefaultWalletsFacade {
  final Exchange _exchange;

  const DefaultWalletsFacade(this._exchange);

  Widget buildScreen() => _provide(const DefaultWalletsScreen());

  Widget buildEditor({
    bool? showDescription,
    EdgeInsetsGeometry? padding,
    DefaultWalletsFooterBuilder? footerBuilder,
  }) => _provide(
    DefaultWalletsEditor(
      showDescription: showDescription,
      padding: padding,
      footerBuilder: footerBuilder,
    ),
  );

  Widget _provide(Widget child) => BlocProvider<DefaultWalletsCubit>(
    create: (_) => DefaultWalletsCubit(exchange: _exchange)..init(),
    child: child,
  );
}
