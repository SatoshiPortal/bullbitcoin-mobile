import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_awake/screen_awake.dart';

import 'package:primitives/primitives.dart';

import '../../domain/entities/recoverbull_flow.dart';
import '../../domain/entities/encrypted_vault.dart';
import '../../domain/entities/vault_provider.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
import '../../presentation/vault_selection_machine.dart';
import '../recoverbull_flow_navigator.dart';
import '../widgets/recoverbull_widgets.dart';
import 'vault_completed_pages.dart';
import 'vault_selected_page.dart';

/// The password a new vault is sealed with, held only until it is sealed.
///
/// A holder rather than a string: the route that built the screen keeps its
/// arguments, so only a holder lets the screen actually forget the secret.
final class SealingPassword {
  String? _value;

  SealingPassword(String value) : _value = value;

  String? get value => _value;

  void forget() => _value = null;
}

/// Where to save a new vault, or where to read an existing one from.
class VaultProviderSelectionPage extends StatefulWidget {
  /// Set only when creating a vault.
  final SealingPassword? password;
  final bool passphraseWarningAccepted;

  /// The user skipped the key server and will open the vault with its key.
  final bool vaultKeyOnly;

  const VaultProviderSelectionPage({
    super.key,
    this.password,
    this.passphraseWarningAccepted = false,
    this.vaultKeyOnly = false,
  });

  @override
  State<VaultProviderSelectionPage> createState() =>
      _VaultProviderSelectionPageState();
}

class _VaultProviderSelectionPageState
    extends State<VaultProviderSelectionPage> {
  VaultProvider? _provider;
  int _attempt = 0;
  VaultSelectionState _selection = const VaultSelectionIdle();

  /// Set while this page creates the vault, so a key-server probe started
  /// elsewhere is not shown as vault creation.
  bool _creating = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Leaving the app before the vault is sealed forgets its password: the
    // user types it again rather than having it outlive the screen.
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.paused &&
            state != AppLifecycleState.hidden) {
          return;
        }
        final password = widget.password;
        if (_creating || password == null || password.value == null) return;
        password.forget();
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      },
    );
  }

  @override
  void dispose() {
    _attempt++;
    _selection = transitionVaultSelection(
      _selection,
      const VaultSelectionLeft(),
    );
    _lifecycle.dispose();
    widget.password?.forget();
    super.dispose();
  }

  Future<void> _select(VaultProvider provider) async {
    final cubit = context.read<VaultFlowCubit>();
    final flow = RecoverBullFlowScope.of(context).flow;
    if (flow == RecoverBullFlow.secureVault) {
      setState(() => _provider = provider);
      final password = widget.password?.value;
      if (password == null) return;
      setState(() => _creating = true);
      await cubit.create(
        provider,
        password,
        passphraseWarningAccepted: widget.passphraseWarningAccepted,
      );
      // Once sealed, a retry saves the same vault and needs no password.
      if (cubit.state.hasPendingProviderSave ||
          cubit.state.completion != null) {
        widget.password?.forget();
      }
      if (mounted) setState(() => _creating = false);
      return;
    }
    final attempt = ++_attempt;
    _selection = transitionVaultSelection(
      _selection,
      VaultSelectionStarted(attempt, provider),
    );
    bool current() =>
        mounted &&
        _attempt == attempt &&
        ModalRoute.of(context)?.isCurrent == true;
    if (provider == VaultProvider.googleDrive) {
      final result = await cubit.openDriveList();
      if (!mounted || !current() || result == null) return;
      switch (result) {
        case Err(:final failure):
          _selection = transitionVaultSelection(
            _selection,
            VaultSelectionError(attempt, failure),
          );
        case Ok(:final value):
          _selection = transitionVaultSelection(
            _selection,
            VaultSelectionListed(attempt, value),
          );
      }
      if (_selection case VaultSelectionReading(:final file)) {
        final opened = await cubit.openDriveVault(file);
        if (!mounted || !current() || opened == null) return;
        _acceptOpening(attempt, opened);
      }
    } else {
      final opened = await cubit.openPickedVault();
      if (!mounted || !current() || opened == null) return;
      _acceptOpening(attempt, opened);
    }
    if (!mounted || !current()) return;
    switch (_selection) {
      case VaultSelectionSelected(:final provider, :final vault):
        if (!cubit.adoptSelectedVault(vault)) return;
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VaultSelectedPage(
                provider: provider,
                vaultKeyOnly: widget.vaultKeyOnly,
              ),
            ),
          ),
        );
      case VaultSelectionEmpty():
        BullSnackBar.show(
          context,
          message: context.loc.recoverbullGoogleDriveNoBackupsFound,
        );
      case VaultSelectionFailed(:final failure):
        BullSnackBar.show(context, message: failure.toTranslated(context));
      case VaultSelectionIdle() ||
          VaultSelectionCancelled() ||
          VaultSelectionOpening() ||
          VaultSelectionReading():
        break;
    }
  }

  void _acceptOpening(
    int attempt,
    Result<EncryptedVault, RecoverBullFailure> result,
  ) {
    _selection = transitionVaultSelection(_selection, switch (result) {
      Ok(:final value) => VaultSelectionOpened(attempt, value),
      Err(:final failure) => VaultSelectionError(attempt, failure),
    });
  }

  void _onState(BuildContext context, VaultFlowState state) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final failure = state.failure;
    if (failure != null) {
      // Closing the file picker is a choice, not an error.
      if (failure is! VaultCancelledFailure) {
        BullSnackBar.show(context, message: failure.toTranslated(context));
      }
      context.read<VaultFlowCubit>().clearFailure();
      return;
    }
    final flow = RecoverBullFlowScope.of(context).flow;
    if (flow == RecoverBullFlow.secureVault) {
      final completion = state.completion;
      if (completion == null) return;
      BullSnackBar.show(
        context,
        message: context.loc.recoverbullVaultCreatedSuccess,
      );
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => VaultCreatedPage(completion: completion),
          ),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = RecoverBullFlowScope.of(context).flow;
    return Scaffold(
      appBar: RecoverBullAppBar(
        title: context.loc.recoverbullSelectVaultProvider,
      ),
      body: BlocConsumer<VaultFlowCubit, VaultFlowState>(
        listenWhen: (previous, current) =>
            (current.failure != null && previous.failure != current.failure) ||
            (current.vault != null && previous.vault != current.vault) ||
            (current.completion != null &&
                previous.completion != current.completion),
        listener: (context, state) {
          if (flow == RecoverBullFlow.secureVault) _onState(context, state);
        },
        builder: (context, state) {
          final creating =
              flow == RecoverBullFlow.secureVault && _creating && state.busy;
          return ScreenAwakeScope(
            enabled: creating,
            child: Column(
              children: [
                BullFadingLinearProgress(
                  trigger: state.busy,
                  backgroundColor: context.bull.surface,
                  foregroundColor: context.bull.primary,
                  height: 2,
                ),
                if (creating)
                  Center(
                    child: RecoverBullProgress(
                      title: context.loc.recoverbullCreatingVault,
                      description: context.loc.recoverbullConnectingTor,
                    ),
                  )
                else if (state.hasPendingProviderSave)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        BullText(
                          context.loc.recoverbullPendingProviderSave,
                          style: context.bullType.body,
                          maxLines: 5,
                        ),
                        const Gap(16),
                        BullButton.secondary(
                          label: context.loc.recoverbullRetryProviderSave,
                          onPressed: (state.busy)
                              ? null
                              : () => context
                                    .read<VaultFlowCubit>()
                                    .retryProviderSave(_provider),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: IgnorePointer(
                      ignoring: state.busy,
                      child: VaultProviderSelector(onProviderSelected: _select),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => BullBottomSheet.show<void>(
                          context: context,
                          child: const HowToDecideVaultLocation(),
                        ),
                        child: BullText(
                          context.loc.backupWalletHowToDecide,
                          style: context.bullType.subtitle
                              .copyWith(fontWeight: FontWeight.w700)
                              .copyWith(color: context.bull.primary),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class HowToDecideVaultLocation extends StatelessWidget {
  const HowToDecideVaultLocation({super.key});

  @override
  Widget build(BuildContext context) {
    final body = context.bullType.label.copyWith(height: 1.5);
    TextSpan recommendation(String title, String text) => TextSpan(
      style: context.bullType.body,
      children: [
        TextSpan(
          text: title,
          style: context.bullType.caption.copyWith(fontWeight: .bold),
        ),
        TextSpan(text: text, style: context.bullType.caption),
      ],
    );
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.bull.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.bullShapes.sheet),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  const Spacer(),
                  BullText(
                    context.loc.backupWalletHowToDecideBackupModalTitle,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: .center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: context.bull.onSurface),
                  ),
                ],
              ),
            ),
            const Gap(32),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      BullText(
                        context.loc.backupWalletHowToDecideVaultCloudSecurity,
                        style: body,
                        maxLines: 16,
                      ),
                      const Gap(32),
                      BullText(
                        context.loc.backupWalletHowToDecideVaultCustomLocation,
                        style: body,
                        maxLines: 16,
                      ),
                      const Gap(12),
                      RichText(
                        text: recommendation(
                          context
                              .loc
                              .backupWalletHowToDecideVaultCustomRecommendation,
                          context
                              .loc
                              .backupWalletHowToDecideVaultCustomRecommendationText,
                        ),
                      ),
                      const Gap(12),
                      RichText(
                        text: recommendation(
                          context
                              .loc
                              .backupWalletHowToDecideVaultCloudRecommendation,
                          context
                              .loc
                              .backupWalletHowToDecideVaultCloudRecommendationText,
                        ),
                      ),
                      const Gap(12),
                      BullText(
                        context.loc.backupWalletHowToDecideVaultMoreInfo,
                        style: body,
                      ),
                      const Gap(20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
