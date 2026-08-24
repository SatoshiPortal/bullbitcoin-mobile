import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_registration_options_usecase.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:satoshifier/utils/descriptor_checksum.dart';

class _MockBitcoinSigningPort extends Mock implements BitcoinSigningPort {}

void main() {
  late _MockBitcoinSigningPort bitcoinSigningPort;
  late GetWalletRegistrationOptionsUsecase usecase;

  setUp(() {
    bitcoinSigningPort = _MockBitcoinSigningPort();
    usecase = GetWalletRegistrationOptionsUsecase(
      bitcoinSigningPort: bitcoinSigningPort,
    );
  });

  test(
    'builds each assigned device registration format for multisig',
    () async {
      final wallet = _wallet(
        devices: const [
          SignerDeviceEntity.jade,
          SignerDeviceEntity.specter,
          SignerDeviceEntity.coldcardQ,
          SignerDeviceEntity.bitbox02,
          SignerDeviceEntity.ledgerNanoX,
        ],
      );
      final policy = _multisigPolicy(keyCount: 5);
      when(
        () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
      ).thenAnswer((_) async => Ok(policy));

      final result = await usecase.execute(wallet);

      final options =
          (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;
      expect(options.map((option) => option.device), [
        SignerDeviceEntity.jade,
        SignerDeviceEntity.specter,
        SignerDeviceEntity.coldcardQ,
        SignerDeviceEntity.bitbox02,
        SignerDeviceEntity.ledgerNanoX,
      ]);

      expect(
        options.whereType<ConnectedWalletRegistration>().map(
          (option) => option.device,
        ),
        [SignerDeviceEntity.bitbox02, SignerDeviceEntity.ledgerNanoX],
      );

      final jade = options.whereType<AvailableWalletRegistration>().singleWhere(
        (option) => option.device == SignerDeviceEntity.jade,
      );
      expect(jade.qrEncoding, WalletRegistrationQrEncoding.urBytes);
      expect(jade.fileData, contains('Policy: 2 of 5'));
      expect(jade.fileData, contains("Derivation: m/48'/0'/0'/2'"));
      expect(jade.fileData, contains('Format: P2WSH'));

      final specter = options
          .whereType<AvailableWalletRegistration>()
          .singleWhere((option) => option.device == SignerDeviceEntity.specter);
      expect(specter.qrEncoding, WalletRegistrationQrEncoding.urBytes);
      expect(specter.qrData, startsWith('addwallet Bull Wallet&'));
      expect(specter.qrData, contains('/{0,1}/*'));
      expect(specter.qrData, isNot(contains('/<0;1>/*')));

      final coldcard = options
          .whereType<AvailableWalletRegistration>()
          .singleWhere(
            (option) => option.device == SignerDeviceEntity.coldcardQ,
          );
      expect(coldcard.qrEncoding, WalletRegistrationQrEncoding.bbqrText);
      expect(coldcard.fileData, contains('/0/*'));
      expect(DescriptorChecksum.isValid(coldcard.fileData), isTrue);
    },
  );

  test(
    'limits Miniscript registration to devices with descriptor support',
    () async {
      final wallet = _wallet(
        devices: const [
          SignerDeviceEntity.krux,
          SignerDeviceEntity.specter,
          SignerDeviceEntity.passport,
          SignerDeviceEntity.jade,
          SignerDeviceEntity.seedsigner,
          SignerDeviceEntity.bitbox02,
          SignerDeviceEntity.ledgerNanoSPlus,
        ],
        miniscript: true,
        usesDisjointBranches: true,
      );
      final policy = _miniscriptPolicy();
      when(
        () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
      ).thenAnswer((_) async => Ok(policy));

      final result = await usecase.execute(wallet);

      final options =
          (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;
      expect(
        options.whereType<AvailableWalletRegistration>().map(
          (option) => option.device,
        ),
        [
          SignerDeviceEntity.krux,
          SignerDeviceEntity.specter,
          SignerDeviceEntity.passport,
        ],
      );
      final passport = options
          .whereType<AvailableWalletRegistration>()
          .singleWhere(
            (option) => option.device == SignerDeviceEntity.passport,
          );
      expect(passport.qrEncoding, WalletRegistrationQrEncoding.urBytes);
      expect(passport.qrData, wallet.publicDescriptor);
      expect(passport.fileData, wallet.publicDescriptor);
      final specter = options
          .whereType<AvailableWalletRegistration>()
          .singleWhere((option) => option.device == SignerDeviceEntity.specter);
      expect(specter.qrData, contains('/{2,3}/*'));
      expect(specter.qrData, isNot(contains('/<2;3>/*')));
      expect(
        options.whereType<UnavailableWalletRegistration>().map(
          (option) => option.device,
        ),
        [SignerDeviceEntity.jade, SignerDeviceEntity.seedsigner],
      );
      expect(
        options.whereType<UnavailableWalletRegistration>().map(
          (option) => option.reason,
        ),
        everyElement(WalletRegistrationUnavailableReason.unsupportedPolicy),
      );
      expect(
        options.whereType<ConnectedWalletRegistration>().map(
          (option) => option.device,
        ),
        [SignerDeviceEntity.bitbox02, SignerDeviceEntity.ledgerNanoSPlus],
      );
    },
  );

  test('limits Taproot registration to verified device formats', () async {
    final wallet = _wallet(
      devices: const [
        SignerDeviceEntity.krux,
        SignerDeviceEntity.specter,
        SignerDeviceEntity.passport,
        SignerDeviceEntity.jade,
        SignerDeviceEntity.seedsigner,
        SignerDeviceEntity.coldcardQ,
        SignerDeviceEntity.coldcardMk4,
        SignerDeviceEntity.bitbox02,
        SignerDeviceEntity.ledgerNanoSPlus,
      ],
      taproot: true,
    );
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(_multisigPolicy(keyCount: 8)));

    final result = await usecase.execute(wallet);

    final options =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;
    expect(
      options.whereType<AvailableWalletRegistration>().map(
        (option) => option.device,
      ),
      [SignerDeviceEntity.krux, SignerDeviceEntity.specter],
    );
    expect(
      options.whereType<UnavailableWalletRegistration>().map(
        (option) => option.device,
      ),
      [
        SignerDeviceEntity.passport,
        SignerDeviceEntity.jade,
        SignerDeviceEntity.seedsigner,
        SignerDeviceEntity.coldcardQ,
        SignerDeviceEntity.coldcardMk4,
      ],
    );
    expect(
      options.whereType<ConnectedWalletRegistration>().map(
        (option) => option.device,
      ),
      [SignerDeviceEntity.bitbox02, SignerDeviceEntity.ledgerNanoSPlus],
    );
  });

  test('does not offer Coldcard registration for Taproot', () async {
    final wallet = _wallet(
      devices: const [
        SignerDeviceEntity.coldcardQ,
        SignerDeviceEntity.coldcardMk4,
      ],
      taproot: true,
    );
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(_multisigPolicy(keyCount: 2)));

    final result = await usecase.execute(wallet);

    final options =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;
    expect(
      options.whereType<UnavailableWalletRegistration>().map(
        (option) => option.device,
      ),
      [SignerDeviceEntity.coldcardQ, SignerDeviceEntity.coldcardMk4],
    );
  });

  test('does not offer BitBox for nested unsorted multisig', () async {
    final wallet = _wallet(
      devices: const [
        SignerDeviceEntity.bitbox02,
        SignerDeviceEntity.ledgerNanoX,
      ],
      nestedUnsortedMultisig: true,
    );
    final policy = _multisigPolicy(keyCount: 2);
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(policy));

    final result = await usecase.execute(wallet);
    final options =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;

    expect(options.first, isA<UnavailableWalletRegistration>());
    expect(options.last, isA<ConnectedWalletRegistration>());
  });

  test('does not offer BitBox for a hashlock policy', () async {
    final wallet = _wallet(
      devices: const [
        SignerDeviceEntity.bitbox02,
        SignerDeviceEntity.ledgerNanoX,
      ],
      miniscript: true,
      hashlock: true,
    );
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(_miniscriptPolicy(hashlock: true)));

    final result = await usecase.execute(wallet);
    final options =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;

    expect(options.first, isA<UnavailableWalletRegistration>());
    expect(options.last, isA<ConnectedWalletRegistration>());
  });

  test('does not export Passport hashlock policies', () async {
    final wallet = _wallet(
      devices: const [SignerDeviceEntity.passport],
      miniscript: true,
    );
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(_miniscriptPolicy(hashlock: true)));

    final result = await usecase.execute(wallet);

    final option =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>)
            .value
            .single;
    expect(option, isA<UnavailableWalletRegistration>());
  });

  test(
    'preserves unhardened key suffixes in common multisig exports',
    () async {
      final wallet = _wallet(
        devices: const [SignerDeviceEntity.jade, SignerDeviceEntity.passport],
        keySuffix: '/5',
      );
      final policy = _multisigPolicy(keyCount: 2);
      when(
        () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
      ).thenAnswer((_) async => Ok(policy));
      final derivedXpub = Bip32Derivation.getBip32Xpub(
        _xpub,
      ).derivePath('5').toBase58();

      final result = await usecase.execute(wallet);

      final options =
          (result as Ok<List<WalletRegistrationOption>, SettingsFailure>).value;
      for (final option in options.whereType<AvailableWalletRegistration>()) {
        expect(option.fileData, contains("Derivation: m/48'/0'/0'/2'/5"));
        expect(option.fileData, contains(derivedXpub));
      }
    },
  );

  test('enforces SeedSigner quorum limits', () async {
    final tenKeyWallet = _wallet(
      origin: 'ten-key-wallet',
      devices: List.filled(10, SignerDeviceEntity.seedsigner),
    );
    final nineOfNineWallet = _wallet(
      origin: 'nine-key-wallet',
      devices: List.filled(9, SignerDeviceEntity.seedsigner),
      threshold: 9,
    );
    when(
      () => bitcoinSigningPort.getPolicy(walletId: tenKeyWallet.id),
    ).thenAnswer((_) async => Ok(_multisigPolicy(keyCount: 10)));
    when(
      () => bitcoinSigningPort.getPolicy(walletId: nineOfNineWallet.id),
    ).thenAnswer((_) async => Ok(_multisigPolicy(keyCount: 9, threshold: 9)));

    final tenKeyResult = await usecase.execute(tenKeyWallet);
    final nineOfNineResult = await usecase.execute(nineOfNineWallet);

    expect(
      (tenKeyResult as Ok<List<WalletRegistrationOption>, SettingsFailure>)
          .value
          .single,
      isA<UnavailableWalletRegistration>(),
    );
    expect(
      (nineOfNineResult as Ok<List<WalletRegistrationOption>, SettingsFailure>)
          .value
          .single,
      isA<AvailableWalletRegistration>(),
    );
  });

  test('limits Jade multisig names to fifteen characters', () async {
    final wallet = _wallet(
      devices: const [SignerDeviceEntity.jade, SignerDeviceEntity.jade],
      label: '1234567890abcdef',
    );
    final policy = _multisigPolicy(keyCount: 2);
    when(
      () => bitcoinSigningPort.getPolicy(walletId: wallet.id),
    ).thenAnswer((_) async => Ok(policy));

    final result = await usecase.execute(wallet);

    final option =
        (result as Ok<List<WalletRegistrationOption>, SettingsFailure>)
                .value
                .single
            as AvailableWalletRegistration;
    expect(option.fileData, contains('Name: 1234567890abcde\n'));
    expect(option.fileData, isNot(contains('Name: 1234567890abcdef\n')));
  });

  test('maps policy analysis failures to a settings failure', () async {
    final wallet = _wallet(devices: const [SignerDeviceEntity.jade]);
    when(() => bitcoinSigningPort.getPolicy(walletId: wallet.id)).thenAnswer(
      (_) async => const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
      ),
    );

    final result = await usecase.execute(wallet);

    expect(
      (result as Err<List<WalletRegistrationOption>, SettingsFailure>).failure,
      isA<SettingsWalletRegistrationFailure>(),
    );
  });
}

const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
const _hash =
    '1111111111111111111111111111111111111111111111111111111111111111';

Wallet _wallet({
  required List<SignerDeviceEntity> devices,
  String origin = 'wallet-id',
  String label = 'Bull Wallet',
  int threshold = 2,
  String keySuffix = '',
  bool miniscript = false,
  bool hashlock = false,
  bool nestedUnsortedMultisig = false,
  bool usesDisjointBranches = false,
  bool taproot = false,
}) {
  final signers = [
    for (final (index, device) in devices.indexed)
      WalletSigner.single(
        id: 'signer-$index',
        descriptorKeyId: 'key-$index',
        masterFingerprint: '${index + 1}'.padLeft(8, '0'),
        xpubFingerprint: '',
        xpub: _xpub,
        derivationPath: 'm/48h/0h/0h/2h',
        signer: SignerEntity.remote,
        signerDevice: device,
      ),
  ];
  final keys = signers.expand((signer) => signer.descriptorKeys).indexed.map((
    entry,
  ) {
    final key = entry.$2;
    final branches = usesDisjointBranches && entry.$1 == 1 ? '<2;3>' : '<0;1>';
    return '[${key.masterFingerprint}/48h/0h/0h/2h]'
        '${key.xpub}$keySuffix/$branches/*';
  }).toList();
  final miniscriptPolicy = hashlock
      ? 'and_v(v:pk(${keys.first}),sha256($_hash))'
      : keys.reversed
            .skip(1)
            .fold(
              'pk(${keys.last})',
              (policy, key) => 'or_d(pk($key),$policy)',
            );
  final body = taproot
      ? 'tr(${keys.first},multi_a($threshold,${keys.skip(1).join(',')}))'
      : miniscript
      ? 'wsh($miniscriptPolicy)'
      : nestedUnsortedMultisig
      ? 'sh(wsh(multi($threshold,${keys.join(',')})))'
      : 'wsh(sortedmulti($threshold,${keys.join(',')}))';
  final checksum = DescriptorChecksum.compute(body)!;
  return Wallet(
    origin: origin,
    label: label,
    network: Network.bitcoinMainnet,
    signers: signers,
    scriptType: null,
    publicDescriptor: '$body#$checksum',
    balanceSat: BigInt.zero,
  );
}

BitcoinWalletPolicy _multisigPolicy({
  required int keyCount,
  int threshold = 2,
}) {
  final root = BitcoinThresholdPolicyNode(
    id: 'root',
    threshold: threshold,
    children: [
      for (var index = 0; index < keyCount; index++)
        BitcoinSignaturePolicyNode(
          id: 'key-$index',
          key: BitcoinPolicyKey(
            kind: BitcoinPolicyKeyKind.descriptorKey,
            value: 'key-$index',
          ),
        ),
    ],
  );
  final spendingPolicy = BitcoinSpendingPolicy(root: root, requiresPath: false);
  return BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );
}

BitcoinWalletPolicy _miniscriptPolicy({bool hashlock = false}) {
  final root = BitcoinThresholdPolicyNode(
    id: 'root',
    threshold: 1,
    requiresPath: true,
    children: [
      BitcoinSignaturePolicyNode(
        id: 'key-0',
        key: BitcoinPolicyKey(
          kind: BitcoinPolicyKeyKind.descriptorKey,
          value: 'key-0',
        ),
      ),
      BitcoinThresholdPolicyNode(
        id: 'root/1',
        threshold: hashlock ? 3 : 2,
        children: [
          BitcoinRelativeTimelockPolicyNode(id: 'delay', value: 10),
          BitcoinSignaturePolicyNode(
            id: 'key-1',
            key: BitcoinPolicyKey(
              kind: BitcoinPolicyKeyKind.descriptorKey,
              value: 'key-1',
            ),
          ),
          if (hashlock)
            BitcoinHashlockPolicyNode(
              id: 'hashlock',
              type: BitcoinHashlockType.sha256,
              hash: _hash,
            ),
        ],
      ),
    ],
  );
  final spendingPolicy = BitcoinSpendingPolicy(root: root, requiresPath: true);
  return BitcoinWalletPolicy(
    external: spendingPolicy,
    internal: spendingPolicy,
  );
}
