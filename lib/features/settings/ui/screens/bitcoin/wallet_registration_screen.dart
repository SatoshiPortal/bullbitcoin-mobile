import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_registration_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/settings_failure_l10n.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_registration_export_bottom_sheet.dart';
import 'package:bb_mobile/features/bitbox/public/bitbox_facade.dart';
import 'package:bb_mobile/features/ledger/public/ledger_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WalletRegistrationScreen extends StatelessWidget {
  final Wallet wallet;

  const WalletRegistrationScreen({super.key, required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.walletRegistrationTitle)),
      body: SafeArea(
        child: BlocBuilder<WalletRegistrationCubit, WalletRegistrationState>(
          builder: (context, state) =>
              switch ((state.isLoading, state.failure)) {
                (true, _) => const Center(child: CircularProgressIndicator()),
                (false, final failure?) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    BullInfoCard(
                      description: failure.toTranslated(context),
                      tagColor: context.appColors.error,
                      bgColor: context.appColors.errorContainer,
                    ),
                    const Gap(16),
                    BullButton.big(
                      label: context.loc.retry,
                      onPressed: () =>
                          context.read<WalletRegistrationCubit>().load(wallet),
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                    ),
                  ],
                ),
                (false, null) => _RegistrationOptions(
                  wallet: wallet,
                  options: state.options,
                ),
              },
        ),
      ),
    );
  }
}

class WalletRegistrationWalletNotFoundScreen extends StatelessWidget {
  const WalletRegistrationWalletNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.walletRegistrationTitle)),
      body: SafeArea(
        child: Center(
          child: Text(context.loc.walletDeletionErrorWalletNotFound),
        ),
      ),
    );
  }
}

class _RegistrationOptions extends StatelessWidget {
  final Wallet wallet;
  final List<WalletRegistrationOption> options;

  const _RegistrationOptions({required this.wallet, required this.options});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          context.loc.walletRegistrationDescription,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(24),
        if (options.isEmpty)
          BullInfoCard(
            description: context.loc.walletRegistrationNoDevices,
            tagColor: context.appColors.secondary,
            bgColor: context.appColors.onSecondary,
          )
        else
          for (final (index, option) in options.indexed) ...[
            BullBorderedTile(
              onTap: () => _openOption(context, option),
              child: Row(
                children: [
                  Icon(_optionIcon(option), color: context.appColors.secondary),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.loc.walletRegistrationDeviceAction(
                            _deviceName(context, option),
                          ),
                          style: context.font.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          option is ConnectedWalletRegistration
                              ? context.loc.walletRegistrationConnectDevice
                              : option is AvailableWalletRegistration
                              ? context.loc.walletRegistrationAvailable
                              : context.loc.walletRegistrationUnavailable,
                          style: context.font.bodyMedium?.copyWith(
                            color: context.appColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(8),
                  Icon(Icons.chevron_right, color: context.appColors.textMuted),
                ],
              ),
            ),
            if (index != options.length - 1) const Gap(12),
          ],
      ],
    );
  }

  String _deviceName(BuildContext context, WalletRegistrationOption option) {
    if (option.device.isLedger) return context.loc.hwLedger;
    return option.device.displayName;
  }

  IconData _optionIcon(WalletRegistrationOption option) => switch (option) {
    ConnectedWalletRegistration() => Icons.usb,
    AvailableWalletRegistration(
      qrEncoding: WalletRegistrationQrEncoding.none,
    ) =>
      Icons.nfc,
    AvailableWalletRegistration() => Icons.qr_code_2,
    UnavailableWalletRegistration() => Icons.info_outline,
  };

  Future<void> _openOption(
    BuildContext context,
    WalletRegistrationOption option,
  ) async {
    if (option is! ConnectedWalletRegistration) {
      await WalletRegistrationExportBottomSheet.show(context, option);
      return;
    }
    if (option.device.isBitBox) {
      const facade = BitBoxFacade();
      await context.pushNamed(
        facade.registerWalletPolicyRouteName,
        extra: RegisterBitBoxWalletPolicyRequest(wallet),
      );
      return;
    }
    const facade = LedgerFacade();
    await context.pushNamed(
      facade.registerWalletPolicyRouteName,
      extra: RegisterLedgerWalletPolicyRequest(
        wallet,
        requestedDeviceType: _singleLedgerDeviceType(),
      ),
    );
  }

  SignerDeviceEntity? _singleLedgerDeviceType() {
    final devices = wallet.signers
        .map((signer) => signer.signerDevice)
        .whereType<SignerDeviceEntity>()
        .where((device) => device.isLedger)
        .toSet();
    return devices.length == 1 ? devices.single : null;
  }
}
