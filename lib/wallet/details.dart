import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
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

  @override
  Widget build(BuildContext context) {
    final fingerPrint = context.select((WalletBloc _) => _.state.wallet?.sourceFingerprint ?? '');

    final descriptor =
        context.select((WalletBloc _) => _.state.wallet?.externalPublicDescriptor ?? '');
    final pub = keyFromDescriptor(descriptor);

    final addressType = context.select((WalletBloc _) => _.state.wallet!.scriptType);
    final addressTypeStr = scriptTypeString(addressType);

    final derivationPath = context.select((WalletBloc _) => _.state.wallet?.path ?? '');

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BBText.title('Wallet fingerprint'),
            BBText.body(fingerPrint, isBold: true),
            const Gap(16),
            const BBText.title('Wallet xpub'),
            BBText.body(pub, isBold: true),
            const Gap(16),
            const BBText.title('Descriptor'),
            BBText.body(descriptor, isBold: true),
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
