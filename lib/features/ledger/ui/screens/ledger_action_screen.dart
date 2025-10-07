import 'dart:io';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_errors.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/connect_ledger_device_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/scan_ledger_devices_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/verify_address_ledger_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/instructions_bottom_sheet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/dropdown/selectable_list.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/ledger/ledger_action.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_cubit.dart';
import 'package:bb_mobile/features/ledger/presentation/cubit/ledger_operation_state.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

class LedgerRouteParams {
  final String? psbt;
  final String? derivationPath;
  final String? address;
  final SignerDeviceEntity? requestedDeviceType;
  final ScriptType? scriptType;

  const LedgerRouteParams({
    this.psbt,
    this.derivationPath,
    this.address,
    this.requestedDeviceType,
    this.scriptType,
  });
}

class LedgerActionScreen extends StatelessWidget {
  final LedgerAction action;
  final LedgerRouteParams? parameters;

  const LedgerActionScreen({super.key, required this.action, this.parameters});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => LedgerOperationCubit(
            scanLedgerDevicesUsecase: locator<ScanLedgerDevicesUsecase>(),
            connectLedgerDeviceUsecase: locator<ConnectLedgerDeviceUsecase>(),
            requestedDeviceType: parameters?.requestedDeviceType,
          ),
      child: _LedgerActionView(action: action, parameters: parameters),
    );
  }
}

class _LedgerActionView extends StatefulWidget {
  final LedgerAction action;
  final LedgerRouteParams? parameters;

  const _LedgerActionView({required this.action, this.parameters});

  @override
  State<_LedgerActionView> createState() => _LedgerActionViewState();
}

class _LedgerActionViewState extends State<_LedgerActionView> {
  ScriptType _selectedScriptType = ScriptType.bip84;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: widget.action.title,
          color: context.colour.surface,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocConsumer<LedgerOperationCubit, LedgerOperationState>(
        listener: (context, state) {
          if (state.isSuccess) {
            if (!context.mounted) return;
            context.read<LedgerOperationCubit>().reset();
            _handleSuccess(context, state.result);
          } else if (state.isError) {
            SnackBarUtils.showSnackBar(
              context,
              state.errorMessage ?? 'Unknown error',
            );
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

  Widget _buildMainContent(BuildContext context, LedgerOperationState state) {
    return Column(
      children: [
        _buildnIconsForState(context, state),
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
          color: context.colour.onSurfaceVariant,
          style: context.font.bodyMedium,
        ),
        if (widget.action is VerifyAddressLedgerAction && state.isProcessing)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildAddressDisplay(context),
          ),
        if (widget.action is ImportWalletLedgerAction && state.isInitial)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildScriptTypeButton(context),
          ),
      ],
    );
  }

  Widget _buildnIconsForState(
    BuildContext context,
    LedgerOperationState state,
  ) {
    if (state.status == LedgerOperationStatus.initial) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.parameters?.requestedDeviceType == null ||
              widget.parameters!.requestedDeviceType!.supportsBluetooth)
            Icon(Icons.bluetooth, size: 60, color: context.colour.primary),
          if (!Platform.isIOS) ...[
            const Gap(16),
            Icon(Icons.usb, size: 60, color: context.colour.primary),
          ],
        ],
      );
    }

    if (state.status == LedgerOperationStatus.scanning ||
        state.status == LedgerOperationStatus.connecting) {
      return SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          color: context.colour.primary,
          strokeWidth: 3,
        ),
      );
    }

    IconData icon;
    switch (state.status) {
      case LedgerOperationStatus.processing:
        icon = _getProcessingIcon();
      case LedgerOperationStatus.success:
        icon = Icons.check_circle;
      case LedgerOperationStatus.error:
        icon = Icons.error;
      default:
        return Container();
    }

    return Icon(icon, size: 80, color: context.colour.primary);
  }

  Widget _buildActionButtons(BuildContext context, LedgerOperationState state) {
    return Column(
      children: [
        if (state.isInitial)
          BBButton.big(
            onPressed: () => _startOperation(context),
            label: widget.action.buttonText,
            bgColor: context.colour.primary,
            textColor: context.colour.onPrimary,
          ),
        if (state.isError) ...[
          BBButton.big(
            onPressed: () => context.read<LedgerOperationCubit>().reset(),
            label: 'Try Again',
            bgColor: context.colour.primary,
            textColor: context.colour.onPrimary,
          ),
          if (state.errorMessage ==
              const LedgerError.permissionDenied().message) ...[
            const Gap(16),
            BBButton.big(
              onPressed: () => _openAppSettings(),
              label: 'Manage App Permissions',
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
          ],
        ],
        const Gap(16),
        if (state.isInitial || state.isError)
          BBButton.small(
            label: 'Need Help?',
            onPressed: () => _showInstructions(context),
            bgColor: context.colour.onSecondary,
            textColor: context.colour.onSurface,
            outlined: true,
          ),
      ],
    );
  }

  Widget _buildAddressDisplay(BuildContext context) {
    final address = widget.parameters?.address;

    if (address == null) return const SizedBox.shrink();

    return Column(
      children: [
        BBText(
          'Address to verify:',
          style: context.font.bodyMedium,
          color: context.colour.onSurfaceVariant,
        ),
        const Gap(8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colour.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.colour.outline, width: 1),
          ),
          child: SelectableText(
            address
                .replaceAllMapped(
                  RegExp('.{1,4}'),
                  (match) => '${match.group(0)} ',
                )
                .trim(),
            style: context.font.bodyLarge?.copyWith(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildScriptTypeButton(BuildContext context) {
    return Column(
      children: [
        BBText(
          'Wallet Type:',
          style: context.font.bodyMedium,
          color: context.colour.onSurfaceVariant,
        ),
        const Gap(12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colour.onSecondary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.colour.outline,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showScriptTypeSelection(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      color: context.colour.onSurfaceVariant,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getScriptTypeDisplayName(ScriptType scriptType) {
    switch (scriptType) {
      case ScriptType.bip84:
        return 'Segwit (BIP84)';
      case ScriptType.bip49:
        return 'Nested Segwit (BIP49)';
      case ScriptType.bip44:
        return 'Legacy (BIP44)';
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
      const SelectableListItem(
        value: 'bip44',
        title: 'Legacy (BIP44)',
        subtitle1: 'P2PKH - Older format',
        subtitle2: '',
      ),
    ];

    final selected = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colour.onSecondary,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (BuildContext buildContext) => Padding(
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

  IconData _getProcessingIcon() {
    switch (widget.action) {
      case ImportWalletLedgerAction():
        return Icons.download;
      case SignTransactionLedgerAction():
        return Icons.edit;
      case VerifyAddressLedgerAction():
        return Icons.verified_user;
    }
  }

  String _getMainTextForState(LedgerOperationState state) {
    switch (state.status) {
      case LedgerOperationStatus.initial:
        return 'Connect Your Ledger Device';
      case LedgerOperationStatus.scanning:
        return 'Scanning for Devices';
      case LedgerOperationStatus.connecting:
        return 'Connecting to ${state.connectedDevice!.name}';
      case LedgerOperationStatus.processing:
        return widget.action.processingText;
      case LedgerOperationStatus.success:
        return widget.action.successText;
      case LedgerOperationStatus.error:
        return '${widget.action.title} Failed';
    }
  }

  String _getSubTextForState(LedgerOperationState state) {
    switch (state.status) {
      case LedgerOperationStatus.initial:
        return Platform.isIOS
            ? 'Make sure your Ledger is unlocked with the Bitcoin app opened and Bluetooth enabled.'
            : (widget.parameters?.requestedDeviceType != null &&
                !widget.parameters!.requestedDeviceType!.supportsBluetooth)
            ? 'Make sure your Ledger is unlocked with the Bitcoin app opened and connect it via USB.'
            : 'Make sure your Ledger is unlocked with the Bitcoin app opened and Bluetooth enabled, or connect the device via USB.';
      case LedgerOperationStatus.scanning:
        return 'Looking for Ledger devices nearby...';
      case LedgerOperationStatus.connecting:
        return 'Establishing secure connection...';
      case LedgerOperationStatus.processing:
        return widget.action.processingSubText;
      case LedgerOperationStatus.success:
        return widget.action.successSubText;
      case LedgerOperationStatus.error:
        return state.errorMessage ?? 'Unknown error occurred';
    }
  }

  Future<void> _startOperation(BuildContext context) async {
    final cubit = context.read<LedgerOperationCubit>();
    await cubit.executeOperation(() {
      final connectedDevice = cubit.connectedDevice;

      if (connectedDevice == null) {
        throw Exception('No Ledger connection available');
      }

      return _executeAction(connectedDevice);
    });
  }

  Future<dynamic> _executeAction(LedgerDeviceEntity device) {
    switch (widget.action) {
      case ImportWalletLedgerAction():
        return _executeImportWallet(device);
      case SignTransactionLedgerAction():
        return _executeSignTransaction(device);
      case VerifyAddressLedgerAction():
        return _executeVerifyAddress(device);
    }
  }

  Future<WatchOnlyWalletEntity> _executeImportWallet(
    LedgerDeviceEntity device,
  ) {
    return locator<GetLedgerWatchOnlyWalletUsecase>().execute(
      label: 'Ledger Wallet',
      device: device,
      scriptType: _selectedScriptType,
    );
  }

  Future<String> _executeSignTransaction(LedgerDeviceEntity device) {
    final psbt = widget.parameters?.psbt;
    final derivationPath = widget.parameters?.derivationPath;
    final scriptType = widget.parameters?.scriptType;

    if (psbt == null) {
      throw Exception('PSBT is required for signing');
    }

    if (derivationPath == null) {
      throw Exception('Derivation path is required for signing');
    }

    if (scriptType == null) {
      throw Exception('Script type is required for signing');
    }

    final result = locator<SignPsbtLedgerUsecase>().execute(
      device,
      psbt: psbt,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
    return result;
  }

  Future<bool> _executeVerifyAddress(LedgerDeviceEntity device) {
    final address = widget.parameters?.address;
    final derivationPath = widget.parameters?.derivationPath;
    final scriptType = widget.parameters?.scriptType;

    if (address == null) {
      throw Exception('Address is required for verification');
    }

    if (derivationPath == null) {
      throw Exception('Derivation path is required for verification');
    }

    if (scriptType == null) {
      throw Exception('Script type is required for verification');
    }

    return locator<VerifyAddressLedgerUsecase>().execute(
      device: device,
      address: address,
      derivationPath: derivationPath,
      scriptType: scriptType,
    );
  }

  void _handleSuccess(BuildContext context, dynamic result) {
    switch (widget.action) {
      case ImportWalletLedgerAction():
        context.pushNamed(
          ImportWatchOnlyWalletRoutes.import.name,
          extra: result,
        );
      case SignTransactionLedgerAction():
        context.pop(result);
      case VerifyAddressLedgerAction():
        SnackBarUtils.showSnackBar(context, 'Address verified successfully!');
        context.pop();
    }
  }

  void _showInstructions(BuildContext context) {
    InstructionsBottomSheet.show(
      context,
      title: 'Ledger Troubleshooting',
      subtitle:
          "First, make sure your Ledger device is unlocked and the Bitcoin app is opened. If your device still doesn't connect with the app, try the following:",
      instructions: [
        'Restart your Ledger device.',
        'Make sure your phone has Bluetooth turned on and permitted.',
        'Make sure your Ledger has Bluetooth turned on.',
        'Make sure you have installed the latest version of the Bitcoin app from Ledger Live.',
        'Make sure your Ledger device is using the latest firmware, you can update the firmware using the Ledger Live desktop app.',
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
}
