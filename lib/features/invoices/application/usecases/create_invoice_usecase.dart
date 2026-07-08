import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_error.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';

/// Orchestrates a wallet-origin invoice create (§3.5). The PAYOUT addresses come
/// ONLY from the user's DEFAULT wallets (never a reserved Get Paid descriptor
/// 101/102/103, so no LUD-22 cursor is ever touched — DG-I2). A server
/// used-address rejection triggers a SINGLE regenerate-and-retry for that rail;
/// the private memo is stored as local labels best-effort AFTER success.
class CreateInvoiceUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;
  final WalletRepository _walletRepository;
  final WalletAddressRepository _walletAddressRepository;
  final LabelsFacade _labels;
  final GetSettingsUsecase _getSettings;

  const CreateInvoiceUsecase({
    required this._identity,
    required this._payService,
    required this._walletRepository,
    required this._walletAddressRepository,
    required this._labels,
    required this._getSettings,
  });

  Future<CreateInvoiceResult> execute(CreateInvoiceCommand command) async {
    // Local pre-validation (server echo, §3.6/§3.8): fail before any wire call.
    if (!command.hasAnyRail) {
      throw const InvoicesException.invalidInput(code: 'NoRailSelected');
    }
    if (!command.hasExactlyOneAmount) {
      throw const InvoicesException.invalidInput(code: 'AmountNotOneOf');
    }

    // Identity signer from the default-wallet xprv, resolved at point of use.
    final signer = await _identity.getSigningHandle();

    final environment = (await _getSettings.execute()).environment;

    // System labels written to RESERVE the Liquid payout address(es) issued
    // during THIS create (see [_freshLiquidAddress]). On total failure they are
    // released so a repeated failed create does not burn consecutive unfunded
    // Liquid indices.
    final reservedLabelIds = <int>[];
    try {
      // Resolve fresh payout addresses from the DEFAULT wallets only.
      String? bitcoinWalletId;
      String? bitcoinAddress;
      if (command.acceptBtc) {
        bitcoinWalletId = await _defaultBitcoinWalletId(environment);
        bitcoinAddress = await _freshBitcoinAddress(bitcoinWalletId);
      }

      String? liquidWalletId;
      String? liquidAddress;
      String? liquidBlindingKeyHex;
      if (command.needsLiquidAddress) {
        liquidWalletId = await _defaultLiquidWalletId(environment);
        final generated = await _freshLiquidAddress(
          liquidWalletId,
          reservedLabelIds,
        );
        liquidAddress = generated.$1;
        // The blinding key is sent ONLY when the Liquid rail itself is accepted;
        // an LN-only invoice supplies the address without the key (§3.5/§3.19).
        liquidBlindingKeyHex = command.acceptLiquid ? generated.$2 : null;
      }

      CreateInvoiceResult result;
      try {
        result = await _payService.createInvoice(
          signer: signer,
          command: command,
          bitcoinAddress: bitcoinAddress,
          liquidAddress: liquidAddress,
          liquidBlindingKeyHex: liquidBlindingKeyHex,
        );
      } on InvoicesException catch (e) {
        // Single regenerate-and-retry on a used-address rejection (§7.2). A
        // second reuse on the retry propagates as the typed reused* error.
        if (e.kind == InvoicesErrorKind.reusedBitcoinAddress &&
            bitcoinWalletId != null) {
          bitcoinAddress = await _freshBitcoinAddress(bitcoinWalletId);
        } else if (e.kind == InvoicesErrorKind.reusedLiquidAddress &&
            liquidWalletId != null) {
          final regenerated = await _freshLiquidAddress(
            liquidWalletId,
            reservedLabelIds,
          );
          liquidAddress = regenerated.$1;
          liquidBlindingKeyHex = command.acceptLiquid ? regenerated.$2 : null;
        } else {
          rethrow;
        }
        result = await _payService.createInvoice(
          signer: signer,
          command: command,
          bitcoinAddress: bitcoinAddress,
          liquidAddress: liquidAddress,
          liquidBlindingKeyHex: liquidBlindingKeyHex,
        );
      }

      await _storePrivateMemo(
        command: command,
        invoiceId: result.invoiceId,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
      );

      return result;
    } catch (_) {
      // The create failed for good (all attempts): release the reservations so
      // the next attempt reuses the same unfunded indices instead of walking
      // the gap forward on every failure. Best-effort — never mask the error.
      await _releaseReservations(reservedLabelIds);
      rethrow;
    }
  }

  Future<String> _defaultBitcoinWalletId(Environment environment) async {
    final wallets = await _walletRepository.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      throw const InvoicesException.noDefaultBitcoinWallet();
    }
    return wallets.first.id;
  }

  Future<String> _defaultLiquidWalletId(Environment environment) async {
    final wallets = await _walletRepository.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyLiquid: true,
    );
    if (wallets.isEmpty) {
      throw const InvoicesException.noDefaultLiquidWallet();
    }
    return wallets.first.id;
  }

  Future<String> _freshBitcoinAddress(String walletId) async {
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: walletId,
    );
    return address.address;
  }

  // (address, blindingKeyHex)
  //
  // RESERVE the issued Liquid address the same way swaps/payjoin/exchange do —
  // by storing a system label on it. The address repository's generate loop
  // skips any index carrying a system label, so this makes a back-to-back
  // invoice (created before the first is funded) derive a DIFFERENT address +
  // blinding key instead of colliding on the same unfunded index. Unlike the
  // best-effort private memo, this reservation is correctness-critical, so a
  // persistence failure MUST fail the create (it is caught by [execute] and the
  // label released). The stored label id is appended to [reservedLabelIds].
  Future<(String, String)> _freshLiquidAddress(
    String walletId,
    List<int> reservedLabelIds,
  ) async {
    final generated = await _walletAddressRepository
        .generateNewLiquidReceiveAddressWithBlindingKey(walletId: walletId);
    final reservation = await _labels.store(
      NewLabel.addr(
        address: generated.address,
        label: LabelSystem.invoice.label,
        origin: 'invoice',
      ),
    );
    final reserved = reservation.fold(
      (label) => label,
      (_) => throw const InvoicesException.unexpected(),
    );
    reservedLabelIds.add(reserved.id);
    return (generated.address, generated.blindingKeyHex);
  }

  // Best-effort release of the address reservations written during a create
  // that ultimately failed. A failed trash just leaves the index reserved,
  // which is safe (a reserved index is never reused), so it never throws.
  Future<void> _releaseReservations(List<int> labelIds) async {
    for (final id in labelIds) {
      try {
        await _labels.trash(id);
      } catch (_) {
        // Best-effort cleanup only.
      }
    }
  }

  // Best-effort: the private memo is stored as a local address label after the
  // invoice exists. It NEVER reaches the server and NEVER fails the create.
  Future<void> _storePrivateMemo({
    required CreateInvoiceCommand command,
    required InvoiceId invoiceId,
    required String? bitcoinAddress,
    required String? liquidAddress,
  }) async {
    final memo = command.privateMemo?.trim();
    if (memo == null || memo.isEmpty) return;
    final origin = 'invoice:${invoiceId.value}';
    for (final address in [bitcoinAddress, liquidAddress]) {
      if (address == null) continue;
      try {
        await _labels.store(
          NewLabel.addr(address: address, label: memo, origin: origin),
        );
      } catch (_) {
        // Best-effort only (§3.14 / AD-3 post-commitment).
      }
    }
  }
}
