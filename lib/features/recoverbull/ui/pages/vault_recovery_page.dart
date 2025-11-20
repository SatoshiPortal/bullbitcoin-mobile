import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/wallet_status_widget.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class VaultRecoveryPage extends StatelessWidget {
  const VaultRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.recoverbullVaultRecovery)),
      body: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listenWhen:
            (previous, current) =>
                previous.error != current.error ||
                previous.isFlowFinished != current.isFlowFinished,
        listener: (context, state) {
          if (state.error != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.error!.toTranslated(context),
            );
            context.read<RecoverBullBloc>().add(const OnClearError());
          }
          if (state.isFlowFinished) {
            context.goNamed(WalletRoute.walletHome.name);
          }
        },
        builder: (context, state) {
          final bip84Status = state.bip84Status;
          final liquidStatus = state.liquidStatus;
          final isLoadingStatuses = bip84Status == null || liquidStatus == null;

          return Column(
            children: [
              FadingLinearProgress(
                trigger: isLoadingStatuses || state.isLoading,
                backgroundColor: context.colour.surface,
                foregroundColor: context.colour.primary,
                height: 2.0,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const Gap(40),
                      WalletStatusWidget(
                        bip84Status: bip84Status,
                        liquidStatus: liquidStatus,
                      ),
                      const Spacer(),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).size.height * 0.05,
                        ),
                        child: BBButton.big(
                          onPressed: () {
                            context.read<RecoverBullBloc>().add(
                              const OnVaultRecovery(),
                            );
                          },
                          label: context.loc.recoverbullContinue,
                          bgColor: context.colour.secondary,
                          textColor: context.colour.onPrimary,
                          disabled: state.decryptedVault == null,
                        ),
                      ),
                    ],
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
