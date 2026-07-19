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
import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/private_invoice_cipher.dart';
import 'package:bb_mobile/features/invoices/domain/repositories/private_invoice_link_repository.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/private_invoice_link.dart';
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

void main() {
  final signer = BullnymAuthSigner(
    npubHex: 'aa' * 32,
    signHashHex: (_) => 'bb' * 64,
  );
  final invoiceId = InvoiceId('inv-1');
  final result = CreateInvoiceResult(
    invoiceId: invoiceId,
    privateLink: PrivateInvoiceLink.fromServer(
      invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
      expectedInvoiceId: invoiceId,
      viewingKey: 'A' * 43,
      expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
    ),
  );

  setUpAll(() {
    registerFallbackValue(
      BullnymAuthSigner(npubHex: '00' * 32, signHashHex: (_) => ''),
    );
    registerFallbackValue(_prepared());
    registerFallbackValue(NewLabel.addr(address: 'x', label: 'y'));
  });

  late _MockIdentity identity;
  late _MockPayService payService;
  late _MockWalletRepo walletRepo;
  late _MockAddrRepo addrRepo;
  late _MockLabels labels;
  late _MockGetSettings getSettings;
  late _FakeCipher cipher;
  late _FakeLinks links;
  late CreateInvoiceUsecase usecase;
  late List<String> sequence;
  late int liquidAddressIndex;
  late int nextLabelId;

  setUp(() {
    identity = _MockIdentity();
    payService = _MockPayService();
    walletRepo = _MockWalletRepo();
    addrRepo = _MockAddrRepo();
    labels = _MockLabels();
    getSettings = _MockGetSettings();
    cipher = _FakeCipher();
    links = _FakeLinks();
    sequence = [];
    liquidAddressIndex = 0;
    nextLabelId = 1;
    usecase = CreateInvoiceUsecase(
      identity: identity,
      payService: payService,
      cipher: cipher,
      links: links,
      walletRepository: walletRepo,
      walletAddressRepository: addrRepo,
      labels: labels,
      getSettings: getSettings,
    );

    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(() => getSettings.execute()).thenAnswer((_) async => settings);
    when(() => identity.getSigningHandle()).thenAnswer((_) async => Ok(signer));

    final btcWallet = _MockWallet();
    final liquidWallet = _MockWallet();
    when(() => btcWallet.id).thenReturn('btc-default');
    when(() => liquidWallet.id).thenReturn('liquid-default');
    when(
      () => walletRepo.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    ).thenAnswer((invocation) async {
      final liquid = invocation.namedArguments[#onlyLiquid] as bool?;
      return liquid == true ? [liquidWallet] : [btcWallet];
    });
    when(
      () =>
          addrRepo.generateNewReceiveAddress(walletId: any(named: 'walletId')),
    ).thenAnswer(
      (_) async => WalletAddress(
        walletId: 'btc-default',
        index: 0,
        address: 'bc1qfresh',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    when(
      () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
        walletId: any(named: 'walletId'),
      ),
    ).thenAnswer((_) async {
      liquidAddressIndex++;
      return LiquidReceiveAddressWithBlindingSecret(
        address: 'lq1qfresh$liquidAddressIndex',
        blindingSecretHex: '11' * 32,
      );
    });
    when(() => labels.store(any())).thenAnswer((invocation) async {
      final label = invocation.positionalArguments.first as NewLabel;
      return Ok<Label, LabelFailure>(
        Label.addr(
          id: nextLabelId++,
          address: label.reference,
          label: label.label,
          origin: label.origin,
        ),
      );
    });
    when(
      () => labels.trash(any()),
    ).thenAnswer((_) async => const Ok<Null, LabelFailure>(null));
    when(
      () => payService.createInvoice(
        signer: any(named: 'signer'),
        operation: any(named: 'operation'),
      ),
    ).thenAnswer((_) async {
      sequence.add('send');
      return Ok(result);
    });
    links.onSavePending = (_) => sequence.add('save-pending');
    links.onRetainLink = (_) => sequence.add('retain-link');
    links.onDeletePending = (_) => sequence.add('delete-pending');
  });

  test(
    'persists the complete operation before sending and commits link first',
    () async {
      final value = _unwrap(await usecase.execute(_command()));

      expect(value.privateLink, result.privateLink);
      expect(sequence, [
        'save-pending',
        'send',
        'retain-link',
        'delete-pending',
      ]);
      expect(links.pending, isNull);
      expect(links.retained[invoiceId.value]?.value, result.privateLink.value);
      expect(cipher.encryptCalls, 1);
      final sent =
          verify(
                () => payService.createInvoice(
                  signer: signer,
                  operation: captureAny(named: 'operation'),
                ),
              ).captured.single
              as PreparedPrivateInvoiceCreate;
      expect(sent.liquidAddress, 'lq1qfresh1');
      expect(sent.liquidBlindingKeyHex, '11' * 32);
      expect(sent.encrypted.presentationEnvelope, 'E' * 5500);
    },
  );

  test(
    'response loss retains the exact operation and address reservation',
    () async {
      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async => const Err(InvoicesFailure.network()));

      final failure = _unwrapFailure(await usecase.execute(_command()));

      expect(failure.kind, InvoicesFailureKind.outcomeUnknown);
      expect(links.pending, isNotNull);
      expect(links.pending!.encrypted.presentationEnvelope, 'E' * 5500);
      expect(links.pending!.reservationLabelIds, [1]);
      verifyNever(() => labels.trash(any()));

      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((_) async => Ok(result));
      final resumed = _unwrap(await usecase.resumePending());
      expect(resumed, result);
      expect(cipher.encryptCalls, 1);
      verify(
        () => addrRepo.generateNewLiquidReceiveAddressWithBlindingSecret(
          walletId: any(named: 'walletId'),
        ),
      ).called(1);
    },
  );

  test(
    'definite pre-insert rejection deletes pending and releases reservation',
    () async {
      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer(
        (_) async =>
            const Err(InvoicesFailure.invalidInput(code: 'InvalidAmount')),
      );

      final failure = _unwrapFailure(await usecase.execute(_command()));

      expect(failure.kind, InvoicesFailureKind.invalidInput);
      expect(links.pending, isNull);
      verify(() => labels.trash(1)).called(1);
    },
  );

  test(
    'used Liquid address replaces only payout data and request id',
    () async {
      var calls = 0;
      final sent = <PreparedPrivateInvoiceCreate>[];
      when(
        () => payService.createInvoice(
          signer: any(named: 'signer'),
          operation: any(named: 'operation'),
        ),
      ).thenAnswer((invocation) async {
        sent.add(
          invocation.namedArguments[#operation] as PreparedPrivateInvoiceCreate,
        );
        calls++;
        return calls == 1
            ? const Err(InvoicesFailure.reusedLiquidAddress())
            : Ok(result);
      });

      _unwrap(await usecase.execute(_command()));

      expect(sent, hasLength(2));
      expect(
        sent[1].encrypted.clientRequestId,
        isNot(sent[0].encrypted.clientRequestId),
      );
      expect(
        sent[1].encrypted.presentationEnvelope,
        sent[0].encrypted.presentationEnvelope,
      );
      expect(sent[1].encrypted.viewingKey, sent[0].encrypted.viewingKey);
      expect(sent[1].liquidAddress, 'lq1qfresh2');
      verify(() => labels.trash(1)).called(1);
    },
  );

  test('retained-link failure leaves pending operation recoverable', () async {
    links.retainFailure = true;

    final failure = _unwrapFailure(await usecase.execute(_command()));

    expect(failure.kind, InvoicesFailureKind.privateStorage);
    expect(links.pending, isNotNull);
    expect(links.deleteCalls, 0);
    verifyNever(() => labels.trash(any()));
  });

  test('all wallet lookups are constrained to defaults', () async {
    _unwrap(
      await usecase.execute(
        _command(acceptBtc: true, acceptLn: true, acceptLiquid: true),
      ),
    );

    final captured = verify(
      () => walletRepo.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: captureAny(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    ).captured;
    expect(captured, everyElement(isTrue));
  });

  test(
    'invalid command fails before identity, encryption, and storage',
    () async {
      final failure = _unwrapFailure(
        await usecase.execute(_command(acceptLn: false, acceptLiquid: false)),
      );

      expect(failure.kind, InvoicesFailureKind.invalidInput);
      verifyNever(() => identity.getSigningHandle());
      expect(cipher.encryptCalls, 0);
      expect(links.saveCalls, 0);
    },
  );
}

CreateInvoiceCommand _command({
  bool acceptBtc = false,
  bool acceptLn = true,
  bool acceptLiquid = true,
}) => CreateInvoiceCommand(
  amountSat: 1000,
  presentation: PrivateInvoicePresentation(
    invoice: PrivateInvoiceDetails(description: 'Consulting'),
  ),
  acceptBtc: acceptBtc,
  acceptLn: acceptLn,
  acceptLiquid: acceptLiquid,
);

PreparedPrivateInvoiceCreate _prepared() => PreparedPrivateInvoiceCreate(
  encrypted: EncryptedPrivateInvoice(
    clientRequestId: '00000000-0000-4000-8000-000000000001',
    presentationEnvelope: 'E' * 5500,
    viewingKey: 'A' * 43,
  ),
  amountSat: 1000,
  acceptBtc: false,
  acceptLn: true,
  acceptLiquid: true,
  liquidAddress: 'lq1qfresh',
  liquidBlindingKeyHex: '11' * 32,
);

T _unwrap<T>(Result<T, InvoicesFailure> result) => result.fold(
  (value) => value,
  (failure) => throw TestFailure('expected Ok, got $failure'),
);

InvoicesFailure _unwrapFailure<T>(Result<T, InvoicesFailure> result) =>
    result.fold(
      (_) => throw TestFailure('expected Err, got Ok'),
      (failure) => failure,
    );

class _FakeCipher implements PrivateInvoiceCipher {
  int encryptCalls = 0;
  int _requestSequence = 0;

  @override
  Future<EncryptedPrivateInvoice> encrypt(
    PrivateInvoicePresentation presentation,
  ) async {
    encryptCalls++;
    return EncryptedPrivateInvoice(
      clientRequestId: newClientRequestId(),
      presentationEnvelope: 'E' * 5500,
      viewingKey: 'A' * 43,
    );
  }

  @override
  String newClientRequestId() {
    _requestSequence++;
    return '00000000-0000-4000-8000-'
        '${_requestSequence.toString().padLeft(12, '0')}';
  }
}

class _FakeLinks implements PrivateInvoiceLinkRepository {
  PreparedPrivateInvoiceCreate? pending;
  final Map<String, PrivateInvoiceLink> retained = {};
  int saveCalls = 0;
  int deleteCalls = 0;
  bool retainFailure = false;
  void Function(PreparedPrivateInvoiceCreate)? onSavePending;
  void Function(String)? onDeletePending;
  void Function(PrivateInvoiceLink)? onRetainLink;

  @override
  Future<void> deletePending(String clientRequestId) async {
    deleteCalls++;
    onDeletePending?.call(clientRequestId);
    if (pending?.encrypted.clientRequestId == clientRequestId) pending = null;
  }

  @override
  Future<PreparedPrivateInvoiceCreate?> getPending() async => pending;

  @override
  Future<PrivateInvoiceLink?> getRetainedLink(InvoiceId invoiceId) async =>
      retained[invoiceId.value];

  @override
  Future<void> retainLink(PrivateInvoiceLink link) async {
    onRetainLink?.call(link);
    if (retainFailure) throw const FormatException('storage unavailable');
    retained[link.invoiceId.value] = link;
  }

  @override
  Future<void> savePending(PreparedPrivateInvoiceCreate operation) async {
    saveCalls++;
    onSavePending?.call(operation);
    pending = operation;
  }
}
