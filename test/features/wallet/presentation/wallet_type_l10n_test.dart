import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/presentation/wallet_type_l10n.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Wallet _wallet(Network network, SignerEntity signer) => Wallet(
  origin: 'origin',
  network: network,
  xpubFingerprint: '00000000',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: '',
  internalPublicDescriptor: '',
  signer: signer,
  signerDevice: null,
  balanceSat: BigInt.zero,
);

void main() {
  testWidgets('names each kind of wallet card in the app language', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    String label(Network network, SignerEntity signer) =>
        _wallet(network, signer).typeLabel(context);

    expect(label(Network.bitcoinMainnet, SignerEntity.local), 'Réseau Bitcoin');
    expect(
      label(Network.liquidMainnet, SignerEntity.local),
      'Liquid et Lightning',
    );
    expect(label(Network.bitcoinMainnet, SignerEntity.none), 'Lecture seule');
    expect(
      label(Network.bitcoinMainnet, SignerEntity.remote),
      'Signataire externe',
    );
  });
}
