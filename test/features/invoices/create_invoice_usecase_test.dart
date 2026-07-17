import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/liquid_receive_address_with_blinding_secret.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/application/usecases/create_invoice_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_url.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockIdentity extends Mock implements InvoicesIdentityPort {}

class _MockPayService extends Mock implements InvoicesPayServicePort {}

class _MockWalletRepo extends Mock implements WalletRepository {}

class _MockAddrRepo extends Mock implements WalletAddressRepository {}

class _MockLabels extends Mock implements LabelsFacade {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

class _MockWallet extends Mock implements Wallet {}

class _MockSettings extends Mock implements SettingsEntity {}

T _unwrap<T>(Result<T, InvoicesFailure> result) => result.fold(
  (value) => value,
  (failure) => throw TestFailure('expected Ok, got $failure'),
);

InvoicesFailure _unwrapFailure<T>(Result<T, InvoicesFailure> result) =>
    result.fold(
      (_) => throw TestFailure('expected Err, got Ok'),
      (failure) => failure,
    );

void main() {
  final signer = BullnymAuthSigner(
    npubHex: 'aa' * 32,
    signHashHex: (_) => 'bb' * 64,
  );

  setUpAll(() {
    registerFallbackValue(
      CreateInvoiceCommand(
        amountSat: 1000,
        acceptBtc: false,
        acceptLn: false,
        acceptLiquid: true,
        expiresAt: DateTime.utc(2030),
      ),
    );
    registerFallbackValue(
      BullnymAuthSigner(npubHex: '00' * 32, signHashHex: (_) => ''),
    );
    registerFallbackValue(NewLabel.addr(address: 'x', label: 'y'));
  });

  late _MockIdentity identity;
  late _MockPayService payService;
  late _MockWalletRepo walletRepo;
  late _MockAddrRepo addrRepo;
  late _MockLabels labels;
  late _MockGetSettings getSettings;
  late CreateInvoiceUsecase usecase;
  late int nextLabelId;

  final btcWallet = _MockWallet();
  final liquidWallet = _MockWallet();
  final btcWalletAddress = WalletAddress(
    walletId: 'btc-default',
    index: 0,
    address: 'bc1qfresh',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  final result = CreateInvoiceResult(
    invoiceId: InvoiceId('inv-1'),
    shareUrl: InvoiceUrl('https://bullpay.ca/invoice/inv-1'),
  );

  CreateInvoiceCommand command({
    int? amountSat = 1000,
    int? fiatAmountMinor,
    String? fiatCurrency,
    bool acceptBtc = false,
    bool acceptLn = false,
    bool acceptLiquid = true,
    String? privateMemo,
  }) {
    return CreateInvoiceCommand(
      amountSat: amountSat,
      fiatAmountMinor: fiatAmountMinor,
      fiatCurrency: fiatCurrency,
      acceptBtc: acceptBtc,
      acceptLn: acceptLn,
      acceptLiquid: acceptLiquid,
      expiresAt: DateTime.utc(2030),
      privateMemo: privateMemo,
    );
  }

  setUp(() {
    identity = _MockIdentity();
    payService = _MockPayService();
    walletRepo = _MockWalletRepo();
    addrRepo = _MockAddrRepo();
    labels = _MockLabels();
    getSettings = _MockGetSettings();
    usecase = CreateInvoiceUsecase(
      identity: identity,
      payService: payService,
      walletRepository: walletRepo,
      walletAddressRepository: addrRepo,
      labels: labels,
      getSettings: getSettings,
    );

    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(() => identity.getSigningHandle()).thenAnswer((_) async => Ok(signer));

    when(() => btcWallet.id).thenReturn('btc-default');
    when(() => liquidWallet.id).thenReturn('liquid-default');

    // The DEFAULT wallet lookups: bitcoin vs liquid disambiguated by the flag.
    when(
      () => walletRepo.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    ).thenAnswer((invocation) async {
      final onlyLiquid = invocation.namedArguments[#onlyLiquid] as bool?;
      return onlyLiquid == true ? [liquidWallet] : [btcWallet];
    });

    when(
      () =>
          addrRepo.generateNewReceiveAddress(walletId: any(named: 'walletId')),
    ).thenAnswer((_) async => btcWalletAddress);
    when(
      () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer(
      (_) async => const LiquidReceiveAddressWithBlindingSecret(
        address: 'lq1qfresh',
        blindingSecretHex:
            '1111111111111111111111111111111111111111111111111111111111111111',
      ),
    );

    when(
      () => payService.createInvoice(
        signer: any(named: 'signer'),
        command: any(named: 'command'),
        bitcoinAddress: any(named: 'bitcoinAddress'),
        liquidAddress: any(named: 'liquidAddress'),
        liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
      ),
    ).thenAnswer((_) async => Ok(result));

    // Labels store/trash default to success: the address reservation (system
    // label) written at generation persists, and any release is a no-op.
    nextLabelId = 1;
    when(() => labels.store(any())).thenAnswer((invocation) async {
      final newLabel = invocation.positionalArguments.first as NewLabel;
      return Ok<Label, LabelFailure>(
        Label.addr(
          id: nextLabelId++,
          address: newLabel.reference,
          label: newLabel.label,
          origin: newLabel.origin,
        ),
      );
    });
    when(
      () => labels.trash(any()),
    ).thenAnswer((_) async => const Ok<Null, LabelFailure>(null));
  });

  // A NewLabel matcher for the correctness-critical Liquid address reservation
  // (the system label), as opposed to the best-effort private-memo label.
  Matcher isReservationLabel() =>
      predicate<NewLabel>((l) => l.label == LabelSystem.invoice.label);
  Matcher isMemoLabel() =>
      predicate<NewLabel>((l) => l.label != LabelSystem.invoice.label);

  group('payout discipline (DG-I2 / §8.1/§8.2)', () {
    test('sources addresses ONLY from onlyDefaults wallets', () async {
      _unwrap(await usecase.execute(command(acceptLiquid: true)));

      final calls = verify(
        () => walletRepo.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: captureAny(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyLiquid: any(named: 'onlyLiquid'),
        ),
      ).captured;
      // Every wallet lookup pins onlyDefaults:true — never a reserved descriptor.
      expect(calls, everyElement(isTrue));
    });

    test(
      'Liquid rail: fresh confidential address + blinding secret supplied',
      () async {
        _unwrap(await usecase.execute(command(acceptLiquid: true)));

        final captured = verify(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: any(named: 'command'),
            bitcoinAddress: captureAny(named: 'bitcoinAddress'),
            liquidAddress: captureAny(named: 'liquidAddress'),
            liquidBlindingKeyHex: captureAny(named: 'liquidBlindingKeyHex'),
          ),
        ).captured;
        expect(captured[0], isNull); // no BTC address for a Liquid-only invoice
        expect(captured[1], 'lq1qfresh');
        expect(
          captured[2],
          '1111111111111111111111111111111111111111111111111111111111111111',
        );
        verify(
          () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
            walletId: 'liquid-default',
          ),
        ).called(1);
      },
    );

    test(
      'LN-only invoice supplies the Liquid address without the secret',
      () async {
        _unwrap(
          await usecase.execute(command(acceptLn: true, acceptLiquid: false)),
        );

        final captured = verify(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: any(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: captureAny(named: 'liquidAddress'),
            liquidBlindingKeyHex: captureAny(named: 'liquidBlindingKeyHex'),
          ),
        ).captured;
        expect(captured[0], 'lq1qfresh');
        expect(
          captured[1],
          isNull,
        ); // §3.5/§3.19: key sent only when acceptLiquid
      },
    );

    test('BTC rail: fresh address from the DEFAULT bitcoin wallet', () async {
      _unwrap(
        await usecase.execute(command(acceptBtc: true, acceptLiquid: false)),
      );

      verify(
        () => addrRepo.generateNewReceiveAddress(walletId: 'btc-default'),
      ).called(1);
      final captured = verify(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
          bitcoinAddress: captureAny(named: 'bitcoinAddress'),
          liquidAddress: any(named: 'liquidAddress'),
          liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
        ),
      ).captured;
      expect(captured.single, 'bc1qfresh');
    });
  });

  group('orchestration order + linked-vs-unlinked', () {
    test(
      'validates → signer → addresses → wire (signer resolved once)',
      () async {
        _unwrap(await usecase.execute(command(acceptLiquid: true)));
        verify(() => identity.getSigningHandle()).called(1);
        verify(
          () => payService.createInvoice(
            signer: signer,
            command: any(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: any(named: 'liquidAddress'),
            liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
          ),
        ).called(1);
      },
    );

    test(
      'v1 is unlinked: the command carries no nym (linkToPageNym null)',
      () async {
        _unwrap(await usecase.execute(command(acceptLiquid: true)));
        final captured = verify(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: captureAny(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: any(named: 'liquidAddress'),
            liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
          ),
        ).captured;
        final sent = captured.single as CreateInvoiceCommand;
        expect(sent.linkToPageNym, isNull);
      },
    );

    test(
      'identity failure short-circuits before settings and wire work',
      () async {
        when(
          () => identity.getSigningHandle(),
        ).thenAnswer((_) async => const Err(InvoicesFailure.signingFailed()));

        final failure = _unwrapFailure(
          await usecase.execute(command(acceptLiquid: true)),
        );

        expect(failure.kind, InvoicesFailureKind.signingFailed);
        verifyNever(() => getSettings.execute());
        verifyNever(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: any(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: any(named: 'liquidAddress'),
            liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
          ),
        );
      },
    );
  });

  group('local pre-validation (§3.6/§3.8)', () {
    test('no rail selected → invalidInput, zero wire calls', () async {
      final failure = _unwrapFailure(
        await usecase.execute(
          command(acceptBtc: false, acceptLn: false, acceptLiquid: false),
        ),
      );
      expect(failure.kind, InvoicesFailureKind.invalidInput);
      verifyNever(() => identity.getSigningHandle());
      verifyNever(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
        ),
      );
    });

    test('both amount forms → invalidInput', () async {
      final failure = _unwrapFailure(
        await usecase.execute(
          command(amountSat: 1000, fiatAmountMinor: 500, fiatCurrency: 'CAD'),
        ),
      );
      expect(failure.kind, InvoicesFailureKind.invalidInput);
    });

    test('neither amount form → invalidInput', () async {
      final failure = _unwrapFailure(
        await usecase.execute(command(amountSat: null)),
      );
      expect(failure.kind, InvoicesFailureKind.invalidInput);
    });
  });

  group('missing default wallets', () {
    test('BTC rail with no default bitcoin wallet → typed error', () async {
      when(
        () => walletRepo.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyLiquid: any(named: 'onlyLiquid'),
        ),
      ).thenAnswer((_) async => []);

      final failure = _unwrapFailure(
        await usecase.execute(command(acceptBtc: true, acceptLiquid: false)),
      );
      expect(failure.kind, InvoicesFailureKind.noDefaultBitcoinWallet);
    });

    test('Liquid rail with no default liquid wallet → typed error', () async {
      when(
        () => walletRepo.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyLiquid: any(named: 'onlyLiquid'),
        ),
      ).thenAnswer((_) async => []);

      final failure = _unwrapFailure(
        await usecase.execute(command(acceptLiquid: true)),
      );
      expect(failure.kind, InvoicesFailureKind.noDefaultLiquidWallet);
    });
  });

  group('used-address single retry (§7.2)', () {
    test('reused Liquid address regenerates ONCE and retries', () async {
      var call = 0;
      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
          bitcoinAddress: any(named: 'bitcoinAddress'),
          liquidAddress: any(named: 'liquidAddress'),
          liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
        ),
      ).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return const Err(InvoicesFailure.reusedLiquidAddress());
        }
        return Ok(result);
      });

      final r = _unwrap(await usecase.execute(command(acceptLiquid: true)));

      expect(r.invoiceId.value, 'inv-1');
      // one initial + one regenerate = two address derivations.
      verify(
        () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
          walletId: 'liquid-default',
        ),
      ).called(2);
    });

    test(
      'a SECOND reuse propagates the typed error (no infinite loop)',
      () async {
        when(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: any(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: any(named: 'liquidAddress'),
            liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
          ),
        ).thenAnswer(
          (_) async => const Err(InvoicesFailure.reusedLiquidAddress()),
        );

        final failure = _unwrapFailure(
          await usecase.execute(command(acceptLiquid: true)),
        );
        expect(failure.kind, InvoicesFailureKind.reusedLiquidAddress);
        verify(
          () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
            walletId: 'liquid-default',
          ),
        ).called(2);
      },
    );
  });

  group('private memo (§3.14)', () {
    test('stored as a local memo label AFTER a successful create', () async {
      final r = _unwrap(
        await usecase.execute(command(acceptLiquid: true, privateMemo: 'rent')),
      );

      expect(r.invoiceId.value, 'inv-1');
      // The memo label (distinct from the reservation) is stored exactly once,
      // keyed on the created invoice's Liquid address.
      final memoStores = verify(
        () => labels.store(captureAny()),
      ).captured.cast<NewLabel>().where((l) => l.label == 'rent').toList();
      expect(memoStores, hasLength(1));
      expect(memoStores.single.reference, 'lq1qfresh');
    });

    test(
      'a memo label store failure never fails the create (§3.14 / AD-3)',
      () async {
        // ONLY the best-effort memo store throws; the reservation still succeeds.
        when(
          () => labels.store(any(that: isMemoLabel())),
        ).thenThrow(const FormatException('labels down'));

        final r = _unwrap(
          await usecase.execute(
            command(acceptLiquid: true, privateMemo: 'rent'),
          ),
        );

        expect(r.invoiceId.value, 'inv-1');
      },
    );

    test(
      'no memo → only the reservation label is stored (no memo label)',
      () async {
        _unwrap(await usecase.execute(command(acceptLiquid: true)));
        final stored = verify(
          () => labels.store(captureAny()),
        ).captured.cast<NewLabel>();
        // Exactly the reservation, never a memo label.
        expect(stored, hasLength(1));
        expect(stored.single.label, LabelSystem.invoice.label);
      },
    );
  });

  group('Liquid address reservation (back-to-back collision fix)', () {
    test(
      'reserves the issued Liquid address with a system label at generation',
      () async {
        _unwrap(await usecase.execute(command(acceptLiquid: true)));

        final reservation = verify(() => labels.store(captureAny())).captured
            .cast<NewLabel>()
            .firstWhere((l) => l.label == LabelSystem.invoice.label);
        expect(reservation.reference, 'lq1qfresh');
        expect(reservation.type, LabelType.address);
        expect(reservation.origin, 'invoice');
      },
    );

    test(
      'an LN-only invoice (acceptLiquid false) still reserves its address',
      () async {
        _unwrap(
          await usecase.execute(command(acceptLn: true, acceptLiquid: false)),
        );

        final reservations = verify(() => labels.store(captureAny())).captured
            .cast<NewLabel>()
            .where((l) => l.label == LabelSystem.invoice.label)
            .toList();
        expect(reservations, hasLength(1));
        expect(reservations.single.reference, 'lq1qfresh');
      },
    );

    test(
      'a reservation store FAILURE fails the create loudly (never silent)',
      () async {
        when(() => labels.store(any(that: isReservationLabel()))).thenAnswer(
          (_) async =>
              const Err<Label, LabelFailure>(LabelUnexpectedFailure('down')),
        );

        final failure = _unwrapFailure(
          await usecase.execute(command(acceptLiquid: true)),
        );
        expect(failure.kind, InvoicesFailureKind.unexpected);
        // The reservation is correctness-critical: the wire create is never made.
        verifyNever(
          () => payService.createInvoice(
            signer: any(named: 'signer'),
            command: any(named: 'command'),
            bitcoinAddress: any(named: 'bitcoinAddress'),
            liquidAddress: any(named: 'liquidAddress'),
            liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
          ),
        );
      },
    );

    test('releases the reservation when the create ultimately fails', () async {
      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          command: any(named: 'command'),
          bitcoinAddress: any(named: 'bitcoinAddress'),
          liquidAddress: any(named: 'liquidAddress'),
          liquidBlindingKeyHex: any(named: 'liquidBlindingKeyHex'),
        ),
      ).thenAnswer(
        (_) async => const Err(InvoicesFailure.server(retryable: true)),
      );

      final failure = _unwrapFailure(
        await usecase.execute(command(acceptLiquid: true)),
      );
      expect(failure.kind, InvoicesFailureKind.server);
      // The index burned during this failed create is handed back.
      verify(() => labels.trash(any())).called(1);
    });
  });
}
