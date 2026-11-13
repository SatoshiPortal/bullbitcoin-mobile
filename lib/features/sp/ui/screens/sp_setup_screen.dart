import 'dart:async';

import 'package:bb_mobile/features/sp/presentation/sp_failure_l10n.dart';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_config_form.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_scan_start_selector.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SpSetupScreen extends StatefulWidget {
  const SpSetupScreen({super.key, required this.successRedirectPath});

  final String successRedirectPath;

  @override
  State<SpSetupScreen> createState() => _SpSetupScreenState();
}

class _SpSetupScreenState extends State<SpSetupScreen> {
  String? _walletId;
  bool _pendingSetup = false;
  bool _redirected = false;
  BitcoinNetwork? _loadedNetwork;
  int _candidateGeneration = 0;
  Future<
    Result<List<({String id, String label, bool hasPassphrase})>, SpFailure>
  >?
  _candidates;

  void _redirectWhenCreated(BuildContext context, SpSetupState state) {
    if (_redirected || !mounted) return;
    _redirected = true;
    if (state.existingVerified) {
      context.go(SpRoute.spWalletDetail.path);
      return;
    }
    if (state.scanStart != SpScanStart.earlierBlock) {
      context.go(widget.successRedirectPath);
      return;
    }
    final router = GoRouter.of(context);
    router.go(SpRoute.spWalletDetail.path);
    unawaited(router.push(SpRoute.spScan.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.spSetupTitle)),
      body: BlocConsumer<SpSetupCubit, SpSetupState>(
        listenWhen: (prev, curr) => !prev.created && curr.created,
        listener: _redirectWhenCreated,
        builder: (context, state) {
          final cubit = context.read<SpSetupCubit>();
          if (state.created) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _redirectWhenCreated(context, state);
            });
            return const Center(child: CircularProgressIndicator());
          }
          if (state.isInspecting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entryFailure = state.entryFailure;
          if (entryFailure != null && entryFailure is! SpRecoveryRequired) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(entryFailure.toTranslated(context)),
            );
          }
          if (entryFailure is SpRecoveryRequired ||
              state.error is SpRecoveryRequired) {
            _pendingSetup = true;
          }
          if (_pendingSetup) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.loc.spResumeSavedSetupHelp),
                  const SizedBox(height: 16),
                  if (state.error != null)
                    Text(state.error!.toTranslated(context)),
                  const SizedBox(height: 16),
                  BBButton.big(
                    onPressed: cubit.retryPendingSetup,
                    label: context.loc.spResumeSavedSetupButton,
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                    disabled: state.isCreating,
                  ),
                ],
              ),
            );
          }

          if (_loadedNetwork != state.network) {
            _loadedNetwork = state.network;
            _candidateGeneration++;
            _walletId = null;
            _candidates = cubit.candidates(state.network);
          }
          final candidateGeneration = _candidateGeneration;
          return Column(
            children: [
              if (state.isCreating || state.isFetchingDefaults)
                LinearProgressIndicator(
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SpBackendConfigForm<SpSetupState>(
                    state: state,
                    isBusy: state.isCreating,
                    onFetchDefaults: cubit.fetchRegtestDefaults,
                    onBlindbitChanged: cubit.setBlindbitUrl,
                    onTestBlindbit: cubit.testBlindbit,
                    onElectrumChanged: cubit.setElectrumUrl,
                    onTestElectrum: cubit.testElectrum,
                    networkField: DropdownButtonFormField<BitcoinNetwork>(
                      key: ValueKey('network_${state.network.name}'),
                      initialValue: state.network,
                      decoration: InputDecoration(
                        labelText: context.loc.spNetworkLabel,
                      ),
                      items: BitcoinNetwork.values
                          .map(
                            (n) =>
                                DropdownMenuItem(value: n, child: Text(n.name)),
                          )
                          .toList(),
                      onChanged: state.isCreating
                          ? null
                          : (n) {
                              if (n != null) cubit.setNetwork(n);
                            },
                    ),
                    extraFields: Column(
                      children: [
                        FutureBuilder<
                          Result<
                            List<
                              ({String id, String label, bool hasPassphrase})
                            >,
                            SpFailure
                          >
                        >(
                          key: ValueKey('sp_candidates_${state.network.name}'),
                          future: _candidates,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const CircularProgressIndicator();
                            }
                            final result = snapshot.data;
                            if (result
                                is! Ok<
                                  List<
                                    ({
                                      String id,
                                      String label,
                                      bool hasPassphrase,
                                    })
                                  >,
                                  SpFailure
                                >) {
                              return result
                                      is Err<
                                        List<
                                          ({
                                            String id,
                                            String label,
                                            bool hasPassphrase,
                                          })
                                        >,
                                        SpFailure
                                      >
                                  ? Text(context.loc.oopsSomethingWentWrong)
                                  : const CircularProgressIndicator();
                            }
                            if (result.value.isEmpty) {
                              return Text(
                                context.loc.spSourceNoEligibleWallets,
                              );
                            }
                            final needsPassphrase = result.value.any(
                              (wallet) =>
                                  wallet.id == _walletId &&
                                  wallet.hasPassphrase,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'sp_source_${state.network.name}',
                                  ),
                                  initialValue: _walletId,
                                  decoration: InputDecoration(
                                    labelText: context.loc.spSourceWalletLabel,
                                    helperText: context.loc.spSourceWalletHelp,
                                    helperMaxLines: 3,
                                  ),
                                  items: result.value
                                      .map(
                                        (w) => DropdownMenuItem(
                                          value: w.id,
                                          child: Text(w.label),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: state.isCreating
                                      ? null
                                      : (value) {
                                          if (!mounted ||
                                              _loadedNetwork != state.network ||
                                              candidateGeneration !=
                                                  _candidateGeneration) {
                                            return;
                                          }
                                          setState(() => _walletId = value);
                                        },
                                ),
                                if (needsPassphrase)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      context
                                          .loc
                                          .spSourcePassphraseBackupNotice,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        SpScanStartSelector(
                          scanStart: state.scanStart,
                          onChanged: cubit.setScanStart,
                          isBusy: state.isCreating,
                        ),
                      ],
                    ),
                    submit: BBButton.big(
                      onPressed: () {
                        final walletId = _walletId;
                        if (walletId != null) cubit.create(walletId);
                      },
                      label: context.loc.spCreateButton,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      disabled: !state.canCreate || _walletId == null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
