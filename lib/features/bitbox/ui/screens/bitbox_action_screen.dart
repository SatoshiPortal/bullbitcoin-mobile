import 'package:bb_mobile/core/bitbox/domain/errors/bitbox_errors.dart';
import 'package:bb_mobile/core/bitbox/domain/repositories/bitbox_device_repository.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/connect_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/get_bitbox_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/pair_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/scan_bitbox_devices_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/sign_psbt_bitbox_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/unlock_bitbox_device_usecase.dart';
import 'package:bb_mobile/core/bitbox/domain/usecases/verify_address_bitbox_usecase.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitbox/bitbox_action.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_cubit.dart';
import 'package:bb_mobile/features/bitbox/presentation/cubit/bitbox_operation_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class BitBoxRouteParams {
  final String? psbt;
  final String? derivationPath;
  final String? address;
  final SignerDeviceEntity? requestedDeviceType;
  final ScriptType? scriptType;

  const BitBoxRouteParams({
    this.psbt,
    this.derivationPath,
    this.address,
    this.requestedDeviceType,
    this.scriptType,
  });
}

class BitBoxActionScreen extends StatelessWidget {
  final BitBoxAction action;
  final BitBoxRouteParams? parameters;

  const BitBoxActionScreen({super.key, required this.action, this.parameters});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => BitBoxOperationCubit(
            scanBitBoxDevicesUsecase: locator<ScanBitBoxDevicesUsecase>(),
            connectBitBoxDeviceUsecase: locator<ConnectBitBoxDeviceUsecase>(),
          ),
      child: _BitBoxActionView(action: action, parameters: parameters),
    );
  }
}

class _BitBoxActionView extends StatefulWidget {
  final BitBoxAction action;
  final BitBoxRouteParams? parameters;

  const _BitBoxActionView({required this.action, this.parameters});

  @override
  State<_BitBoxActionView> createState() => _BitBoxActionViewState();
}

class _BitBoxActionViewState extends State<_BitBoxActionView> {
  ScriptType _selectedScriptType = ScriptType.bip84;

  @override
  void dispose() {
    try {
      final cubit = context.read<BitBoxOperationCubit>();
      cubit.disconnectIfConnected().catchError((e) {});
      cubit.close().catchError((e) {
        // Ignore errors during disposal
      });
    } catch (e) {
      // Ignore errors if context is no longer valid
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: widget.action.title,
          color: context.appColors.background,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<BitBoxOperationCubit, BitBoxOperationState>(
        listener: (context, state) {
          if (state.isSuccess) {
            SnackBarUtils.showSnackBar(context, widget.action.successText);
            if (widget.action == const BitBoxAction.importWallet()) {
              if (state.result is WatchOnlyWalletEntity &&
                  state.connectedDevice != null) {
                _navigateToImportPage(
                  context,
                  state.result as WatchOnlyWalletEntity,
                );
              }
            } else if (widget.action == const BitBoxAction.verifyAddress()) {
              Navigator.of(context).pop();
            } else if (widget.action == const BitBoxAction.signTransaction()) {
              Navigator.of(context).pop(state.result);
            }
          }
        },
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Center(
                child: Column(
                  children: [
                    const Gap(32),
                    _buildMainContent(context, state),
                    const Gap(32),
                    _buildActionButtons(context, state),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, BitBoxOperationState state) {
    return Column(
      children: [
        _buildIconsForState(context, state),
        const Gap(24),
        BBText(
          _getMainTextForState(state),
          textAlign: TextAlign.center,
          style: context.font.bodyLarge,
        ),
        const Gap(16),
        BBText(
          _getSubTextForState(state),
          textAlign: TextAlign.center,
          color: context.appColors.textMuted,
          style: context.font.bodyMedium,
        ),
        if (widget.action == const BitBoxAction.importWallet() &&
            state.isInitial) ...[
          const Gap(24),
          _buildScriptTypeButton(context),
        ],
        if (widget.action == const BitBoxAction.verifyAddress() &&
            state.isShowingAddressVerification) ...[
          const Gap(24),
          _buildAddressDisplay(context),
        ],
        if (state.isShowingPairingCode) ...[
          const Gap(24),
          _buildPairingCodeDisplay(context, state),
        ],
      ],
    );
  }

  Widget _buildIconsForState(BuildContext context, BitBoxOperationState state) {
    IconData icon;
    switch (state.status) {
      case BitBoxOperationStatus.initial:
        icon = Icons.usb;
      case BitBoxOperationStatus.scanning:
        icon = Icons.search;
      case BitBoxOperationStatus.connecting:
        icon = Icons.link;
      case BitBoxOperationStatus.processing:
        icon = Icons.sync;
      case BitBoxOperationStatus.showingPairingCode:
        icon = Icons.security;
      case BitBoxOperationStatus.waitingForPassword:
        icon = Icons.lock;
      case BitBoxOperationStatus.showingAddressVerification:
        icon = Icons.verified_user;
      case BitBoxOperationStatus.success:
        icon = Icons.check_circle;
      case BitBoxOperationStatus.error:
        icon = Icons.error;
    }

    return Icon(icon, size: 80, color: context.appColors.primary);
  }

  Widget _buildPairingCodeDisplay(
    BuildContext context,
    BitBoxOperationState state,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.appColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.primary.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: BBText(
            state.result?.toString() ?? '',
            textAlign: TextAlign.center,
            style: context.font.headlineMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: context.appColors.primary,
              letterSpacing: 2,
            ),
          ),
        ),
        const Gap(20),
        BBText(
          'Waiting for confirmation on BitBox02...',
          textAlign: TextAlign.center,
          color: context.appColors.textMuted.withValues(alpha: 0.7),
          style: context.font.bodyMedium,
        ),
      ],
    );
  }

  Future<void> _executeAction(BuildContext context) async {
    final cubit = context.read<BitBoxOperationCubit>();

    try {
      if (widget.action == const BitBoxAction.importWallet()) {
        await _executeImportWithPairing(context, cubit);
      } else if (widget.action == const BitBoxAction.verifyAddress()) {
        await _executeVerifyAddress(context, cubit);
      } else if (widget.action == const BitBoxAction.signTransaction()) {
        await _executeSignTransaction(context, cubit);
      }
    } catch (e) {
      log.warning('BitBox operation failed', error: e);
    }
  }

  void _navigateToImportPage(
    BuildContext context,
    WatchOnlyWalletEntity wallet,
  ) {
    if (context.mounted) {
      context.replaceNamed(
        ImportWatchOnlyWalletRoutes.import.name,
        extra: wallet,
      );
    }
  }

  Widget _buildAddressDisplay(BuildContext context) {
    String? address = widget.parameters?.address;

    if (widget.action == const BitBoxAction.verifyAddress() &&
        context
            .read<BitBoxOperationCubit>()
            .state
            .isShowingAddressVerification) {
      address = context.read<BitBoxOperationCubit>().state.result as String?;
    }

    if (address == null) return const SizedBox.shrink();

    return Column(
      children: [
        BBText(
          'Address to verify:',
          style: context.font.bodyMedium,
          color: context.appColors.textMuted.withValues(alpha: 0.8),
        ),
        const Gap(12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.appColors.border.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.appColors.border.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SelectableText(
            address
                .replaceAllMapped(
                  RegExp('.{1,4}'),
                  (match) => '${match.group(0)} ',
                )
                .trim(),
            style: context.font.bodyLarge?.copyWith(
              fontSize: 18,
              fontFamily: 'monospace',
              color: context.appColors.text,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Gap(12),
        BBText(
          'Please verify this address on your BitBox device',
          style: context.font.bodySmall,
          color: context.appColors.textMuted.withValues(alpha: 0.6),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _executeVerifyAddress(
    BuildContext context,
    BitBoxOperationCubit cubit,
  ) async {
    try {
      await cubit.executeOperation(() async {
        await _ensureDeviceReady(cubit);

        final device = cubit.state.connectedDevice!;
        final address = widget.parameters?.address;
        final derivationPath = widget.parameters?.derivationPath;
        final scriptType = widget.parameters?.scriptType ?? ScriptType.bip84;

        if (address == null) {
          throw Exception('Address is required for verification');
        }

        if (derivationPath == null) {
          throw Exception('Derivation path is required for verification');
        }

        cubit.showAddressVerification(address);

        return await locator<VerifyAddressBitBoxUsecase>().execute(
          device: device,
          address: address,
          derivationPath: derivationPath,
          scriptType: scriptType,
        );
      });
    } catch (e) {
      log.warning('BitBox verify address failed');
    }
  }

  Future<void> _executeSignTransaction(
    BuildContext context,
    BitBoxOperationCubit cubit,
  ) async {
    try {
      await cubit.executeOperation(() async {
        await _ensureDeviceReady(cubit);

        final device = cubit.state.connectedDevice!;
        final psbt = widget.parameters?.psbt;
        final derivationPath = widget.parameters?.derivationPath;
        final scriptType = widget.parameters?.scriptType ?? ScriptType.bip84;

        if (psbt == null) {
          throw Exception('PSBT is required for signing');
        }

        if (derivationPath == null) {
          throw Exception('Derivation path is required for signing');
        }
        return await locator<SignPsbtBitBoxUsecase>().execute(
          device,
          psbt: psbt,
          derivationPath: derivationPath,
          scriptType: scriptType,
        );
      });
    } catch (e) {
      log.warning('BitBox sign transaction failed');
    }
  }

  Future<void> _ensureDeviceReady(BitBoxOperationCubit cubit) async {
    try {
      await locator<BitBoxDeviceRepository>().getMasterFingerprint(
        cubit.state.connectedDevice!,
      );
    } catch (e) {
      cubit.showWaitingForPassword();

      final pairingCode = await locator<UnlockBitBoxDeviceUsecase>().execute(
        cubit.state.connectedDevice!,
      );

      if (pairingCode.isNotEmpty) {
        cubit.showPairingCode(pairingCode);

        await locator<PairBitBoxDeviceUsecase>().execute(
          cubit.state.connectedDevice!,
        );
      }
    }
    cubit.showProcessing();
  }

  Future<void> _executeImportWithPairing(
    BuildContext context,
    BitBoxOperationCubit cubit,
  ) async {
    try {
      await cubit.executeOperation(() async {
        await _ensureDeviceReady(cubit);

        final device = cubit.state.connectedDevice!;

        return await locator<GetBitBoxWatchOnlyWalletUsecase>().execute(
          device: device,
          deviceType: widget.parameters?.requestedDeviceType,
          label: 'BitBox Wallet',
          scriptType: _selectedScriptType,
        );
      });
    } catch (e) {
      log.severe('BitBox import with pairing failed');
    }
  }

  Widget _buildScriptTypeButton(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          children: [
            BBText(
              'Wallet Type:',
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
            ),
            const Gap(12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.appColors.border, width: 1),
              ),
              child: Material(
                color: context.appColors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showScriptTypeSelection(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: BBText(
                            _getScriptTypeDisplayName(_selectedScriptType),
                            style: context.font.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: context.appColors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getScriptTypeDisplayName(ScriptType scriptType) {
    switch (scriptType) {
      case ScriptType.bip84:
        return 'Segwit (BIP84)';
      case ScriptType.bip49:
        return 'Nested Segwit (BIP49)';
      default:
        return '';
    }
  }

  Future<void> _showScriptTypeSelection(BuildContext context) async {
    final scriptTypeItems = [
      const SelectableListItem(
        value: 'bip84',
        title: 'Segwit (BIP84)',
        subtitle1: 'Native SegWit - Recommended',
        subtitle2: '',
      ),
      const SelectableListItem(
        value: 'bip49',
        title: 'Nested Segwit (BIP49)',
        subtitle1: 'P2WPKH-nested-in-P2SH',
        subtitle2: '',
      ),
    ];

    final selected = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder:
          (BuildContext buildContext) => Padding(
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(16),
                    BBText(
                      'Select Wallet Type',
                      style: context.font.headlineMedium,
                    ),
                    const Gap(16),
                    SelectableList(
                      selectedValue: _selectedScriptType.name,
                      items: scriptTypeItems,
                    ),
                    const Gap(24),
                  ],
                ),
              ),
            ),
          ),
    );

    if (selected != null) {
      final newScriptType = ScriptType.fromName(selected);
      if (newScriptType != _selectedScriptType) {
        setState(() => _selectedScriptType = newScriptType);
      }
    }
  }

  void _showInstructions(BuildContext context) {
    InstructionsBottomSheet.show(
      context,
      title: 'BitBox02 Troubleshooting',
      subtitle:
          "First, make sure your BitBox02 device is connected to your phone USB port. If your device still doesn't connect with the app, try the following:",
      instructions: [
        'Make sure your phone has USB permissions enabled.',
        'Restart your BitBox02 device by unplugging and reconnecting it.',
        'Make sure you have the latest firmware installed on your BitBox.',
      ],
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      log.warning('Could not open app settings', error: e);
    }
  }

  Widget _buildActionButtons(BuildContext context, BitBoxOperationState state) {
    return Column(
      children: [
        if (state.isInitial)
          BBButton.big(
            onPressed: () => _executeAction(context),
            label: widget.action.buttonText,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError) ...[
          BBButton.big(
            onPressed: () => context.read<BitBoxOperationCubit>().reset(),
            label: 'Try Again',
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
          if (state.errorMessage ==
              const BitBoxError.permissionDenied().message) ...[
            const Gap(16),
            BBButton.big(
              onPressed: () => _openAppSettings(),
              label: 'Manage App Permissions',
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ],
        const Gap(16),
        if (state.isInitial || state.isError)
          BBButton.small(
            label: 'Need Help?',
            onPressed: () => _showInstructions(context),
            bgColor: context.appColors.surface,
            textColor: context.appColors.text,
            outlined: true,
          ),
      ],
    );
  }

  String _getMainTextForState(BitBoxOperationState state) {
    switch (state.status) {
      case BitBoxOperationStatus.initial:
        return 'Connect Your BitBox Device';
      case BitBoxOperationStatus.scanning:
        return 'Scanning for Devices';
      case BitBoxOperationStatus.connecting:
        return 'Connecting to BitBox';
      case BitBoxOperationStatus.processing:
        return widget.action.processingText;
      case BitBoxOperationStatus.showingPairingCode:
        return 'Pairing Code';
      case BitBoxOperationStatus.waitingForPassword:
        return 'Enter Password';
      case BitBoxOperationStatus.showingAddressVerification:
        return 'Verify Address';
      case BitBoxOperationStatus.success:
        return widget.action.successText;
      case BitBoxOperationStatus.error:
        return '${widget.action.title} Failed';
    }
  }

  String _getSubTextForState(BitBoxOperationState state) {
    switch (state.status) {
      case BitBoxOperationStatus.initial:
        return 'Make sure your BitBox02 is unlocked and connected via USB.';
      case BitBoxOperationStatus.scanning:
        return 'Looking for your BitBox device...';
      case BitBoxOperationStatus.connecting:
        return 'Establishing secure connection...';
      case BitBoxOperationStatus.processing:
        return widget.action.processingSubText;
      case BitBoxOperationStatus.showingPairingCode:
        return 'Verify this code matches your BitBox02 screen, then confirm on the device.';
      case BitBoxOperationStatus.waitingForPassword:
        return 'Please enter your password on the BitBox device to continue.';
      case BitBoxOperationStatus.showingAddressVerification:
        return 'Compare this address with your BitBox02 screen';
      case BitBoxOperationStatus.success:
        return widget.action.successSubText;
      case BitBoxOperationStatus.error:
        return state.errorMessage ?? 'Unknown error occurred';
    }
  }
}
