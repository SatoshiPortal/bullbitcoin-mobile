import 'package:bb_mobile/features/experimental/import_watch_only_wallet/domain/usecases/import_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ImportScreen extends StatelessWidget {
  final ExtendedPublicKeyEntity pub;
  const ImportScreen({super.key, required this.pub});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => ImportWatchOnlyCubit(
            pub: pub,
            importWatchOnlyWalletUsecase:
                locator<ImportWatchOnlyWalletUsecase>(),
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
                Text('Extended Public Key', style: context.font.titleMedium),
                const SizedBox(height: 8),
                Text(state.pub.key, style: context.font.bodyMedium),
                const SizedBox(height: 16),
                Text('Type', style: context.font.titleMedium),
                const SizedBox(height: 8),
                Text(state.pub.type.name, style: context.font.bodyMedium),
                const SizedBox(height: 16),
                Text('Label', style: context.font.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  onChanged: cubit.updateLabel,
                  decoration: const InputDecoration(
                    hintText: 'label (optional)',
                  ),
                ),
                const Spacer(),
                BBButton.big(
                  onPressed: cubit.import,
                  label: 'Import',
                  bgColor: context.colour.primary,
                  textColor: context.colour.onPrimary,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
