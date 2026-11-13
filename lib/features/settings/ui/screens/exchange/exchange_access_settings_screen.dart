import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:bb_mobile/features/settings/presentation/exchange_access_settings_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeAccessSettingsScreen extends StatelessWidget {
  const ExchangeAccessSettingsScreen({
    required this.cubit,
    required this.onBack,
    required this.onAuthenticate,
    required this.onOpenAccount,
    required this.onDisabled,
    super.key,
  });
  final ExchangeAccessSettingsCubit cubit;
  final VoidCallback onBack;
  final Future<void> Function() onAuthenticate;
  final VoidCallback onOpenAccount;
  final VoidCallback onDisabled;

  Future<void> _enable() async {
    final outcome = await cubit.setEnabled(true);
    if (outcome == ExchangeAccessOutcome.authenticationRequired) {
      final generation = cubit.generation;
      await onAuthenticate();
      if (!cubit.isClosed) await cubit.cancelActivation(generation);
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => cubit,
    child: BullScaffold(
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
                child: BlocBuilder<ExchangeAccessSettingsCubit, ExchangeAccessSettingsState>(
                  builder: (context, state) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: BullText(
                              context.loc.exchangeAccessSettingsLabel,
                              style: const TextStyle(),
                            ),
                          ),
                          BullSwitch(
                            value: state.access.enabledForHome,
                            onChanged: state.busy
                                ? null
                                : (enabled) async {
                                    if (enabled) {
                                      await _enable();
                                    } else {
                                      final confirmed = await BullBottomSheet.show<bool>(
                                        context: context,
                                        child: Padding(
                                          padding: const EdgeInsets.all(24),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              BullText(
                                                context
                                                    .loc
                                                    .exchangeAccessDisableTitle,
                                                style: const TextStyle(),
                                              ),
                                              const Gap(16),
                                              BullText(
                                                context
                                                    .loc
                                                    .exchangeAccessDisableBody,
                                                style: const TextStyle(),
                                              ),
                                              const Gap(16),
                                              BullButton.big(
                                                label: context
                                                    .loc
                                                    .exchangeAccessDisableConfirm,
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                bgColor: context.bull.primary,
                                                textColor:
                                                    context.bull.onPrimary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                      if (confirmed == true &&
                                          !cubit.isClosed) {
                                        final outcome = await cubit.setEnabled(
                                          false,
                                        );
                                        if (outcome ==
                                            ExchangeAccessOutcome.applied) {
                                          onDisabled();
                                        }
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                      const Gap(12),
                      BullText(
                        context.loc.exchangeAccessSettingsDescription,
                        style: const TextStyle(),
                      ),
                      const Gap(12),
                      BullText(
                        state.access.enabledForHome
                            ? context.loc.exchangeAccessSettingsOnHint
                            : context.loc.exchangeAccessSettingsOffHint,
                        style: const TextStyle(),
                      ),
                      if (state.failure case final failure?) ...[
                        const Gap(16),
                        BullText(
                          failure.toTranslated(context),
                          style: const TextStyle(),
                        ),
                      ],
                      const Gap(24),
                      BullButton.big(
                        label: state.access.canUseAuthenticatedExchange
                            ? context.loc.exchangeAccessOpenAccount
                            : context.loc.exchangeAccessSignIn,
                        disabled: state.busy,
                        onPressed: state.access.canUseAuthenticatedExchange
                            ? onOpenAccount
                            : _enable,
                        bgColor: context.bull.primary,
                        textColor: context.bull.onPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
