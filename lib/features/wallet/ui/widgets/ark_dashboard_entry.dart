import 'dart:async';

import 'package:bb_mobile/features/settings/public/network_capability_visibility.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/read_ark_home_usecase.dart';
import '../../presentation/ark_home_cubit.dart';
import '../../presentation/bloc/wallet_bloc.dart';
import '../../domain/wallet.dart' as wallet_model;

class ArkDashboardEntry extends StatelessWidget {
  final ArkForegroundHost? host;
  final int refresh;
  const ArkDashboardEntry({
    super.key,
    required this.host,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    final host = this.host;
    if (host == null) {
      return const SizedBox.shrink();
    }
    final sources = context.select(
      (WalletBloc bloc) => bloc.state.wallets
          .where(
            (wallet) =>
                wallet.isDefault &&
                wallet.network == wallet_model.Network.bitcoinRegtest,
          )
          .map((wallet) => (wallet.id, wallet.masterFingerprint))
          .toList()
          .toString(),
    );
    return NetworkCapabilityVisibility(
      capability: NetworkCapability.ark,
      child: _ArkDashboardCard(
        key: ValueKey(sources),
        host: host,
        refresh: refresh,
      ),
    );
  }
}

class _ArkDashboardCard extends StatefulWidget {
  final ArkForegroundHost host;
  final int refresh;
  const _ArkDashboardCard({
    super.key,
    required this.host,
    required this.refresh,
  });
  @override
  State<_ArkDashboardCard> createState() => _ArkDashboardCardState();
}

class _ArkDashboardCardState extends State<_ArkDashboardCard>
    with WidgetsBindingObserver {
  late ArkHomeCubit _owner;
  late StreamSubscription<Object?> _subscription;

  void _listen() {
    final owner = ArkHomeCubit(ReadArkHomeUsecase(widget.host.homeObservation));
    _owner = owner;
    _subscription = owner.stream.listen((_) {
      if (mounted && identical(owner, _owner)) setState(() {});
    });
    unawaited(owner.load());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(_ArkDashboardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.host, widget.host)) {
      unawaited(_subscription.cancel());
      unawaited(_owner.close());
      _listen();
    } else if (oldWidget.refresh != widget.refresh) {
      unawaited(_owner.load());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    unawaited(_owner.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_owner.load());
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      BullSpacing.sm,
      0,
      BullSpacing.sm,
      BullSpacing.md,
    ),
    child: ArkWalletCard(
      snapshot: _owner.state,
      onOpen: () {
        final snapshot = _owner.state;
        if (snapshot == null || snapshot.stale) {
          ArkNavigation.open(context);
        } else {
          ArkNavigation.account(context, snapshot.account);
        }
      },
    ),
  );
}
