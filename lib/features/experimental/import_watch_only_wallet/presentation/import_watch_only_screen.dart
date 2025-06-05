import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ImportWatchOnlyScreen extends StatelessWidget {
  final WatchOnlyWalletEntity? watchOnlyWallet;
  const ImportWatchOnlyScreen({super.key, this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => ImportWatchOnlyCubit(
            watchOnlyWallet: watchOnlyWallet,
            importWatchOnlyUsecase: locator<ImportWatchOnlyUsecase>(),
          ),
      child: const _ImportScreenContent(),
    );
  }
}

class _ImportScreenContent extends StatelessWidget {
  const _ImportScreenContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        title: const Text('Import Watch Only Wallet'),
        backgroundColor: context.colour.surface,
      ),
      body: BlocConsumer<ImportWatchOnlyCubit, ImportWatchOnlyState>(
        listener: (context, state) {
          if (state.error.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: context.colour.error,
              ),
            );
          }
          if (state.importedWallet != null) {
            context.goNamed(WalletRoute.walletHome.name);
          }
        },
        builder: (context, state) {
          final cubit = context.read<ImportWatchOnlyCubit>();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.watchOnlyWallet == null)
                  _buildInputZone(context, cubit)
                else
                  Expanded(
                    child: _buildWalletDetails(
                      context,
                      state.watchOnlyWallet!,
                      cubit,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputZone(BuildContext context, ImportWatchOnlyCubit cubit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBInputText(
          onlyPaste: true,
          onChanged: cubit.updateLabel,
          value: cubit.state.publicKey,
          maxLines: 1,
          maxLength: 111,
        ),
        const SizedBox(height: 8),
        const BBText(
          'Enter a valid extended public key (xpub / ypub / zpub) that is 111 characters long',
          style: null,
        ),
      ],
    );
  }

  Widget _buildWalletDetails(
    BuildContext context,
    WatchOnlyWalletEntity wallet,
    ImportWatchOnlyCubit cubit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(wallet.pubkey, style: null),
                BBText(wallet.fingerprint, style: null),
                BBText(wallet.type.name, style: null),
                BBText(wallet.label, style: null),

                // Text('Extended Public Key', style: context.font.titleMedium),
                // const SizedBox(height: 8),
                // Text(wallet.pubkey, style: context.font.bodyMedium),
                // const SizedBox(height: 16),
                // Text('Type', style: context.font.titleMedium),
                // const SizedBox(height: 8),
                // Text(wallet.type.name, style: context.font.bodyMedium),
                // const SizedBox(height: 16),
                // Text('Label', style: context.font.titleMedium),
                // const SizedBox(height: 8),
                BBInputText(
                  onChanged: cubit.updateLabel,
                  value: wallet.label,
                  hint: 'label (optional)',
                  maxLines: 1,
                  maxLength: 111,
                ),

                BBInputText(
                  onChanged: cubit.overrideFingerprint,
                  value: wallet.fingerprint,
                  maxLines: 1,
                  hint: 'fingerprint',
                  maxLength: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        BBButton.big(
          onPressed: cubit.import,
          label: 'Import',
          bgColor: context.colour.primary,
          textColor: context.colour.onPrimary,
        ),
      ],
    );
  }
}
