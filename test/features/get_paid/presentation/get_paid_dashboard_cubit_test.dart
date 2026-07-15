import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockWallet extends Mock implements Wallet {}

// The public facades are callback-injected, so the tests wire real facade
// instances to plain closures — no mocking framework needed.

LightningAddressFacade _laFacade(
  Future<LightningAddressStatus> Function() lookup,
) {
  return LightningAddressFacade(
    prepareWallet: () async => throw UnimplementedError(),
    lookupRegistration: ({required String npubHex}) async =>
        throw UnimplementedError(),
    registerWalletOwned: ({required String nym}) async =>
        throw UnimplementedError(),
    lookupWalletOwnedRegistration: lookup,
    ensureRegistrationLive: () async => throw UnimplementedError(),
  );
}

PaymentPageFacade _pageFacade(
  Future<PaymentPage?> Function({required String nym}) find,
) {
  return PaymentPageFacade(
    find: find,
    save: (command) async => throw UnimplementedError(),
    archive: () async => throw UnimplementedError(),
    supportedCurrencies: () async => throw UnimplementedError(),
    ensurePageLive: () async => throw UnimplementedError(),
  );
}

PosFacade _posFacade(
  Future<PosTerminal?> Function({required String nym}) find,
) {
  return PosFacade(
    find: find,
    provision: (command) async => throw UnimplementedError(),
    archive: () async => throw UnimplementedError(),
    supportedCurrencies: () async => throw UnimplementedError(),
    ensurePosLive: () async => throw UnimplementedError(),
  );
}

BtcpayFacade _btcpayFacade(
  Future<Result<BtcpayConnection?, BtcpayFailure>> Function() connection,
) {
  return BtcpayFacade(connection: connection);
}

LightningAddressStatus _status({
  bool active = false,
  String nym = 'satoshi',
  String? address,
}) {
  return LightningAddressStatus(
    nym: nym,
    active: active,
    lightningAddress: address,
  );
}

PaymentPage _page({bool enabled = true, bool archived = false}) {
  return PaymentPage(
    nym: 'satoshi',
    header: 'Donate',
    description: 'desc',
    displayCurrency: 'USD',
    enabled: enabled,
    isArchived: archived,
    publicUrl: 'https://pay.example/satoshi',
  );
}

PosTerminal _pos({bool enabled = true, bool archived = false}) {
  return PosTerminal(
    nym: 'satoshi',
    label: 'Till',
    displayCurrency: 'USD',
    enabled: enabled,
    isArchived: archived,
    terminalUrl: 'https://pos.example/satoshi/pos',
  );
}

BtcpayConnection _connection() {
  return BtcpayConnection.tryCreate(
    environment: Environment.mainnet,
    serverUrl: 'https://btcpay.example',
    storeId: 'store',
    capabilities: const [SamRockSetupCapability.bitcoinChain],
    walletNetworks: const [BtcpayWalletNetwork.bitcoin],
    status: BtcpayConnectionStatus.paired,
    pairedAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  )!;
}

GetWalletsUsecase _getWallets({bool hasDefaultWallet = false}) {
  final usecase = _MockGetWallets();
  when(
    () => usecase.execute(
      onlyDefaults: any(named: 'onlyDefaults'),
      onlyBitcoin: any(named: 'onlyBitcoin'),
      onlyLiquid: any(named: 'onlyLiquid'),
      sync: any(named: 'sync'),
    ),
  ).thenAnswer((_) async => hasDefaultWallet ? [_MockWallet()] : <Wallet>[]);
  return usecase;
}

GetPaidDashboardCubit _cubit({
  Future<LightningAddressStatus> Function()? lookup,
  Future<PaymentPage?> Function({required String nym})? pageFind,
  Future<PosTerminal?> Function({required String nym})? posFind,
  Future<Result<BtcpayConnection?, BtcpayFailure>> Function()? connection,
  bool hasDefaultWallet = false,
}) {
  return GetPaidDashboardCubit(
    lightningAddress: _laFacade(lookup ?? () async => _status()),
    paymentPage: _pageFacade(pageFind ?? ({required String nym}) async => null),
    pos: _posFacade(posFind ?? ({required String nym}) async => null),
    btcpay: _btcpayFacade(
      connection ??
          () async => const Ok<BtcpayConnection?, BtcpayFailure>(null),
    ),
    getWallets: _getWallets(hasDefaultWallet: hasDefaultWallet),
  );
}

void main() {
  test('all products unset after refresh', () async {
    final cubit = _cubit();

    await cubit.refresh();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.hasLightningAddress, isFalse);
    expect(cubit.state.paymentPage, isNull);
    expect(cubit.state.posTerminal, isNull);
    expect(cubit.state.btcpayConnection, isNull);
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('active Lightning Address populates address + nym', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
    );

    await cubit.refresh();

    expect(cubit.state.hasLightningAddress, isTrue);
    expect(cubit.state.lightningAddress, 'satoshi@bull.money');
    expect(cubit.state.lightningActive, isTrue);
    expect(cubit.state.nym, 'satoshi');
    await cubit.close();
  });

  test('inactive registration keeps the address but is not active', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: false, address: 'satoshi@bull.money'),
    );

    await cubit.refresh();

    expect(cubit.state.lightningAddress, 'satoshi@bull.money');
    expect(cubit.state.lightningActive, isFalse);
    await cubit.close();
  });

  test('invoices tile is ready when a default wallet exists', () async {
    final cubit = _cubit(hasDefaultWallet: true);

    await cubit.refresh();

    expect(cubit.state.invoicesWalletReady, isTrue);
    await cubit.close();
  });

  test('invoices tile is not ready without a default wallet', () async {
    final cubit = _cubit();

    await cubit.refresh();

    expect(cubit.state.invoicesWalletReady, isFalse);
    await cubit.close();
  });

  test('published Donation Page is active', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
      pageFind: ({required String nym}) async => _page(enabled: true),
    );

    await cubit.refresh();

    expect(cubit.state.hasPaymentPage, isTrue);
    expect(cubit.state.paymentPage!.enabled, isTrue);
    await cubit.close();
  });

  test('unpublished Donation Page is present but disabled', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
      pageFind: ({required String nym}) async => _page(enabled: false),
    );

    await cubit.refresh();

    expect(cubit.state.paymentPage, isNotNull);
    expect(cubit.state.paymentPage!.enabled, isFalse);
    await cubit.close();
  });

  test('archived Donation Page is treated as unset', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
      pageFind: ({required String nym}) async => _page(archived: true),
    );

    await cubit.refresh();

    expect(cubit.state.paymentPage, isNull);
    await cubit.close();
  });

  test('active Point of Sale populates the terminal', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
      posFind: ({required String nym}) async => _pos(enabled: true),
    );

    await cubit.refresh();

    expect(cubit.state.hasPos, isTrue);
    expect(cubit.state.posTerminal!.terminalUrl, isNotEmpty);
    await cubit.close();
  });

  test('paired BTCPay connection is exposed', () async {
    final cubit = _cubit(
      connection: () async =>
          Ok<BtcpayConnection?, BtcpayFailure>(_connection()),
    );

    await cubit.refresh();

    expect(cubit.state.hasBtcpayConnection, isTrue);
    expect(cubit.state.btcpayConnection!.serverUrl, 'https://btcpay.example');
    await cubit.close();
  });

  test('a typed BTCPay failure preserves the partial dashboard', () async {
    final cubit = _cubit(
      lookup: () async => _status(active: true, address: 'satoshi@bull.money'),
      connection: () async =>
          const Err(BtcpayStorageFailure('fixture failure')),
    );

    await cubit.refresh();

    expect(cubit.state.hasLightningAddress, isTrue);
    expect(cubit.state.btcpayConnection, isNull);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });

  test('nym-keyed products are not probed without a nym', () async {
    var pageProbed = false;
    var posProbed = false;
    final cubit = _cubit(
      lookup: () async => _status(nym: '', active: false),
      pageFind: ({required String nym}) async {
        pageProbed = true;
        return null;
      },
      posFind: ({required String nym}) async {
        posProbed = true;
        return null;
      },
    );

    await cubit.refresh();

    expect(pageProbed, isFalse);
    expect(posProbed, isFalse);
    expect(cubit.state.nym, isNull);
    await cubit.close();
  });

  test('a facade failure surfaces an error and stops loading', () async {
    final cubit = _cubit(lookup: () async => throw Exception('boom'));

    await cubit.refresh();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });

  test('refresh clears a prior error on success', () async {
    var shouldThrow = true;
    final cubit = _cubit(
      lookup: () async {
        if (shouldThrow) throw Exception('boom');
        return _status(active: true, address: 'satoshi@bull.money');
      },
    );

    await cubit.refresh();
    expect(cubit.state.error, isNotNull);

    shouldThrow = false;
    await cubit.refresh();

    expect(cubit.state.error, isNull);
    expect(cubit.state.hasLightningAddress, isTrue);
    await cubit.close();
  });
}
