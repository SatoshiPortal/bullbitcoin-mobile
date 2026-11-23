import 'package:bip85/src/presentation/bip85_l10n.dart';

import 'dart:async';

import 'package:bip85/src/ui/bip85_derivation_widget.dart';
import 'package:bip85/src/presentation/bip85_failure_l10n.dart';
import 'package:bip85/src/presentation/bip85_cubit.dart';
import 'package:bip85/src/presentation/bip85_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:screen_privacy/screen_privacy.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullScreenPrivacyGate,
        BullThemeX,
        BullShapesX,
        BullSnackBar,
        Gap;

class Bip85HomePage extends StatefulWidget {
  final Bip85EntropyCubit Function() createCubit;

  const Bip85HomePage({super.key, required this.createCubit});

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
        if (state.failure case final failure?) {
          BullSnackBar.show(context, message: failure.toTranslated(context));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.bip85Loc.bip85Title)),
        body: BlocBuilder<Bip85EntropyCubit, Bip85EntropyState>(
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
                      color: context.bull.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: context.bull.warning),
                        const Gap(8),
                        Expanded(
                          child: Text(
                            context.bip85Loc.bip85ExperimentalWarning,
                            style: TextStyle(color: context.bull.warning),
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
                              key: ValueKey((
                                derivationWithEntropy
                                    .derivation
                                    .parentFingerprint,
                                derivationWithEntropy.derivation.path,
                              )),
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
                          child: BullButton.secondary(
                            onPressed: () => cubit.deriveNextMnemonic(),
                            label: context.bip85Loc.bip85NextMnemonic,
                          ),
                        ),
                        Gap(MediaQuery.sizeOf(context).width * 0.01),
                        Expanded(
                          child: BullButton.secondary(
                            onPressed: () => cubit.deriveNextHex(),
                            label: context.bip85Loc.bip85NextHex,
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
  // The page shows BIP85 children: nothing draws before capture blocking is
  // confirmed, and they stay hidden if the platform refused it.
  late Future<bool> _privacyFuture = enableScreenPrivacy();

  @override
  Widget build(BuildContext context) => BullScreenPrivacyGate(
    unavailableMessage: context.bip85Loc.screenPrivacyUnavailable,
    retryLabel: context.bip85Loc.retry,
    protection: _privacyFuture,
    onRetry: () => setState(() {
      _privacyFuture = enableScreenPrivacy();
    }),
    builder: (context) => BlocProvider(
      create: (_) => widget.createCubit()..init(),
      child: const _Bip85HomePageView(),
    ),
  );

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }
}
