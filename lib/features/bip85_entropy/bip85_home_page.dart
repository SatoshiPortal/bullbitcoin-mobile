import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/bip85_derivation_widget.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/bip85_failure_l10n.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullFadingLinearProgress, BullPage, BullTopBar, Gap;

class Bip85HomePage extends StatefulWidget {
  const Bip85HomePage({super.key});

  @override
  State<Bip85HomePage> createState() => _Bip85HomePageState();
}

class _Bip85HomePageView extends StatelessWidget {
  const _Bip85HomePageView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<Bip85EntropyCubit, Bip85EntropyState>(
      listenWhen: (p, c) => p.failure != c.failure && c.failure != null,
      listener: (context, state) {
        SnackBarUtils.showSnackBar(
          context,
          state.failure!.toTranslated(context),
        );
      },
      child: BullPage(
        topBar: BullTopBar(
          title: context.loc.bip85Title,
          onBack: Navigator.of(context).canPop()
              ? () => Navigator.of(context).pop()
              : null,
        ),
        padding: EdgeInsets.zero,
        child: BlocBuilder<Bip85EntropyCubit, Bip85EntropyState>(
          builder: (context, state) {
            final cubit = context.read<Bip85EntropyCubit>();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  BullFadingLinearProgress(trigger: state.isLoading),
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.appColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: context.appColors.warning),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            context.loc.bip85ExperimentalWarning,
                            style: TextStyle(color: context.appColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(16),
                  if (state.derivations.isNotEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: state.derivations.length,
                        itemBuilder: (context, index) {
                          final derivationWithEntropy =
                              state.derivations[index];
                          return Padding(
                            padding: const EdgeInsets.all(8),
                            child: Bip85DerivationWidget(
                              derivation: derivationWithEntropy.derivation,
                              entropy: derivationWithEntropy.entropy,
                              onAliasChanged: cubit.aliasDerivation,
                              onDerivationRevoked: cubit.revokeDerivation,
                              onDerivationActivated: cubit.activateDerivation,
                            ),
                          );
                        },
                      ),
                    ),
                  const Gap(16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: BullButton.primary(
                            onPressed: () => cubit.deriveNextMnemonic(),
                            label: context.loc.bip85NextMnemonic,
                          ),
                        ),
                        Gap(Device.screen.width * 0.01),
                        Expanded(
                          child: BullButton.primary(
                            onPressed: () => cubit.deriveNextHex(),
                            label: context.loc.bip85NextHex,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Bip85HomePageState extends State<Bip85HomePage> with PrivacyScreen {
  @override
  void initState() {
    super.initState();
    enableScreenPrivacy();
  }

  @override
  Widget build(BuildContext context) => const _Bip85HomePageView();

  @override
  void dispose() {
    disableScreenPrivacy();
    super.dispose();
  }
}
