import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_signer_details.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared key inspection and device metadata editing, without spending actions.
class WalletKeysView extends StatelessWidget {
  final Wallet wallet;
  final Widget Function(BuildContext, WalletSigner) signerSummaryBuilder;
  const WalletKeysView({
    super.key,
    required this.wallet,
    required this.signerSummaryBuilder,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ValueKey(wallet.id),
    create: (_) => locator<WalletDetailsCubit>(),
    child: BlocConsumer<WalletDetailsCubit, WalletDetailsState>(
      listener: (context, state) {
        if (state.signerUpdateFailure != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.loc.oopsSomethingWentWrong)),
          );
        }
      },
      builder: (context, state) => WalletSignerDetails.inspection(
        signers: (state.updatedWallet ?? wallet).signers,
        signerSummaryBuilder: signerSummaryBuilder,
        isUpdatingSignerDevice: state.isUpdatingSignerDevice,
        onSignerDeviceChanged: (signer, device) =>
            context.read<WalletDetailsCubit>().updateSignerDevice(
              walletId: wallet.id,
              signerId: signer.id,
              signerDevice: device,
            ),
      ),
    ),
  );
}
