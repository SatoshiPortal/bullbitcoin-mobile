import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

import '../data/ark_repository_impl.dart';
import '../domain/usecases/review_ark_claim_recovery_usecase.dart';
import '../domain/usecases/rebroadcast_ark_claim_usecase.dart';
import '../presentation/ark_claim_recovery_cubit.dart';
import '../presentation/ark_l10n.dart';
import '../ui/ark_claim_recovery_screen.dart';
import 'ark_navigation.dart';

/// Foreground module composition. The host owns the client lifetime; its
/// configured execution mode remains the package's admission authority.
List<GoRoute> createArkClaimRecoveryRoutes({required ArkClient client}) => [
  GoRoute(
    path: '/ark/claim-recovery',
    builder: (context, state) {
      if (state.extra case final ArkClaimRecoveryEntry entry) {
        return _RecoveryPage(client: client, entry: entry);
      }
      final l10n = arkLocalizationsOf(context);
      return BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(
                title: l10n.signedClaimRecovery,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: Center(
                  child: BullText(
                    l10n.nativeUnavailable,
                    role: BullTextRole.body,
                    color: context.bull.error,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
];

class _RecoveryPage extends StatefulWidget {
  final ArkClient client;
  final ArkClaimRecoveryEntry entry;
  const _RecoveryPage({required this.client, required this.entry});
  @override
  State<_RecoveryPage> createState() => _RecoveryPageState();
}

class _RecoveryPageState extends State<_RecoveryPage> {
  late ArkClaimRecoveryCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = _create();
  }

  ArkClaimRecoveryCubit _create() {
    final repository = ArkRepositoryImpl(widget.client);
    return ArkClaimRecoveryCubit(
      ReviewArkClaimRecoveryUsecase(repository),
      RebroadcastArkClaimUsecase(repository),
      account: widget.entry.account,
      operationId: widget.entry.operationId,
    );
  }

  @override
  void didUpdateWidget(_RecoveryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        oldWidget.entry.account != widget.entry.account ||
        oldWidget.entry.operationId != widget.entry.operationId) {
      unawaited(_cubit.close());
      _cubit = _create();
    }
  }

  @override
  void dispose() {
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ArkClaimRecoveryScreen(cubit: _cubit);
}
