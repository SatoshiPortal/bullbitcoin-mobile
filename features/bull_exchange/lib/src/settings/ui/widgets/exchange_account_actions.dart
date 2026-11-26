import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

import 'package:go_router/go_router.dart';

import '../../domain/account_deletion_machine.dart';
import '../../domain/usecases/delete_exchange_account_usecase.dart';
import '../../domain/usecases/sign_out_of_exchange_usecase.dart';
import '../exchange_access_settings_route.dart';
import 'exchange_account_sheets.dart';
import '../../../exchange_l10n.dart';

import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem, BullSnackBar;

class ExchangeAccountActions extends StatefulWidget {
  final bool showDeleteAccount;
  final DeleteExchangeAccountUsecase deleteAccount;
  final SignOutOfExchangeUsecase signOut;
  final String Function(BuildContext, ExchangeFailure) failureMessage;
  final bool Function(BuildContext) hasAccount;

  const ExchangeAccountActions({
    required this.showDeleteAccount,
    required this.deleteAccount,
    required this.signOut,
    required this.failureMessage,
    required this.hasAccount,
    super.key,
  });

  @override
  State<ExchangeAccountActions> createState() => _ExchangeAccountActionsState();
}

class _ExchangeAccountActionsState extends State<ExchangeAccountActions> {
  AccountDeletionState _deletion = const AccountDeletionIdle();

  void _addDeletion(AccountDeletionEvent event) {
    if (!mounted) return;
    final next = transitionAccountDeletion(_deletion, event);
    if (next == _deletion) return;
    setState(() => _deletion = next);
    switch (next) {
      case AccountDeletionRequesting():
        unawaited(_requestDeletion());
      case AccountDeletionRequested():
        // The settings screen may leave once signed out: show the notice
        // above it.
        final overlay = Navigator.of(context, rootNavigator: true).overlay;
        if (overlay != null) {
          unawaited(
            ExchangeAccountSheets.showDeletionRequested(overlay.context),
          );
        }
      case AccountDeletionFailed(:final failure):
        BullSnackBar.show(
          context,
          message: widget.failureMessage(context, failure),
        );
      case AccountDeletionIdle():
        break;
    }
  }

  Future<void> _requestDeletion() async {
    final result = await widget.deleteAccount.execute();
    _addDeletion(switch (result) {
      Ok(value: ExchangeAccountDeletionOutcome.completed) =>
        const AccountDeletionSent(),
      Ok(value: ExchangeAccountDeletionOutcome.stale) =>
        const AccountDeletionStale(),
      Err(:final failure) => AccountDeletionNotSent(failure),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasAccount(context)) return const SizedBox.shrink();
    return Column(
      children: [
        if (widget.showDeleteAccount)
          BullSettingsEntryItem(
            icon: Icons.delete_forever,
            title: context.loc.exchangeSettingsDeleteAccountTitle,
            onTap: _deletion is AccountDeletionRequesting
                ? null
                : () {
                    ExchangeAccountSheets.confirmDeletion(
                      context,
                      onConfirm: () async =>
                          _addDeletion(const AccountDeletionConfirmed()),
                    );
                  },
          ),
        BullSettingsEntryItem(
          icon: Icons.logout,
          title: context.loc.exchangeSettingsLogOutTitle,
          onTap: () {
            ExchangeAccountSheets.confirmLogout(
              context,
              onConfirm: () async {
                // A failed sign-out leaves access in SignOutIncomplete: the
                // session is gone from this screen, which may close, so the
                // message points to where the sign-out is finished (B18).
                final overlay = Overlay.of(context, rootOverlay: true);
                final router = GoRouter.of(context);
                final loc = context.loc;
                final result = await widget.signOut.execute();
                if (result case Err()) {
                  BullSnackBar.showOnOverlay(
                    overlay,
                    message: loc.exchangeLogoutDidNotFinish,
                    actionLabel: loc.exchangeAccessRetryLogout,
                    onAction: () => router.pushNamed<void>(
                      ExchangeAccessSettingsNavigation.name,
                    ),
                  );
                }
              },
            );
          },
        ),
      ],
    );
  }
}
