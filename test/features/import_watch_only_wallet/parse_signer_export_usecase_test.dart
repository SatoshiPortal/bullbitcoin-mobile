import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/signer_export.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_signer_export_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show ScriptType;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class FakeWallet extends Fake implements WatchOnlyWalletEntity {
  @override
  ScriptType get scriptType => ScriptType.bip84;
}

void main() {
  test('SignerExport reads the derivation keys in a fixed order', () {
    final descriptors = SignerExport.descriptors(
      '{"bip44":"pkh(a)","xfp":"0f056943","bip84":"wpkh(b)","bip49":7}',
    );

    expect(descriptors, [
      (derivation: 'bip84', descriptor: 'wpkh(b)'),
      (derivation: 'bip44', descriptor: 'pkh(a)'),
    ]);
    expect(SignerExport.descriptors('wpkh(a)'), isEmpty);
    expect(SignerExport.descriptors('[1,2]'), isEmpty);
  });

  group('ParseSignerExportUsecase', () {
    test('parses every derivation of a JSON export', () async {
      final parsed = <String>[];
      final usecase = ParseSignerExportUsecase(
        parse: (input) async {
          parsed.add(input);
          return FakeWallet();
        },
        externalDescriptor: (_) => fail('not a single descriptor'),
      );

      final result = await usecase.execute(
        '{"bip84":"wpkh(b)","bip44":"pkh(a)"}',
      );

      final options = (result as Ok).value as List<SignerExportOption>;
      expect(options.map((option) => option.derivation), ['bip84', 'bip44']);
      expect(parsed, ['wpkh(b)', 'pkh(a)']);
    });

    test('drops a derivation that does not parse', () async {
      final usecase = ParseSignerExportUsecase(
        parse: (input) async =>
            input == 'bad' ? throw const FormatException('bad') : FakeWallet(),
        externalDescriptor: (_) => fail('not a single descriptor'),
      );

      final result = await usecase.execute('{"bip84":"wpkh(b)","bip44":"bad"}');

      final options = (result as Ok).value as List<SignerExportOption>;
      expect(options.map((option) => option.derivation), ['bip84']);
    });

    test('reads the external descriptor of a combined descriptor', () async {
      final parsed = <String>[];
      final usecase = ParseSignerExportUsecase(
        parse: (input) async {
          parsed.add(input);
          return FakeWallet();
        },
        externalDescriptor: (input) => '$input/0/*',
      );

      final result = await usecase.execute('wpkh(key)');

      final options = (result as Ok).value as List<SignerExportOption>;
      expect(options.single.derivation, 'bip84');
      expect(parsed, ['wpkh(key)/0/*']);
    });

    test('unreadable input is an invalid format', () async {
      final usecase = ParseSignerExportUsecase(
        parse: (_) async => FakeWallet(),
        externalDescriptor: (_) => throw const FormatException('no'),
      );

      final result = await usecase.execute('hello');

      expect((result as Err).failure, isA<InvalidFormatFailure>());
    });
  });
}
