import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class WalletDetailsPage extends StatelessWidget {
  const WalletDetailsPage({super.key, required this.walletBloc});

  final WalletBloc walletBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: walletBloc,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          flexibleSpace: BBAppBar(
            text: 'Wallet Details',
            onBack: () {
              context.pop();
            },
          ),
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  void copy(BuildContext context, String text) async {
    if (locator.isRegistered<Clippboard>()) {
      await locator<Clippboard>().copy(text);
    }

    // ScaffoldMessenger.of(context)
    //     .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final fingerPrint = context
        .select((WalletBloc _) => _.state.wallet?.sourceFingerprint ?? '');

    final descriptorCombined = context.select(
      (WalletBloc _) => _.state.wallet?.getDescriptorCombined() ?? '',
    );
    final descriptor = context.select(
      (WalletBloc _) => _.state.wallet?.externalPublicDescriptor ?? '',
    );
    final pub = keyFromDescriptor(descriptor);
    final scriptType =
        context.select((WalletBloc _) => _.state.wallet!.scriptType);
    final addressTypeStr = scriptTypeString(scriptType);
    final network = context.select((WalletBloc _) => _.state.wallet!.network);

    final derivationPath = context
        .select((WalletBloc _) => _.state.wallet?.derivationPathString() ?? '');
    final slipKey = convertToSlipPub(scriptType, network, pub);

    final showFingerprint = !fingerPrint.toLowerCase().contains('unknown');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showFingerprint) ...[
              const BBText.title('Wallet fingerprint'),
              BBText.bodySmall(fingerPrint),
              const Gap(16),
            ],
            const BBText.title('Pubkey'),
            BBText.bodySmall(slipKey ?? pub),
            BBButton.text(
              label: 'Copy',
              onPressed: () {
                copy(context, slipKey ?? pub);
              },
            ),
            const Gap(16),
            const BBText.title('Descriptor'),
            BBText.bodySmall(descriptorCombined),
            BBButton.text(
              label: 'Copy',
              onPressed: () {
                copy(context, descriptorCombined);
              },
            ),
            const Gap(16),
            const BBText.title('Address type'),
            BBText.bodySmall(addressTypeStr),
            const Gap(16),
            if (derivationPath.isNotEmpty) ...[
              const BBText.title('Derivation Path'),
              BBText.bodySmall(derivationPath),
              const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}
