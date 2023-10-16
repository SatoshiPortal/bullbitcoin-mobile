import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    await Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final fingerPrint = context.select((WalletBloc _) => _.state.wallet?.sourceFingerprint ?? '');

    final descriptor =
        context.select((WalletBloc _) => _.state.wallet?.externalPublicDescriptor ?? '');
    final pub = keyFromDescriptor(descriptor);
    final scriptType = context.select((WalletBloc _) => _.state.wallet!.scriptType);
    final addressTypeStr = scriptTypeString(scriptType);
    final network = context.select((WalletBloc _) => _.state.wallet!.network);

    final derivationPath =
        context.select((WalletBloc _) => _.state.wallet?.derivationPathString() ?? '');
    final slipKey = convertToSlipPub(scriptType, network, pub);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBText.title('Wallet fingerprint'),
            BBText.body(fingerPrint, isBold: true),
            const Gap(16),
            const BBText.title('XPub'),
            BBText.body(slipKey ?? pub, isBold: true),
            BBButton.text(
              label: 'Copy',
              onPressed: () {
                copy(context, slipKey ?? pub);
              },
            ),
            const Gap(16),
            const BBText.title('Descriptor'),
            BBText.body(descriptor, isBold: true),
            BBButton.text(
              label: 'Copy',
              onPressed: () {
                copy(context, descriptor);
              },
            ),
            const Gap(16),
            const BBText.title('Address type'),
            BBText.body(addressTypeStr, isBold: true),
            const Gap(16),
            if (derivationPath.isNotEmpty) ...[
              const BBText.title('Derivation Path'),
              BBText.body(derivationPath, isBold: true),
              const Gap(16),
            ],
          ],
        ),
      ),
    );
  }
}
