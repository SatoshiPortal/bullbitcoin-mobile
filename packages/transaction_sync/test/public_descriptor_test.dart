import 'package:primitives/primitives.dart';
import 'package:test/test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test(
    'Liquid descriptor preserves privacy material and redacts diagnostics',
    () {
      // Deliberately non-key placeholders: contract test, not native parsing.
      const descriptor = 'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(public))';
      LiquidWalletDescriptor createLiquid(
        String value, {
        Network network = LiquidNetwork.mainnet,
      }) => LiquidWalletDescriptor(
        key: WalletKey(id: 'origin', network: network),
        scriptType: ScriptType.bip84,
        origin: 'origin',
        combinedCtDescriptor: value,
      );
      final wallet = createLiquid(descriptor);
      expect(wallet.combinedCtDescriptor, descriptor);
      expect(wallet, createLiquid(descriptor));
      expect(wallet.hashCode, createLiquid(descriptor).hashCode);
      expect(wallet.toString(), 'LiquidWalletDescriptor(<redacted>)');
      expect(wallet.toString(), isNot(contains('PRIVACY_PLACEHOLDER')));
      expect(
        () => createLiquid(descriptor, network: BitcoinNetwork.mainnet),
        throwsArgumentError,
      );
      expect(() => createLiquid('elwpkh(public)'), throwsArgumentError);
      const rejected = 'ct(slip77(PRIVACY_PLACEHOLDER),elwpkh(xprvINVALID))';
      expect(
        () => createLiquid(rejected),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.toString(),
            'redacted failure',
            isNot(contains('PRIVACY_PLACEHOLDER')),
          ),
        ),
      );
    },
  );
  BitcoinWalletDescriptor create(
    String descriptor, {
    Network network = BitcoinNetwork.mainnet,
  }) => BitcoinWalletDescriptor(
    key: WalletKey(id: 'origin', network: network),
    scriptType: ScriptType.bip84,
    origin: 'origin',
    externalDescriptor: descriptor,
    internalDescriptor: descriptor,
  );

  test(
    'descriptor contract refuses private-key encodings without echoing input',
    () {
      // Non-key strings exercise rejection; no private fixture is stored here.
      for (final prefix in [
        'xprv',
        'tprv',
        'yprv',
        'zprv',
        'uprv',
        'vprv',
        'Yprv',
        'Zprv',
        'Uprv',
        'Vprv',
      ]) {
        final rejected = 'wpkh(${prefix}INVALID)';
        expect(
          () => create(rejected),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString().contains(rejected),
              'does not echo descriptor',
              isFalse,
            ),
          ),
        );
      }
      for (final prefix in ['5', 'K', 'L', 'c', '9']) {
        expect(() => create('wpkh($prefix${'1' * 51})'), throwsArgumentError);
      }
      expect(() => create(''), throwsArgumentError);
      expect(() => create('wpkh(public)'), returnsNormally);
      expect(
        () => create('wpkh(public)', network: LiquidNetwork.mainnet),
        throwsArgumentError,
      );
    },
  );
}
