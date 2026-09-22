import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/features/default_wallets/presentation/default_wallets_cubit.dart';
import 'package:bb_mobile/features/default_wallets/ui/screens/default_wallets_screen.dart';
import 'package:bb_mobile/features/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:bb_mobile/features/default_wallets/ui/widgets/default_wallets_scope.dart';
import 'package:flutter/widgets.dart';

export '../default_wallets_locator.dart' show DefaultWalletsLocator;
export '../ui/default_wallets_router.dart'
    show DefaultWalletsRoute, DefaultWalletsRouter;
export '../ui/widgets/default_wallets_editor.dart'
    show DefaultWalletsFooterBuilder;
export 'default_wallets_view_data.dart';

class DefaultWalletsFacade {
  final GetDefaultWalletsUsecase _getDefaultWalletsUsecase;
  final SaveDefaultWalletUsecase _saveDefaultWalletUsecase;
  final DeleteDefaultWalletUsecase _deleteDefaultWalletUsecase;

  const DefaultWalletsFacade({
    required this._getDefaultWalletsUsecase,
    required this._saveDefaultWalletUsecase,
    required this._deleteDefaultWalletUsecase,
  });

  DefaultWalletsCubit _createCubit() => DefaultWalletsCubit(
    getDefaultWalletsUsecase: _getDefaultWalletsUsecase,
    saveDefaultWalletUsecase: _saveDefaultWalletUsecase,
    deleteDefaultWalletUsecase: _deleteDefaultWalletUsecase,
  );

  Widget buildScreen() {
    return DefaultWalletsScope(
      createCubit: _createCubit,
      child: const DefaultWalletsScreen(),
    );
  }

  Widget buildEditor({
    bool showDescription = true,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    DefaultWalletsFooterBuilder? footerBuilder,
  }) {
    return DefaultWalletsScope(
      createCubit: _createCubit,
      child: DefaultWalletsEditor(
        showDescription: showDescription,
        padding: padding,
        footerBuilder: footerBuilder,
      ),
    );
  }
}
