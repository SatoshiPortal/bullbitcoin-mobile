import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../exchange_l10n.dart';
import '../../presentation/exchange_access_settings_bloc.dart';
import '../../presentation/exchange_access_settings_machine.dart';

enum _AccessView { controls, signOutIncomplete, unreadable, expiring }

_AccessView _viewOf(ExchangeAccess access) => switch (access) {
  ExchangeAccessResolving() ||
  ExchangeAccessDisabled() ||
  ExchangeAccessSignedOut() ||
  ExchangeAccessSignedIn() => _AccessView.controls,
  ExchangeAccessSignOutIncomplete() => _AccessView.signOutIncomplete,
  ExchangeAccessUnreadable() ||
  ExchangeAccessCredentialUnreadable() => _AccessView.unreadable,
  ExchangeAccessExpiring() => _AccessView.expiring,
};

class ExchangeAccessSettingsScreen extends StatelessWidget {
  const ExchangeAccessSettingsScreen({
    required this.onBack,
    required this.onAuthenticate,
    required this.onOpenAccount,
    required this.onDisabled,
    required this.activationAllowed,
    required this.description,
    super.key,
  });
  final VoidCallback onBack;
  final Future<void> Function() onAuthenticate;
  final VoidCallback onOpenAccount;
  final VoidCallback onDisabled;
  final bool activationAllowed;
  final String description;

  Future<bool> _confirmLogout(BuildContext context) async =>
      await BullBottomSheet.show<bool>(
        context: context,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BullText(
                context.loc.exchangeAccessDisableTitle,
                style: context.bullType.title,
              ),
              const Gap(16),
              BullText(
                context.loc.exchangeAccessDisableBody,
                style: context.bullType.body,
              ),
              const Gap(16),
              BullButton.primary(
                label: context.loc.exchangeAccessDisableConfirm,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ) ??
      false;

  void _followUp(ExchangeAccessSettingsState state) {
    if (state case AccessSettingsSucceeded(:final attempt, :final access)) {
      switch (attempt) {
        case ExchangeAccessAttempt.enable:
          if (access is ExchangeAccessSignedOut) unawaited(onAuthenticate());
        case ExchangeAccessAttempt.signOut:
          onDisabled();
        case ExchangeAccessAttempt.retry:
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExchangeAccessSettingsBloc>();
    Future<void> confirmSignOut() async {
      if (await _confirmLogout(context) && !bloc.isClosed) {
        bloc.add(const AccessSettingsSignOutRequested());
      }
    }

    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(
              title: context.loc.exchangeAccessSettingsTitle,
              onBack: onBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child:
                    BlocConsumer<
                      ExchangeAccessSettingsBloc,
                      ExchangeAccessSettingsState
                    >(
                      listenWhen: (_, next) => next is AccessSettingsSucceeded,
                      listener: (_, state) => _followUp(state),
                      builder: (context, state) {
                        final access = state.access;
                        final busy = state is AccessSettingsWorking;
                        final enabled = access.isEnabled;
                        final signedIn = access.isSignedIn;
                        final view = _viewOf(access);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (view == _AccessView.controls &&
                                (activationAllowed || signedIn)) ...[
                              MergeSemantics(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: BullText(
                                        context.loc.exchangeAccessSettingsLabel,
                                        style: context.bullType.body,
                                      ),
                                    ),
                                    BullSwitch(
                                      value: enabled,
                                      onChanged:
                                          busy ||
                                              access is ExchangeAccessResolving
                                          ? null
                                          : (value) async {
                                              if (value) {
                                                bloc.add(
                                                  const AccessSettingsEnableRequested(),
                                                );
                                              } else {
                                                await confirmSignOut();
                                              }
                                            },
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(12),
                              BullText(
                                description,
                                style: context.bullType.body,
                              ),
                              const Gap(12),
                              BullText(
                                enabled
                                    ? context.loc.exchangeAccessSettingsOnHint
                                    : context.loc.exchangeAccessSettingsOffHint,
                                style: context.bullType.body,
                              ),
                            ],
                            if (view == _AccessView.signOutIncomplete) ...[
                              BullText(
                                context.loc.exchangeAccessLogoutIncomplete,
                                style: context.bullType.body,
                              ),
                              const Gap(16),
                              BullButton.primary(
                                label: context.loc.exchangeAccessRetryLogout,
                                onPressed: busy
                                    ? null
                                    : () => bloc.add(
                                        const AccessSettingsSignOutRequested(),
                                      ),
                              ),
                            ],
                            if (view == _AccessView.unreadable ||
                                view == _AccessView.expiring) ...[
                              BullText(
                                view == _AccessView.expiring
                                    ? context.loc.exchangeAccessExpiring
                                    : context.loc.exchangeAccessUnreadable,
                                style: context.bullType.body,
                              ),
                              const Gap(16),
                              BullButton.primary(
                                label: context.loc.exchangeTradingRetry,
                                onPressed: busy
                                    ? null
                                    : () => bloc.add(
                                        const AccessSettingsRetryRequested(),
                                      ),
                              ),
                              const Gap(12),
                              BullButton.secondary(
                                label: context.loc.exchangeAccessReset,
                                onPressed: busy ? null : confirmSignOut,
                              ),
                            ],
                            if (state is AccessSettingsFailed) ...[
                              const Gap(16),
                              BullText(
                                context.loc.settingsErrorSavingSetting,
                                style: context.bullType.body,
                              ),
                            ],
                            if (view == _AccessView.controls &&
                                (signedIn ||
                                    (activationAllowed && enabled))) ...[
                              const Gap(24),
                              BullButton.primary(
                                label: signedIn
                                    ? context.loc.settingsAccountSettingsTitle
                                    : context.loc.exchangeAccessSignIn,
                                onPressed: busy
                                    ? null
                                    : signedIn
                                    ? onOpenAccount
                                    : onAuthenticate,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
