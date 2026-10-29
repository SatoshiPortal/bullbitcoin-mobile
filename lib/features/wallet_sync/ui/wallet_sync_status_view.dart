import 'widgets/wallet_receive_sync_note.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transaction_sync/transaction_sync.dart';
import '../../tor_settings/public/tor_settings_facade.dart';
import 'package:go_router/go_router.dart';
import '../domain/usecases/watch_wallet_sync_status_usecase.dart';
import '../domain/wallet_sync_status.dart';
import '../domain/usecases/start_wallet_sync_usecase.dart';
import '../presentation/wallet_sync_status_cubit.dart';
import '../presentation/wallet_sync_status_l10n.dart';
import 'widgets/wallet_recovery_panel.dart';

enum WalletSyncViewKind {
  card,
  recovery,
  incomplete,
  sendWarning,
  sendReview,
  receiveNote,
  status,
  network,
}

class WalletSyncStatusView extends StatefulWidget {
  final String walletId;
  final WatchWalletSyncStatusUsecase watch;
  final StartWalletSyncUsecase start;
  final WalletSyncViewKind kind;
  final bool isSyncing;
  final VoidCallback onSettings;
  final VoidCallback onNetwork;
  const WalletSyncStatusView({
    super.key,
    required this.walletId,
    required this.watch,
    required this.start,
    required this.kind,
    this.isSyncing = false,
    required this.onSettings,
    required this.onNetwork,
  });
  @override
  State<WalletSyncStatusView> createState() => _WalletSyncStatusViewState();
}

class _WalletSyncStatusViewState extends State<WalletSyncStatusView> {
  Timer? _timer;
  int? _activeRecovery;
  int? _announcedRecovery;

  void _onStatus(BuildContext context, WalletSyncStatus? status) {
    if (widget.kind != WalletSyncViewKind.recovery) return;
    if (status == null || !status.isPrivate) {
      _activeRecovery = null;
      return;
    }
    final progress = status.progress;
    if (progress == null || !progress.isRecovery) return;
    if (progress.phase != BitcoinSyncPhase.done) {
      _activeRecovery = progress.operationId;
      return;
    }
    final operation = progress.operationId;
    if (operation == null ||
        operation != _activeRecovery ||
        operation == _announcedRecovery) {
      return;
    }
    _announcedRecovery = operation;
    BullSnackBar.showContent(
      context,
      Semantics(
        liveRegion: true,
        child: BullText(
          context.loc.syncWalletRestored,
          style: context.bullText.bodyMedium,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(WalletSyncStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walletId != widget.walletId ||
        oldWidget.kind != widget.kind) {
      _activeRecovery = null;
      _announcedRecovery = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: _StatusKey(widget.walletId),
    create: (_) => WalletSyncStatusCubit(
      walletId: widget.walletId,
      watch: widget.watch,
      start: widget.start,
    ),
    child: BlocConsumer<WalletSyncStatusCubit, WalletSyncStatus?>(
      listener: _onStatus,
      builder: (context, state) {
        final status = context.watch<WalletSyncStatusCubit>().state;
        if (status == null) return const BullShimmerLine();
        final now = DateTime.now().toUtc();
        return switch (widget.kind) {
          WalletSyncViewKind.card =>
            status.incomplete
                ? WalletIncompleteBalance(status: status)
                : widget.isSyncing
                ? BullFadingLinearProgress(
                    trigger: true,
                    height: 3,
                    backgroundColor: context.bull.transparent,
                    foregroundColor: context.bull.secondary,
                  )
                : const SizedBox.shrink(),
          WalletSyncViewKind.recovery => WalletRecoveryPanel(
            status: status,
            onRetry: context.read<WalletSyncStatusCubit>().retry,
            onSettings: widget.onSettings,
            onTorSettings: () async {
              await context.pushNamed(
                const TorSettingsFacade().settingsRouteName,
              );
              if (context.mounted) {
                await context.read<WalletSyncStatusCubit>().refresh();
              }
            },
          ),
          WalletSyncViewKind.incomplete => WalletIncompleteBalance(
            status: status,
          ),
          WalletSyncViewKind.sendWarning => WalletIncompleteBalance(
            status: status,
            sending: true,
          ),
          WalletSyncViewKind.receiveNote =>
            status.isPrivate
                ? WalletReceiveSyncNote(onSettings: widget.onSettings)
                : const SizedBox.shrink(),
          WalletSyncViewKind.sendReview =>
            status.isPrivate
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BullText(
                        status.torEnabled
                            ? context.loc.syncSendRouteTor
                            : context.loc.syncSendRoute,
                        style: context.bullText.bodySmall,
                      ),
                      WalletIncompleteBalance(status: status, sending: true),
                    ],
                  )
                : const SizedBox.shrink(),
          WalletSyncViewKind.status => BullBorderedTile(
            onTap: widget.onNetwork,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BullText(
                  context.loc.syncStatusTitle,
                  style: context.bullText.bodyMedium,
                ),
                const Gap(BullSpacing.sm),
                BullText(
                  status.message(context, now),
                  style: context.bullText.bodySmall,
                ),
              ],
            ),
          ),
          WalletSyncViewKind.network => BullScaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(BullSpacing.xxxl),
              child: BullTopBar(
                title: context.loc.syncNetworkStatus,
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(BullSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BullText(
                      status.message(context, now),
                      style: context.bullText.bodyMedium,
                    ),
                    const Gap(BullSpacing.md),
                    if (status.progress?.connectedPeers case final count?)
                      BullText(
                        context.loc.syncConnectedPeers(count),
                        style: context.bullText.bodyMedium,
                      ),
                    BullText(
                      context.loc.syncBlockHeight(
                        status.progress?.targetHeight == null
                            ? '—'
                            : NumberFormat.decimalPattern(
                                context.loc.localeName,
                              ).format(status.progress?.targetHeight),
                      ),
                      style: context.bullText.bodyMedium,
                    ),
                    BullText(
                      context.loc.syncLastSuccessful(
                        syncRelativeTime(
                          context,
                          status.lastSuccessfulSync,
                          now,
                        ),
                      ),
                      style: context.bullText.bodyMedium,
                    ),
                    BullText(
                      status.torEnabled
                          ? context.loc.syncTorOn
                          : context.loc.syncTorOff,
                      style: context.bullText.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        };
      },
    ),
  );
}

class _StatusKey extends ValueKey<String> {
  const _StatusKey(super.value);
  @override
  String toString() => 'WalletSyncStatusKey';
}
