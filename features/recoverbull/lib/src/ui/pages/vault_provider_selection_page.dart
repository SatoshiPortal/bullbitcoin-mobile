import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:screen_awake/screen_awake.dart';

import '../../domain/entities/drive_file_metadata.dart';
import '../../domain/entities/recoverbull_flow.dart';
import '../../domain/entities/vault_provider.dart';
import '../../domain/recoverbull_failure.dart';
import '../../l10n/context_localizations.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import '../../presentation/vault_flow_cubit.dart';
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
  bool _awaitingLatestDriveVault = false;

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
    _lifecycle.dispose();
    widget.password?.forget();
    super.dispose();
  }

  Future<void> _select(VaultProvider provider) async {
    final cubit = context.read<VaultFlowCubit>();
    setState(() => _provider = provider);
    final flow = RecoverBullFlowScope.of(context).flow;
    if (flow == RecoverBullFlow.secureVault) {
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
    switch (provider) {
      case VaultProvider.customLocation || VaultProvider.iCloud:
        await cubit.pick();
      case VaultProvider.googleDrive:
        // The most recent Drive vault is preselected; the others stay one tap away.
        _awaitingLatestDriveVault = true;
        await cubit.list();
        if (!mounted) return;
        final files = cubit.state.files;
        _awaitingLatestDriveVault = false;
        if (files == null) return;
        if (files.isEmpty) {
          BullSnackBar.show(
            context,
            message: context.loc.recoverbullGoogleDriveNoBackupsFound,
          );
          return;
        }
        final latest = files.reduce(_newest);
        await cubit.select(latest);
    }
  }

  static DriveFileMetadata _newest(DriveFileMetadata a, DriveFileMetadata b) =>
      a.createdTime.isAfter(b.createdTime) ? a : b;

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
    final provider = _provider;
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
    final vault = state.vault;
    if (vault != null && provider != null && !_awaitingLatestDriveVault) {
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
        listener: _onState,
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
                          style: context.bullText.bodyMedium,
                          maxLines: 5,
                        ),
                        const Gap(16),
                        BullButton.big(
                          label: context.loc.recoverbullRetryProviderSave,
                          bgColor: context.bull.onSurface,
                          textColor: context.bull.surface,
                          disabled: state.busy,
                          onPressed: () => context
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
                          style: context.bullText.headlineLarge?.copyWith(
                            color: context.bull.primary,
                          ),
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
    final body = context.bullText.labelMedium?.copyWith(
      height: 1.5,
      fontSize: 14,
    );
    TextSpan recommendation(String title, String text) => TextSpan(
      style: context.bullText.bodyMedium,
      children: [
        TextSpan(
          text: title,
          style: context.bullText.labelMedium?.copyWith(fontWeight: .bold),
        ),
        TextSpan(text: text, style: context.bullText.labelMedium),
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
                    style: context.bullText.headlineMedium,
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
