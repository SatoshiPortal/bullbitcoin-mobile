import 'dart:async';

import 'package:bb_mobile/core/exchange/data/services/exchange_notification_service.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/list_active_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/presentation/create_limit_order_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_order_details_cubit.dart';
import 'package:bb_mobile/features/limit_orders/presentation/limit_orders_cubit.dart';
import 'package:bb_mobile/features/limit_orders/ui/screens/create_limit_order_screen.dart';
import 'package:bb_mobile/features/limit_orders/ui/screens/limit_order_details_screen.dart';
import 'package:bb_mobile/features/limit_orders/ui/widgets/limit_orders_dashboard_card.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export '../limit_orders_locator.dart' show LimitOrdersLocator;
export '../ui/limit_orders_router.dart'
    show LimitOrdersRoute, LimitOrdersRouter;

class LimitOrdersFacade {
  final ListActiveLimitOrdersUsecase _listActive;
  final CancelAllLimitOrdersUsecase _cancelAll;
  final CanCreateLimitOrderUsecase _canCreate;
  final LoadLimitOrderCreationUsecase _loadCreation;
  final GetLimitOrderRateUsecase _getRate;
  final CreateLimitOrderUsecase _create;
  final GetLimitOrderUsecase _getOrder;
  final CancelLimitOrderUsecase _cancelOrder;
  final ResolveWalletAddressUsecase _resolveAddress;
  final ValidateLightningAddressUsecase _validateLnAddress;
  final ExchangeNotificationService _notifications;

  final _dashboardRefreshRequests = StreamController<void>.broadcast();

  LimitOrdersFacade(
    this._listActive,
    this._cancelAll,
    this._canCreate,
    this._loadCreation,
    this._getRate,
    this._create,
    this._getOrder,
    this._cancelOrder,
    this._resolveAddress,
    this._validateLnAddress,
    this._notifications,
  );

  Widget buildDashboardCard() => BlocProvider(
    create: (_) => LimitOrdersCubit(
      _listActive,
      _cancelAll,
      _canCreate,
      _notifications,
      refreshRequests: _dashboardRefreshRequests.stream,
    )..load(),
    child: const LimitOrdersDashboardCard(),
  );

  void refreshDashboard() => _dashboardRefreshRequests.add(null);

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

  Widget buildDetailsScreen(String id) => BlocProvider(
    create: (_) => LimitOrderDetailsCubit(id, _getOrder, _cancelOrder)..load(),
    child: const LimitOrderDetailsScreen(),
  );
}
