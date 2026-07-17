import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:bb_mobile/features/invoices/application/commands/invoice_commands.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_identity_port.dart';
import 'package:bb_mobile/features/invoices/application/ports/invoices_pay_service_port.dart';
import 'package:bb_mobile/features/invoices/application/results/invoice_results.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/value_objects/invoice_id.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:meta/meta.dart';

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

  @useResult
  Future<Result<CreateInvoiceResult, InvoicesFailure>> execute(
    CreateInvoiceCommand command,
  ) async {
    // Local pre-validation (server echo, §3.6/§3.8): fail before any wire call.
    if (!command.hasAnyRail) {
      return const Err(InvoicesFailure.invalidInput(code: 'NoRailSelected'));
    }
    if (!command.hasExactlyOneAmount) {
      return const Err(InvoicesFailure.invalidInput(code: 'AmountNotOneOf'));
    }

    // Identity signer from the default-wallet xprv, resolved at point of use.
    final signerResult = await _identity.getSigningHandle();
    final BullnymAuthSigner signer;
    switch (signerResult) {
      case Ok(:final value):
        signer = value;
      case Err(:final failure):
        return Err(failure);
    }

    final Environment environment;
    try {
      environment = (await _getSettings.execute()).environment;
    } on Exception catch (error, stack) {
      log.warning('Invoice settings lookup failed', error: error, trace: stack);
      return const Err(InvoicesFailure.unexpected());
    }

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
        switch (await _defaultBitcoinWalletId(environment)) {
          case Ok(:final value):
            bitcoinWalletId = value;
          case Err(:final failure):
            return Err(failure);
        }
        bitcoinAddress = await _freshBitcoinAddress(bitcoinWalletId);
      }

      String? liquidWalletId;
      String? liquidAddress;
      String? liquidBlindingKeyHex;
      if (command.needsLiquidAddress) {
        switch (await _defaultLiquidWalletId(environment)) {
          case Ok(:final value):
            liquidWalletId = value;
          case Err(:final failure):
            return Err(failure);
        }
        final generatedResult = await _freshLiquidAddress(
          liquidWalletId,
          reservedLabelIds,
        );
        switch (generatedResult) {
          case Ok(:final value):
            liquidAddress = value.$1;
            // The blinding secret is sent ONLY when the Liquid rail itself is
            // accepted; an LN-only invoice supplies the address without the
            // secret (§3.5/§3.19).
            liquidBlindingKeyHex = command.acceptLiquid ? value.$2 : null;
          case Err(:final failure):
            await _releaseReservations(reservedLabelIds);
            return Err(failure);
        }
      }

      final firstCreate = await _payService.createInvoice(
        signer: signer,
        command: command,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
        liquidBlindingKeyHex: liquidBlindingKeyHex,
      );
      final CreateInvoiceResult result;
      switch (firstCreate) {
        case Ok(:final value):
          result = value;
        case Err(:final failure):
          // Single regenerate-and-retry on a used-address rejection (§7.2). A
          // second reuse on the retry propagates as the typed reused* error.
          if (failure.kind == InvoicesFailureKind.reusedBitcoinAddress &&
              bitcoinWalletId != null) {
            bitcoinAddress = await _freshBitcoinAddress(bitcoinWalletId);
          } else if (failure.kind == InvoicesFailureKind.reusedLiquidAddress &&
              liquidWalletId != null) {
            final regenerated = await _freshLiquidAddress(
              liquidWalletId,
              reservedLabelIds,
            );
            switch (regenerated) {
              case Ok(:final value):
                liquidAddress = value.$1;
                liquidBlindingKeyHex = command.acceptLiquid ? value.$2 : null;
              case Err(:final failure):
                await _releaseReservations(reservedLabelIds);
                return Err(failure);
            }
          } else {
            await _releaseReservations(reservedLabelIds);
            return Err(failure);
          }
          switch (await _payService.createInvoice(
            signer: signer,
            command: command,
            bitcoinAddress: bitcoinAddress,
            liquidAddress: liquidAddress,
            liquidBlindingKeyHex: liquidBlindingKeyHex,
          )) {
            case Ok(:final value):
              result = value;
            case Err(:final failure):
              await _releaseReservations(reservedLabelIds);
              return Err(failure);
          }
      }

      await _storePrivateMemo(
        command: command,
        invoiceId: result.invoiceId,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
      );

      return Ok(result);
    } on Exception catch (error, stack) {
      // The create failed for good (all attempts): release the reservations so
      // the next attempt reuses the same unfunded indices instead of walking
      // the gap forward on every failure. Best-effort — never mask the error.
      await _releaseReservations(reservedLabelIds);
      log.warning(
        'Invoice create preparation failed',
        error: error,
        trace: stack,
      );
      return const Err(InvoicesFailure.unexpected());
    }
  }

  Future<Result<String, InvoicesFailure>> _defaultBitcoinWalletId(
    Environment environment,
  ) async {
    final wallets = await _walletRepository.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      return const Err(InvoicesFailure.noDefaultBitcoinWallet());
    }
    return Ok(wallets.first.id);
  }

  Future<Result<String, InvoicesFailure>> _defaultLiquidWalletId(
    Environment environment,
  ) async {
    final wallets = await _walletRepository.getWallets(
      environment: environment,
      onlyDefaults: true,
      onlyLiquid: true,
    );
    if (wallets.isEmpty) {
      return const Err(InvoicesFailure.noDefaultLiquidWallet());
    }
    return Ok(wallets.first.id);
  }

  Future<String> _freshBitcoinAddress(String walletId) async {
    final address = await _walletAddressRepository.generateNewReceiveAddress(
      walletId: walletId,
    );
    return address.address;
  }

  // (address, blindingSecretHex)
  //
  // RESERVE the issued Liquid address the same way swaps/payjoin/exchange do —
  // by storing a system label on it. The address repository's generate loop
  // skips any index carrying a system label, so this makes a back-to-back
  // invoice (created before the first is funded) derive a DIFFERENT address +
  // blinding secret instead of colliding on the same unfunded index. Unlike the
  // best-effort private memo, this reservation is correctness-critical, so a
  // persistence failure MUST fail the create (it is caught by [execute] and the
  // label released). The stored label id is appended to [reservedLabelIds].
  Future<Result<(String, String), InvoicesFailure>> _freshLiquidAddress(
    String walletId,
    List<int> reservedLabelIds,
  ) async {
    final generated = await _walletAddressRepository
        .generateNewLiquidReceiveAddressWithBlindingSecret(walletId: walletId);
    final reservation = await _labels.store(
      NewLabel.addr(
        address: generated.address,
        label: LabelSystem.invoice.label,
        origin: 'invoice',
      ),
    );
    switch (reservation) {
      case Ok(:final value):
        reservedLabelIds.add(value.id);
        return Ok((generated.address, generated.blindingSecretHex));
      case Err():
        return const Err(InvoicesFailure.unexpected());
    }
  }

  // Best-effort release of the address reservations written during a create
  // that ultimately failed. A failed trash just leaves the index reserved,
  // which is safe (a reserved index is never reused), so it never throws.
  Future<void> _releaseReservations(List<int> labelIds) async {
    for (final id in labelIds) {
      try {
        await _labels.trash(id);
      } on Exception {
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
      } on Exception {
        // Best-effort only (§3.14 / AD-3 post-commitment).
      }
    }
  }
}
