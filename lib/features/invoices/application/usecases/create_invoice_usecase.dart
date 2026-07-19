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
import 'package:bb_mobile/features/invoices/domain/entities/encrypted_private_invoice.dart';
import 'package:bb_mobile/features/invoices/domain/entities/prepared_private_invoice_create.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:bb_mobile/features/invoices/domain/private_invoice_cipher.dart';
import 'package:bb_mobile/features/invoices/domain/repositories/private_invoice_link_repository.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:meta/meta.dart';

/// Creates one wallet-origin invoice through a durable idempotent operation.
/// Once the request may have reached Bullnym, the exact operation and payout
/// reservations remain until a retry obtains and stores the original result.
class CreateInvoiceUsecase {
  final InvoicesIdentityPort _identity;
  final InvoicesPayServicePort _payService;
  final PrivateInvoiceCipher _cipher;
  final PrivateInvoiceLinkRepository _links;
  final WalletRepository _walletRepository;
  final WalletAddressRepository _walletAddressRepository;
  final LabelsFacade _labels;
  final GetSettingsUsecase _getSettings;

  const CreateInvoiceUsecase({
    required InvoicesIdentityPort identity,
    required InvoicesPayServicePort payService,
    required PrivateInvoiceCipher cipher,
    required PrivateInvoiceLinkRepository links,
    required WalletRepository walletRepository,
    required WalletAddressRepository walletAddressRepository,
    required LabelsFacade labels,
    required GetSettingsUsecase getSettings,
  }) : this._(
         identity,
         payService,
         cipher,
         links,
         walletRepository,
         walletAddressRepository,
         labels,
         getSettings,
       );

  const CreateInvoiceUsecase._(
    this._identity,
    this._payService,
    this._cipher,
    this._links,
    this._walletRepository,
    this._walletAddressRepository,
    this._labels,
    this._getSettings,
  );

  @useResult
  Future<Result<CreateInvoiceResult, InvoicesFailure>> execute(
    CreateInvoiceCommand command,
  ) async {
    if (!command.hasAnyRail) {
      return const Err(InvoicesFailure.invalidInput(code: 'NoRailSelected'));
    }
    if (!command.hasExactlyOneAmount) {
      return const Err(InvoicesFailure.invalidInput(code: 'AmountNotOneOf'));
    }

    final signerResult = await _identity.getSigningHandle();
    final BullnymAuthSigner signer;
    switch (signerResult) {
      case Ok(:final value):
        signer = value;
      case Err(:final failure):
        return Err(failure);
    }

    final PreparedPrivateInvoiceCreate? pending;
    try {
      pending = await _links.getPending();
    } on Exception {
      _logStorageFailure('read pending operation');
      return const Err(InvoicesFailure.privateStorage());
    }
    if (pending != null) {
      return _send(signer, pending, allowAddressReplacement: true);
    }

    final Environment environment;
    try {
      environment = (await _getSettings.execute()).environment;
    } on Exception {
      log.warning('Invoice settings lookup failed');
      return const Err(InvoicesFailure.unexpected());
    }
    return _prepareAndSend(command, signer, environment);
  }

  @useResult
  Future<Result<CreateInvoiceResult?, InvoicesFailure>> resumePending() async {
    final PreparedPrivateInvoiceCreate? pending;
    try {
      pending = await _links.getPending();
    } on Exception {
      _logStorageFailure('read pending operation');
      return const Err(InvoicesFailure.privateStorage());
    }
    if (pending == null) return const Ok(null);

    final signerResult = await _identity.getSigningHandle();
    switch (signerResult) {
      case Ok(:final value):
        final result = await _send(
          value,
          pending,
          allowAddressReplacement: true,
        );
        return result.map<CreateInvoiceResult?>((value) => value);
      case Err(:final failure):
        return Err(failure);
    }
  }

  Future<Result<CreateInvoiceResult, InvoicesFailure>> _prepareAndSend(
    CreateInvoiceCommand command,
    BullnymAuthSigner signer,
    Environment environment,
  ) async {
    final reservationIds = <int>[];
    try {
      String? bitcoinAddress;
      if (command.acceptBtc) {
        final wallet = await _defaultBitcoinWalletId(environment);
        switch (wallet) {
          case Ok(:final value):
            bitcoinAddress = await _freshBitcoinAddress(value);
          case Err(:final failure):
            return Err(failure);
        }
      }

      String? liquidAddress;
      String? liquidBlindingKeyHex;
      if (command.needsLiquidAddress) {
        final wallet = await _defaultLiquidWalletId(environment);
        switch (wallet) {
          case Ok(:final value):
            final generated = await _freshLiquidAddress(value, reservationIds);
            switch (generated) {
              case Ok(:final value):
                liquidAddress = value.$1;
                liquidBlindingKeyHex = command.acceptLiquid ? value.$2 : null;
              case Err(:final failure):
                await _releaseReservations(reservationIds);
                return Err(failure);
            }
          case Err(:final failure):
            return Err(failure);
        }
      }

      final EncryptedPrivateInvoice encrypted;
      try {
        encrypted = await _cipher.encrypt(command.presentation);
      } on PrivateInvoicePresentationException catch (error) {
        await _releaseReservations(reservationIds);
        return Err(
          InvoicesFailure.invalidInput(code: '${error.field}:${error.code}'),
        );
      } on Object {
        await _releaseReservations(reservationIds);
        log.warning('Private invoice encryption failed');
        return const Err(InvoicesFailure.encryption());
      }

      final operation = PreparedPrivateInvoiceCreate(
        encrypted: encrypted,
        amountSat: command.amountSat,
        fiatAmountMinor: command.fiatAmountMinor,
        fiatCurrency: command.fiatCurrency,
        acceptBtc: command.acceptBtc,
        acceptLn: command.acceptLn,
        acceptLiquid: command.acceptLiquid,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
        liquidBlindingKeyHex: liquidBlindingKeyHex,
        linkToPageNym: command.linkToPageNym,
        reservationLabelIds: List.unmodifiable(reservationIds),
      );
      try {
        await _links.savePending(operation);
      } on Exception {
        await _releaseReservations(reservationIds);
        _logStorageFailure('save pending operation');
        return const Err(InvoicesFailure.privateStorage());
      }
      return _send(signer, operation, allowAddressReplacement: true);
    } on Exception {
      await _releaseReservations(reservationIds);
      log.warning('Invoice create preparation failed');
      return const Err(InvoicesFailure.unexpected());
    }
  }

  Future<Result<CreateInvoiceResult, InvoicesFailure>> _send(
    BullnymAuthSigner signer,
    PreparedPrivateInvoiceCreate operation, {
    required bool allowAddressReplacement,
  }) async {
    final response = await _payService.createInvoice(
      signer: signer,
      operation: operation,
    );
    switch (response) {
      case Ok(:final value):
        try {
          await _links.retainLink(value.privateLink);
          await _links.deletePending(operation.encrypted.clientRequestId);
        } on Exception {
          _logStorageFailure('commit retained link');
          return const Err(InvoicesFailure.privateStorage());
        }
        return Ok(value);
      case Err(:final failure):
        if (allowAddressReplacement &&
            (failure.kind == InvoicesFailureKind.reusedBitcoinAddress ||
                failure.kind == InvoicesFailureKind.reusedLiquidAddress)) {
          return _replaceRejectedAddress(signer, operation, failure.kind);
        }
        if (_isAmbiguous(failure)) {
          return const Err(InvoicesFailure.outcomeUnknown());
        }
        if (failure.kind == InvoicesFailureKind.createConflict) {
          return Err(failure);
        }
        await _abandon(operation);
        return Err(failure);
    }
  }

  Future<Result<CreateInvoiceResult, InvoicesFailure>> _replaceRejectedAddress(
    BullnymAuthSigner signer,
    PreparedPrivateInvoiceCreate rejected,
    InvoicesFailureKind kind,
  ) async {
    var bitcoinAddress = rejected.bitcoinAddress;
    var liquidAddress = rejected.liquidAddress;
    var liquidBlindingKeyHex = rejected.liquidBlindingKeyHex;
    var reservationIds = List<int>.of(rejected.reservationLabelIds);
    final replacementReservationIds = <int>[];
    try {
      final environment = (await _getSettings.execute()).environment;
      if (kind == InvoicesFailureKind.reusedBitcoinAddress) {
        final wallet = await _defaultBitcoinWalletId(environment);
        switch (wallet) {
          case Ok(:final value):
            bitcoinAddress = await _freshBitcoinAddress(value);
          case Err(:final failure):
            return Err(failure);
        }
      } else {
        final wallet = await _defaultLiquidWalletId(environment);
        switch (wallet) {
          case Ok(:final value):
            final generated = await _freshLiquidAddress(
              value,
              replacementReservationIds,
            );
            switch (generated) {
              case Ok(:final value):
                liquidAddress = value.$1;
                liquidBlindingKeyHex = rejected.acceptLiquid ? value.$2 : null;
              case Err(:final failure):
                return Err(failure);
            }
          case Err(:final failure):
            return Err(failure);
        }
        reservationIds = replacementReservationIds;
      }

      final replacement = PreparedPrivateInvoiceCreate(
        encrypted: EncryptedPrivateInvoice(
          clientRequestId: _cipher.newClientRequestId(),
          presentationEnvelope: rejected.encrypted.presentationEnvelope,
          viewingKey: rejected.encrypted.viewingKey,
        ),
        amountSat: rejected.amountSat,
        fiatAmountMinor: rejected.fiatAmountMinor,
        fiatCurrency: rejected.fiatCurrency,
        acceptBtc: rejected.acceptBtc,
        acceptLn: rejected.acceptLn,
        acceptLiquid: rejected.acceptLiquid,
        bitcoinAddress: bitcoinAddress,
        liquidAddress: liquidAddress,
        liquidBlindingKeyHex: liquidBlindingKeyHex,
        expiresAtUnix: rejected.expiresAtUnix,
        linkToPageNym: rejected.linkToPageNym,
        reservationLabelIds: List.unmodifiable(reservationIds),
      );
      await _links.savePending(replacement);
      if (kind == InvoicesFailureKind.reusedLiquidAddress) {
        await _releaseReservations(rejected.reservationLabelIds);
      }
      return _send(signer, replacement, allowAddressReplacement: false);
    } on Exception {
      await _releaseReservations(replacementReservationIds);
      log.warning('Invoice address replacement failed');
      return const Err(InvoicesFailure.unexpected());
    }
  }

  bool _isAmbiguous(InvoicesFailure failure) => switch (failure.kind) {
    InvoicesFailureKind.network ||
    InvoicesFailureKind.timeout ||
    InvoicesFailureKind.invalidServerResponse ||
    InvoicesFailureKind.server ||
    InvoicesFailureKind.unexpected => true,
    _ => false,
  };

  Future<void> _abandon(PreparedPrivateInvoiceCreate operation) async {
    try {
      await _links.deletePending(operation.encrypted.clientRequestId);
    } on Exception {
      _logStorageFailure('delete rejected operation');
      return;
    }
    await _releaseReservations(operation.reservationLabelIds);
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

  Future<Result<(String, String), InvoicesFailure>> _freshLiquidAddress(
    String walletId,
    List<int> reservationLabelIds,
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
        reservationLabelIds.add(value.id);
        return Ok((generated.address, generated.blindingSecretHex));
      case Err():
        return const Err(InvoicesFailure.unexpected());
    }
  }

  Future<void> _releaseReservations(Iterable<int> labelIds) async {
    for (final id in labelIds) {
      try {
        await _labels.trash(id);
      } on Exception {
        // A leaked reservation burns one address but never permits address reuse.
      }
    }
  }

  void _logStorageFailure(String operation) {
    log.warning(
      'Private invoice storage failed while attempting to $operation',
    );
  }
}
