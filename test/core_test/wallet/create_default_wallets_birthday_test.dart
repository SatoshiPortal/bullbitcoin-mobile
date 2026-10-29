import 'dart:typed_data';

import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Seeds extends Mock implements SeedRepository {}

class _Settings extends Mock implements SettingsRepository {}

class _Generator extends Mock implements MnemonicGenerator {}

class _Wallets extends Mock implements WalletRepository {}

void main() {
  final seed = MnemonicSeed(
    mnemonicWords: const [],
    bytes: Uint8List(0),
    masterFingerprint: 'deadbeef',
  );
  setUpAll(() {
    registerFallbackValue(seed);
    registerFallbackValue(Network.bitcoinMainnet);
    registerFallbackValue(ScriptType.bip84);
    registerFallbackValue(BitcoinSyncSource.electrum);
  });

  for (final generated in [false, true]) {
    for (final known in [false, true]) {
      test(
        'default wallets preserve birthdays (generated=$generated, known=$known)',
        () async {
          final seeds = _Seeds();
          final settings = _Settings();
          final generator = _Generator();
          final wallets = _Wallets();
          final supplied = known
              ? WalletBirthday(DateTime.parse('2020-03-02T01:30:00+02:00'))
              : null;
          when(() => settings.fetch()).thenAnswer(
            (_) async => const SettingsEntity(
              environment: Environment.mainnet,
              bitcoinUnit: BitcoinUnit.sats,
              currencyCode: 'USD',
            ),
          );
          when(
            () => wallets.getWallets(
              onlyDefaults: true,
              environment: Environment.mainnet,
            ),
          ).thenAnswer((_) async => const Ok([]));
          when(() => generator.generate()).thenReturn(const []);
          when(
            () => seeds.createFromMnemonic(
              mnemonicWords: any(named: 'mnemonicWords'),
              passphrase: any(named: 'passphrase'),
            ),
          ).thenAnswer((_) async => seed);
          final birthdays = <WalletBirthday?>[];
          final sources = <BitcoinSyncSource>[];
          when(
            () => wallets.createWallet(
              seed: seed,
              network: any(named: 'network'),
              scriptType: ScriptType.bip84,
              isDefault: true,
              birthday: any(named: 'birthday'),
              bitcoinSyncSource: any(named: 'bitcoinSyncSource'),
            ),
          ).thenAnswer((invocation) async {
            final birthday =
                invocation.namedArguments[#birthday] as WalletBirthday?;
            birthdays.add(birthday);
            sources.add(
              invocation.namedArguments[#bitcoinSyncSource]
                  as BitcoinSyncSource,
            );
            return Wallet(
              origin: 'public',
              network: invocation.namedArguments[#network] as Network,
              xpubFingerprint: 'deadbeef',
              scriptType: ScriptType.bip84,
              xpub: 'public',
              externalPublicDescriptor: 'public',
              internalPublicDescriptor: 'public',
              signer: SignerEntity.none,
              signerDevice: null,
              balanceSat: BigInt.zero,
              birthday: birthday?.dateTime,
            );
          });
          final before = DateTime.now().toUtc();
          final result =
              await CreateDefaultWalletsUsecase(
                seedRepository: seeds,
                settingsRepository: settings,
                mnemonicGenerator: generator,
                walletRepository: wallets,
              ).execute(
                mnemonicWords: generated ? null : const [],
                birthday: supplied,
                bitcoinSyncSource: BitcoinSyncSource.compactBlockFilters,
              );
          expect(result, hasLength(2));
          expect(birthdays, hasLength(2));
          expect(sources, [
            BitcoinSyncSource.compactBlockFilters,
            BitcoinSyncSource.electrum,
          ]);
          expect(birthdays[0], birthdays[1]);
          if (generated) {
            for (final birthday in birthdays) {
              expect(birthday, isNotNull);
              expect(birthday?.dateTime.isUtc, isTrue);
              expect(birthday?.dateTime.isBefore(before), isFalse);
              expect(
                birthday?.dateTime.isAfter(DateTime.now().toUtc()),
                isFalse,
              );
            }
          } else {
            expect(birthdays, [supplied, supplied]);
          }
        },
      );
    }
  }
}
