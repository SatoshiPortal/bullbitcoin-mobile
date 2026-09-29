import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/ui/screens/default_wallets_screen.dart';
import 'package:bb_mobile/features/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart'
    show DefaultWallet, DefaultWallets, WalletAddressType;

export '../default_wallets_locator.dart' show DefaultWalletsLocator;
export '../ui/default_wallets_router.dart'
    show DefaultWalletsRoute, DefaultWalletsRouter;
export '../ui/widgets/default_wallets_editor.dart'
    show DefaultWalletsFooterBuilder;

class DefaultWalletsFacade {
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final SaveDefaultWalletUsecase _saveDefaultWalletUsecase;
  final DeleteDefaultWalletUsecase _deleteDefaultWalletUsecase;

  const DefaultWalletsFacade({
    required this._getDefaultWalletsUsecase,
    required this._saveDefaultWalletUsecase,
    required this._deleteDefaultWalletUsecase,
  });

  Future<DefaultWallets> getDefaultWallets() =>
      _getDefaultWalletsUsecase.execute();

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
    create: (_) => DefaultWalletsCubit(
      getDefaultWalletsUsecase: _getDefaultWalletsUsecase,
      saveDefaultWalletUsecase: _saveDefaultWalletUsecase,
      deleteDefaultWalletUsecase: _deleteDefaultWalletUsecase,
    )..init(),
    child: child,
  );
}
