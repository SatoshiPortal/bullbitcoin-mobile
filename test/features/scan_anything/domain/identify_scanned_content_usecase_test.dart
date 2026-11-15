import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/public/import_watch_only_facade.dart';
import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';
import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bb_mobile/features/scan_anything/domain/usecases/identify_scanned_content_usecase.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart'
    show DetectBitcoinStringUsecase;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Wallet;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:primitives/primitives.dart' show Err, Ok, Result;

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';
const _xprv =
    'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi';
const _wif = '5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ';
const _xpub =
    'xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7';
final _txid = 'ab' * 32;
final _rawTx = '02' * 100;

class FakeExistingWallet extends Fake implements Wallet {}

class FakeDescriptorEntity extends Fake implements WatchOnlyDescriptorEntity {}

class FakeXpubEntity extends Fake implements WatchOnlyXpubEntity {}

class FakeParseWatchOnly implements ParseWatchOnlyInputUsecase {
  final inputs = <String>[];
  WatchOnlyWalletEntity? answer;

  @override
  Future<Result<WatchOnlyWalletEntity, ImportWatchOnlyFailure>> execute(
    String input,
  ) async {
    inputs.add(input);
    final wallet = answer;
    return wallet == null ? const Err(InvalidFormatFailure()) : Ok(wallet);
  }
}

class FakeParseSignerExport implements ParseSignerExportUsecase {
  final inputs = <String>[];
  List<SignerExportOption> answer = const [];

  @override
  Future<Result<List<SignerExportOption>, ImportWatchOnlyFailure>> execute(
    String input,
  ) async {
    inputs.add(input);
    return answer.isEmpty ? const Err(InvalidFormatFailure()) : Ok(answer);
  }
}

class FakeDetect implements DetectBitcoinStringUsecase {
  final inputs = <String>[];
  PaymentRequest? answer;

  @override
  Future<PaymentRequest> execute({
    required String data,
    primitives.NetworkEnv? environment,
  }) async {
    inputs.add(data);
    final request = answer;
    if (request == null) throw const FormatException('unsupported');
    return request;
  }
}

void main() {
  late FakeParseWatchOnly parseWatchOnly;
  late FakeDetect detect;
  late FakeParseSignerExport parseSignerExport;
  late bool canSendSilentPayment;
  late Wallet? importedWallet;
  late List<String> rawTransactionInputs;
  late bool isRawTransaction;
  late IdentifyScannedContentUsecase usecase;

  setUp(() {
    parseWatchOnly = FakeParseWatchOnly();
    detect = FakeDetect();
    parseSignerExport = FakeParseSignerExport();
    canSendSilentPayment = false;
    importedWallet = null;
    rawTransactionInputs = [];
    isRawTransaction = false;
    usecase = IdentifyScannedContentUsecase(
      parseWatchOnlyInputUsecase: parseWatchOnly,
      parseSignerExportUsecase: parseSignerExport,
      detectBitcoinStringUsecase: detect,
      canSendSilentPayment: () async => canSendSilentPayment,
      findImportedWallet: (_) async => importedWallet,
      hasSwapSource: ({required fromLiquid}) async => fromLiquid,
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
      isRawTransaction: (hex) async {
        rawTransactionInputs.add(hex);
        return isRawTransaction;
      },
    );
  });

  Future<ScannedContent> identify(String input) async {
    final result = await usecase.execute(input);
    expect(result, isA<Ok<ScannedContent, ScanAnythingFailure>>());
    return (result as Ok<ScannedContent, ScanAnythingFailure>).value;
  }

  Future<ScanAnythingFailure> failureOf(String input) async {
    final result = await usecase.execute(input);
    expect(result, isA<Err<ScannedContent, ScanAnythingFailure>>());
    return (result as Err<ScannedContent, ScanAnythingFailure>).failure;
  }

  void expectNoParserCalled() {
    expect(parseWatchOnly.inputs, isEmpty);
    expect(parseSignerExport.inputs, isEmpty);
    expect(detect.inputs, isEmpty);
    expect(rawTransactionInputs, isEmpty);
  }

  test('empty input is refused', () async {
    expect(await failureOf('   '), isA<ScanAnythingEmptyInputFailure>());
    expectNoParserCalled();
  });

  test('a recovery phrase carries no data and reaches no parser', () async {
    final content = await identify('  $_mnemonic\n');

    expect(content, isA<RecoveryPhraseContent>());
    expect(content.copyText, isNull);
    expectNoParserCalled();
  });

  test('twelve words with a bad checksum are not a recovery phrase', () async {
    final words = List.filled(12, 'abandon').join(' ');

    expect(await failureOf(words), isA<ScanAnythingUnrecognizedFailure>());
  });

  test('an extended private key reaches no parser', () async {
    final content = await identify(_xprv);

    expect(content, isA<PrivateKeyContent>());
    expect(content.copyText, isNull);
    expectNoParserCalled();
  });

  test('a descriptor with a private key reaches no parser', () async {
    final content = await identify('wpkh([86241f88/84h/0h/0h]$_xprv/0/*)');

    expect(content, isA<PrivateKeyContent>());
    expectNoParserCalled();
  });

  test('a WIF key reaches no parser', () async {
    expect(await identify(_wif), isA<PrivateKeyContent>());
    expectNoParserCalled();
  });

  test('64 hex characters are a transaction ID', () async {
    final content = await identify(_txid.toUpperCase());

    expect(content, isA<TransactionIdContent>());
    expect((content as TransactionIdContent).txid, _txid);
    expectNoParserCalled();
  });

  test('longer hex that parses is a signed transaction', () async {
    isRawTransaction = true;

    final content = await identify(_rawTx);

    expect(content, isA<SignedTransactionContent>());
    expect((content as SignedTransactionContent).hex, _rawTx);
    expect(detect.inputs, isEmpty);
  });

  test('hex that does not parse goes on to the next parsers', () async {
    expect(await failureOf(_rawTx), isA<ScanAnythingUnrecognizedFailure>());
    expect(rawTransactionInputs, [_rawTx]);
    expect(detect.inputs, [_rawTx]);
  });

  test('a descriptor is identified through the watch-only parser', () async {
    final wallet = FakeDescriptorEntity();
    parseWatchOnly.answer = wallet;

    final content = await identify('wpkh([86241f88/84h/0h/0h]$_xpub/<0;1>/*)');

    expect(content, isA<DescriptorContent>());
    expect((content as DescriptorContent).wallet, same(wallet));
    expect(detect.inputs, isEmpty);
  });

  test('a descriptor of an imported wallet carries that wallet', () async {
    final existing = FakeExistingWallet();
    importedWallet = existing;
    parseWatchOnly.answer = FakeDescriptorEntity();

    final content = await identify('wpkh([86241f88/84h/0h/0h]$_xpub/<0;1>/*)');

    expect((content as DescriptorContent).existingWallet, same(existing));
  });

  test('an xpub is identified through the watch-only parser', () async {
    final wallet = FakeXpubEntity();
    parseWatchOnly.answer = wallet;

    final content = await identify(_xpub);

    expect(content, isA<XpubContent>());
    expect((content as XpubContent).wallet, same(wallet));
  });

  test('a signer export with several derivations keeps every option', () async {
    final options = [
      SignerExportOption(derivation: 'bip84', wallet: FakeDescriptorEntity()),
      SignerExportOption(derivation: 'bip44', wallet: FakeDescriptorEntity()),
    ];
    parseSignerExport.answer = options;
    final export = '{"bip84":"wpkh($_xpub)","bip44":"pkh($_xpub)"}';

    final content = await identify(export);

    expect(content, isA<SignerExportContent>());
    content as SignerExportContent;
    expect(content.options, options);
    expect(content.existingWallet, isNull);
    expect(content.copyText, export);
    expect(detect.inputs, isEmpty);
  });

  test('a signer export with one derivation is a descriptor', () async {
    final wallet = FakeDescriptorEntity();
    parseSignerExport.answer = [
      SignerExportOption(derivation: 'bip84', wallet: wallet),
    ];

    final content = await identify('{"bip84":"wpkh($_xpub)"}');

    expect(content, isA<DescriptorContent>());
    expect((content as DescriptorContent).wallet, same(wallet));
  });

  test('a silent payment address carries the send gate', () async {
    final address = 'sp1q${'q' * 112}';

    final hidden = await identify(address);
    expect(hidden, isA<SilentPaymentAddressContent>());
    expect((hidden as SilentPaymentAddressContent).canSend, isFalse);
    expect(hidden.network, Network.bitcoinMainnet);

    canSendSilentPayment = true;
    final test = await identify('t$address');
    expect((test as SilentPaymentAddressContent).canSend, isTrue);
    expect(test.network, Network.bitcoinTestnet);
    expect(detect.inputs, isEmpty);
  });

  test('Electrum server forms are recognized', () async {
    final ssl = await identify('ssl://electrum.example.com:50002');
    expect(ssl, isA<ElectrumServerContent>());
    ssl as ElectrumServerContent;
    expect(ssl.serverInput, 'electrum.example.com:50002:s');
    expect(ssl.copyText, 'ssl://electrum.example.com:50002');

    final tcp = await identify('tcp://10.0.0.5:50001');
    expect((tcp as ElectrumServerContent).serverInput, '10.0.0.5:50001:t');

    final onion = await identify('${'a' * 56}.onion:50001');
    expect((onion as ElectrumServerContent).useSsl, isFalse);

    final suffix = await identify('electrum.example.com:50002:s');
    expect((suffix as ElectrumServerContent).useSsl, isTrue);
    expect(detect.inputs, isEmpty);
  });

  test('a plain host and port and a web URL are not a server', () async {
    expect(
      await failureOf('example.com:443'),
      isA<ScanAnythingUnrecognizedFailure>(),
    );
    expect(
      await failureOf('https://mempool.space'),
      isA<ScanAnythingUnrecognizedFailure>(),
    );
  });

  test('a BIP329 export is counted and reaches no parser', () async {
    final jsonl =
        '{"type":"tx","ref":"$_txid","label":"rent"}\n'
        '{"type":"xpub","ref":"$_xpub","label":"cold"}\n';

    final content = await identify(jsonl);

    expect(content, isA<LabelsExportContent>());
    expect((content as LabelsExportContent).count, 2);
    expect(content.copyText, isNull);
    expectNoParserCalled();
  });

  test('JSON lines that are not labels are not a label export', () async {
    expect(
      await failureOf('{"type":"other","ref":"x"}'),
      isA<ScanAnythingUnrecognizedFailure>(),
    );
  });

  test('text without a public key skips the watch-only parser', () async {
    detect.answer = const PaymentRequest.lnAddress(address: 'sat@example.com');

    await identify('sat@example.com');

    expect(parseWatchOnly.inputs, isEmpty);
  });

  group('payment requests', () {
    test('Bitcoin address', () async {
      detect.answer = const PaymentRequest.bitcoin(
        address: 'tb1qaddress',
        isTestnet: true,
      );

      final content = await identify('tb1qaddress');

      expect(content, isA<BitcoinAddressContent>());
      content as BitcoinAddressContent;
      expect(content.address, 'tb1qaddress');
      expect(content.canSwap, isTrue);
      expect(content.network, Network.bitcoinTestnet);
    });

    test('Liquid address', () async {
      detect.answer = const PaymentRequest.liquid(
        address: 'lq1address',
        isTestnet: false,
      );

      final content = await identify('lq1address');

      expect(content, isA<LiquidAddressContent>());
      expect((content as LiquidAddressContent).network, Network.liquidMainnet);
      expect(content.canSwap, isFalse);
    });

    test('BIP21 URI', () async {
      detect.answer = const PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qaddress?amount=0.001',
        address: 'bc1qaddress',
        amountSat: 100000,
        label: 'shop',
        lightning: 'lnbc1',
        pj: 'https://payjoin.example',
      );

      final content = await identify('bitcoin:bc1qaddress?amount=0.001');

      expect(content, isA<Bip21Content>());
      content as Bip21Content;
      expect(content.address, 'bc1qaddress');
      expect(content.amountSat, 100000);
      expect(content.label, 'shop');
      expect(content.hasLightning, isTrue);
      expect(content.hasPayjoin, isTrue);
      expect(content.copyText, 'bitcoin:bc1qaddress?amount=0.001');
    });

    test('a bare regtest address is a Bitcoin address', () async {
      detect.answer = const PaymentRequest.bip21(
        network: Network.bitcoinRegtest,
        uri: 'bcrt1qaddress',
        address: 'bcrt1qaddress',
      );

      final content = await identify('bcrt1qaddress');

      expect(content, isA<BitcoinAddressContent>());
      expect(
        (content as BitcoinAddressContent).network,
        Network.bitcoinRegtest,
      );
    });

    test('Lightning invoice', () async {
      detect.answer = const PaymentRequest.bolt11(
        invoice: 'lnbc1invoice',
        amountSat: 2500,
        paymentHash: 'hash',
        description: 'coffee',
        expiresAt: 1800000000,
        isTestnet: false,
      );

      final content = await identify('lnbc1invoice');

      expect(content, isA<LightningInvoiceContent>());
      content as LightningInvoiceContent;
      expect(content.amountSat, 2500);
      expect(content.description, 'coffee');
      expect(
        content.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1800000000 * 1000),
      );
      expect(content.isExpired, isFalse);
    });

    test('an invoice past its expiry is expired', () async {
      detect.answer = const PaymentRequest.bolt11(
        invoice: 'lnbc1invoice',
        amountSat: 2500,
        paymentHash: 'hash',
        expiresAt: 1600000000,
        isTestnet: false,
      );

      final content = await identify('lnbc1invoice');

      expect((content as LightningInvoiceContent).isExpired, isTrue);
    });

    test('Lightning address', () async {
      detect.answer = const PaymentRequest.lnAddress(
        address: 'sat@example.com',
      );

      final content = await identify('sat@example.com');

      expect(content, isA<LightningAddressContent>());
      expect(content.copyText, 'sat@example.com');
    });

    test('PSBT', () async {
      detect.answer = const PaymentRequest.psbt(psbt: 'cHNidP8B');

      final content = await identify('cHNidP8B');

      expect(content, isA<PsbtContent>());
      expect(content.copyText, 'cHNidP8B');
    });
  });

  test('unknown text and web URLs are not recognized', () async {
    expect(
      await failureOf('https://example.com'),
      isA<ScanAnythingUnrecognizedFailure>(),
    );
    expect(
      await failureOf('hello world'),
      isA<ScanAnythingUnrecognizedFailure>(),
    );
  });
}
