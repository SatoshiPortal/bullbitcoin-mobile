import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/pop_until.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/features/recoverbull_select_vault/router.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/cubit.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/presentation/state.dart';
import 'package:bb_mobile/features/recoverbull_vault_recovery/ui/wallet_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class RecoverBullVaultRecoveryPage extends StatelessWidget {
  const RecoverBullVaultRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          onBack: () {
            popUntilPath(context, RecoverBullSelectVault.selectProvider.path);
          },
          title: "Recoverbull vault recovery",
        ),
      ),
      body: BlocBuilder<
        RecoverBullVaultRecoveryCubit,
        RecoverBullVaultRecoveryState
      >(
        builder: (context, state) {
          final cubit = context.read<RecoverBullVaultRecoveryCubit>();
          final status = state.bip84Status;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                WalletStatusWidget(status: status),
                const Spacer(),
                BBButton.big(
                  onPressed: cubit.importWallet,
                  label: 'Continue',
                  bgColor: context.colour.secondary,
                  textColor: context.colour.onPrimary,
                  disabled: state.decryptedVault == null || state.isImported,
                ),
                const Gap(20),
              ],
            ),
          );
        },
      ),
    );
  }
}
