import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/autobuy/presentation/autobuy_cubit.dart';
import 'package:bb_mobile/features/autobuy/ui/screens/autobuy_screen.dart';
import 'package:bb_mobile/features/autobuy/ui/widgets/autobuy_home_card.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../autobuy_locator.dart' show AutoBuyLocator;
export '../ui/autobuy_router.dart' show AutoBuyRoute, AutoBuyRouter;

class AutoBuyFacade {
  final SetAutoBuyUsecase _setAutoBuyUsecase;
  final GetAutoBuyStatusUsecase _getAutoBuyStatusUsecase;
  final DefaultWalletsFacade _defaultWalletsFacade;

  const AutoBuyFacade(
    this._setAutoBuyUsecase,
    this._getAutoBuyStatusUsecase,
    this._defaultWalletsFacade,
  );

  Widget buildHomeCard({
    required bool isActive,
    required bool isRestricted,
    required VoidCallback onActivate,
    required Future<void> Function() onStatusChanged,
  }) => BlocProvider<AutoBuyCubit>(
    create: (_) => _createCubit(),
    child: AutoBuyHomeCard(
      isActive: isActive,
      isRestricted: isRestricted,
      onActivate: onActivate,
      onStatusChanged: onStatusChanged,
    ),
  );

  Widget buildScreen() => BlocProvider<AutoBuyCubit>(
    create: (_) => _createCubit()..loadStatus(),
    child: AutoBuyScreen(defaultWalletsFacade: _defaultWalletsFacade),
  );

  AutoBuyCubit _createCubit({
    bool isActive = false,
    bool isRestricted = true,
  }) => AutoBuyCubit(
    _setAutoBuyUsecase,
    _getAutoBuyStatusUsecase,
    isActive: isActive,
    isRestricted: isRestricted,
  );
}
