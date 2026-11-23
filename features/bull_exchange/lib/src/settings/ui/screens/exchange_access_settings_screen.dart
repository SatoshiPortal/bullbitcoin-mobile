import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../exchange_l10n.dart';
import '../../presentation/exchange_access_settings_cubit.dart';

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

  Future<void> _enable(ExchangeAccessSettingsCubit cubit) async {
    if (!await cubit.setEnabled(true) || cubit.isClosed) return;
    if (cubit.state.access case ExchangeAccessEnabled(
      session: ExchangeAccessSession.signedOut,
    )) {
      await onAuthenticate();
    }
  }

  Future<void> _logout(ExchangeAccessSettingsCubit cubit) async {
    if (await cubit.setEnabled(false) && !cubit.isClosed) onDisabled();
  }

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

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExchangeAccessSettingsCubit>();
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
                    BlocBuilder<
                      ExchangeAccessSettingsCubit,
                      ExchangeAccessSettingsState
                    >(
                      builder: (context, state) {
                        final access = state.access;
                        final enabled = access is ExchangeAccessEnabled;
                        final signedIn =
                            access is ExchangeAccessEnabled &&
                            access.session == ExchangeAccessSession.signedIn;
                        final incomplete =
                            access is ExchangeAccessSignOutIncomplete;
                        final unreadable =
                            access is ExchangeAccessUnreadable ||
                            (access is ExchangeAccessEnabled &&
                                access.session ==
                                    ExchangeAccessSession.unreadable);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if ((activationAllowed || signedIn) &&
                                !incomplete &&
                                !unreadable) ...[
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
                                          state.busy ||
                                              access is ExchangeAccessResolving
                                          ? null
                                          : (value) async {
                                              if (value) {
                                                await _enable(cubit);
                                              } else {
                                                final confirmed =
                                                    await _confirmLogout(
                                                      context,
                                                    );
                                                if (confirmed &&
                                                    !cubit.isClosed) {
                                                  await _logout(cubit);
                                                }
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
                            if (incomplete) ...[
                              BullText(
                                context.loc.exchangeAccessLogoutIncomplete,
                                style: context.bullType.body,
                              ),
                              const Gap(16),
                              BullButton.primary(
                                label: context.loc.exchangeAccessRetryLogout,
                                onPressed: (state.busy)
                                    ? null
                                    : () => _logout(cubit),
                              ),
                            ],
                            if (unreadable) ...[
                              BullText(
                                context.loc.exchangeAccessUnreadable,
                                style: context.bullType.body,
                              ),
                              const Gap(16),
                              BullButton.primary(
                                label: context.loc.exchangeTradingRetry,
                                onPressed: (state.busy) ? null : cubit.retry,
                              ),
                              const Gap(12),
                              BullButton.secondary(
                                label: context.loc.exchangeAccessReset,
                                onPressed: (state.busy)
                                    ? null
                                    : () async {
                                        if (await _confirmLogout(context) &&
                                            !cubit.isClosed) {
                                          await _logout(cubit);
                                        }
                                      },
                              ),
                            ],
                            if (state.failure != null) ...[
                              const Gap(16),
                              BullText(
                                context.loc.settingsErrorSavingSetting,
                                style: context.bullType.body,
                              ),
                            ],
                            if (!incomplete &&
                                !unreadable &&
                                (signedIn ||
                                    (activationAllowed && enabled))) ...[
                              const Gap(24),
                              BullButton.primary(
                                label: signedIn
                                    ? context.loc.settingsAccountSettingsTitle
                                    : context.loc.exchangeAccessSignIn,
                                onPressed: (state.busy)
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
