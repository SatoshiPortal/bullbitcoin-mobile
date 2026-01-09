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
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
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
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: widget.action.getTitle(context),
          color: context.appColors.background,
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
              _getErrorMessage(context, state.errorMessage),
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
          _getMainTextForState(context, state),
          textAlign: .center,
          style: context.font.bodyLarge,
        ),
        const Gap(16),
        BBText(
          _getSubTextForState(context, state),
          textAlign: .center,
          color: context.appColors.textMuted,
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
        mainAxisSize: .min,
        children: [
          if (widget.parameters?.requestedDeviceType == null ||
              widget.parameters!.requestedDeviceType!.supportsBluetooth)
            Icon(Icons.bluetooth, size: 60, color: context.appColors.primary),
          if (!Platform.isIOS) ...[
            const Gap(16),
            Icon(Icons.usb, size: 60, color: context.appColors.primary),
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
          color: context.appColors.primary,
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

    return Icon(icon, size: 80, color: context.appColors.primary);
  }

  Widget _buildActionButtons(BuildContext context, LedgerOperationState state) {
    return Column(
      children: [
        if (state.isInitial)
          BBButton.big(
            onPressed: () => _startOperation(context),
            label: widget.action.getButtonText(context),
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
        if (state.isError) ...[
          BBButton.big(
            onPressed: () => context.read<LedgerOperationCubit>().reset(),
            label: context.loc.ledgerButtonTryAgain,
            bgColor: context.appColors.primary,
            textColor: context.appColors.onPrimary,
          ),
          if (state.errorMessage ==
              const LedgerError.permissionDenied().message) ...[
            const Gap(16),
            BBButton.big(
              onPressed: () => _openAppSettings(),
              label: context.loc.ledgerButtonManagePermissions,
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ],
        const Gap(16),
        if (state.isInitial || state.isError)
          BBButton.small(
            label: context.loc.ledgerButtonNeedHelp,
            onPressed: () => _showInstructions(context),
            bgColor: context.appColors.surface,
            textColor: context.appColors.text,
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
          context.loc.ledgerVerifyAddressLabel,
          style: context.font.bodyMedium,
          color: context.appColors.textMuted,
        ),
        const Gap(8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.border, width: 1),
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
          context.loc.ledgerWalletTypeLabel,
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
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Expanded(
                      child: BBText(
                        _getScriptTypeDisplayName(context, _selectedScriptType),
                        style: context.font.bodyLarge?.copyWith(
                          fontWeight: .w500,
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
    );
  }

  String _getScriptTypeDisplayName(
    BuildContext context,
    ScriptType scriptType,
  ) {
    switch (scriptType) {
      case ScriptType.bip84:
        return context.loc.ledgerWalletTypeSegwit;
      case ScriptType.bip49:
        return context.loc.ledgerWalletTypeNestedSegwit;
      case ScriptType.bip44:
        return context.loc.ledgerWalletTypeLegacy;
    }
  }

  Future<void> _showScriptTypeSelection(BuildContext context) async {
    final scriptTypeItems = [
      SelectableListItem(
        value: 'bip84',
        title: context.loc.ledgerWalletTypeSegwit,
        subtitle1: context.loc.ledgerWalletTypeSegwitDescription,
        subtitle2: '',
      ),
      SelectableListItem(
        value: 'bip49',
        title: context.loc.ledgerWalletTypeNestedSegwit,
        subtitle1: context.loc.ledgerWalletTypeNestedSegwitDescription,
        subtitle2: '',
      ),
      SelectableListItem(
        value: 'bip44',
        title: context.loc.ledgerWalletTypeLegacy,
        subtitle1: context.loc.ledgerWalletTypeLegacyDescription,
        subtitle2: '',
      ),
    ];

    final selected = await BlurredBottomSheet.show<String>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const Gap(16),
                BBText(
                  context.loc.ledgerWalletTypeSelectTitle,
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

  String _getMainTextForState(
    BuildContext context,
    LedgerOperationState state,
  ) {
    switch (state.status) {
      case LedgerOperationStatus.initial:
        return context.loc.ledgerConnectTitle;
      case LedgerOperationStatus.scanning:
        return context.loc.ledgerScanningTitle;
      case LedgerOperationStatus.connecting:
        return context.loc.ledgerConnectingMessage(state.connectedDevice!.name);
      case LedgerOperationStatus.processing:
        return widget.action.getProcessingText(context);
      case LedgerOperationStatus.success:
        return widget.action.getSuccessText(context);
      case LedgerOperationStatus.error:
        return context.loc.ledgerActionFailedMessage(
          widget.action.getTitle(context),
        );
    }
  }

  String _getSubTextForState(BuildContext context, LedgerOperationState state) {
    switch (state.status) {
      case LedgerOperationStatus.initial:
        return Platform.isIOS
            ? context.loc.ledgerInstructionsIos
            : (widget.parameters?.requestedDeviceType != null &&
                !widget.parameters!.requestedDeviceType!.supportsBluetooth)
            ? context.loc.ledgerInstructionsAndroidUsb
            : context.loc.ledgerInstructionsAndroidDual;
      case LedgerOperationStatus.scanning:
        return context.loc.ledgerScanningMessage;
      case LedgerOperationStatus.connecting:
        return context.loc.ledgerConnectingSubtext;
      case LedgerOperationStatus.processing:
        return widget.action.getProcessingSubtext(context);
      case LedgerOperationStatus.success:
        return widget.action.getSuccessSubtext(context);
      case LedgerOperationStatus.error:
        return _getErrorMessage(context, state.errorMessage);
    }
  }

  Future<void> _startOperation(BuildContext context) async {
    final cubit = context.read<LedgerOperationCubit>();
    await cubit.executeOperation(() {
      final connectedDevice = cubit.connectedDevice;

      if (connectedDevice == null) {
        throw Exception(context.loc.ledgerErrorNoConnection);
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
      label: context.loc.ledgerDefaultWalletLabel,
      device: device,
      scriptType: _selectedScriptType,
    );
  }

  Future<String> _executeSignTransaction(LedgerDeviceEntity device) {
    final psbt = widget.parameters?.psbt;
    final derivationPath = widget.parameters?.derivationPath;
    final scriptType = widget.parameters?.scriptType;

    if (psbt == null) {
      throw Exception(context.loc.ledgerErrorMissingPsbt);
    }

    if (derivationPath == null) {
      throw Exception(context.loc.ledgerErrorMissingDerivationPathSign);
    }

    if (scriptType == null) {
      throw Exception(context.loc.ledgerErrorMissingScriptTypeSign);
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
      throw Exception(context.loc.ledgerErrorMissingAddress);
    }

    if (derivationPath == null) {
      throw Exception(context.loc.ledgerErrorMissingDerivationPathVerify);
    }

    if (scriptType == null) {
      throw Exception(context.loc.ledgerErrorMissingScriptTypeVerify);
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
        SnackBarUtils.showSnackBar(
          context,
          context.loc.ledgerSuccessAddressVerified,
        );
        context.pop();
    }
  }

  void _showInstructions(BuildContext context) {
    InstructionsBottomSheet.show(
      context,
      title: context.loc.ledgerHelpTitle,
      subtitle: context.loc.ledgerHelpSubtitle,
      instructions: [
        context.loc.ledgerHelpStep1,
        context.loc.ledgerHelpStep2,
        context.loc.ledgerHelpStep3,
        context.loc.ledgerHelpStep4,
        context.loc.ledgerHelpStep5,
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

  String _getErrorMessage(BuildContext context, String? errorMessage) {
    if (errorMessage == null) {
      return context.loc.ledgerErrorUnknown;
    }

    // Check if the error message is a localization key from the cubit
    switch (errorMessage) {
      case 'LEDGER_ERROR_REJECTED_BY_USER':
        return context.loc.ledgerErrorRejectedByUser;
      case 'LEDGER_ERROR_DEVICE_LOCKED':
        return context.loc.ledgerErrorDeviceLocked;
      case 'LEDGER_ERROR_BITCOIN_APP_NOT_OPEN':
        return context.loc.ledgerErrorBitcoinAppNotOpen;
      default:
        // Return the error message as-is if it's not a localization key
        return errorMessage.isEmpty
            ? context.loc.ledgerErrorUnknown
            : errorMessage;
    }
  }
}
