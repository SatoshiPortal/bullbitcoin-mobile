import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_cubit.dart';
import 'package:bb_mobile/features/limit_orders/ui/screens/create_limit_order_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../limit_orders_locator.dart' show LimitOrdersLocator;
export '../ui/limit_orders_router.dart' show LimitOrdersRouter;

class LimitOrdersFacade {
  final LoadLimitOrderCreationUsecase _loadCreation;
  final GetLimitOrderRateUsecase _getRate;
  final CreateLimitOrderUsecase _create;
  final ResolveWalletAddressUsecase _resolveAddress;
  final ValidateLightningAddressUsecase _validateLnAddress;

  LimitOrdersFacade(
    this._loadCreation,
    this._getRate,
    this._create,
    this._resolveAddress,
    this._validateLnAddress,
  );

  Widget buildCreateScreen() => BlocProvider(
    create: (_) => CreateLimitOrderCubit(
      _loadCreation,
      _getRate,
      _create,
      _resolveAddress,
      _validateLnAddress,
    )..load(),
    child: const CreateLimitOrderScreen(),
  );
}
