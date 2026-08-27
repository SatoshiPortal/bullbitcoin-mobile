import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:crypto/crypto.dart';

typedef _AuthenticatedCall<T> =
    Future<Result<T, BullnymFailure>> Function(BullnymAuthentication auth);

Future<Result<T, BullnymFailure>> _runAuthenticated<T>(
  Future<Result<BullnymAuthentication, BullnymFailure>> signed,
  _AuthenticatedCall<T> call,
) async {
  return switch (await signed) {
    Err(:final failure) => Err(failure),
    Ok(:final value) => call(value),
  };
}

final class GetBullnymVersionUsecase {
  final BullnymRepository _repository;

  const GetBullnymVersionUsecase(this._repository);

  Future<Result<BullnymVersionInfo, BullnymFailure>> execute() =>
      _repository.getVersion();
}

final class RegisterBullnymUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const RegisterBullnymUsecase(this._repository, this._authenticator);

  Future<Result<BullnymRegisterResult, BullnymFailure>> execute({
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  }) async {
    if (!_validNpub(verificationNpubHex)) {
      return const Err(BullnymInvalidInputFailure('Invalid verification npub'));
    }
    final signed = await _authenticator.sign(
      action: 'register',
      nym: nym,
      fields: [ctDescriptor, verificationNpubHex],
    );
    return switch (signed) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.npubHex == verificationNpubHex => const Err(
        BullnymInvalidInputFailure('Authentication keys must differ'),
      ),
      Ok(:final value) => _repository.register(
        auth: value,
        nym: nym,
        ctDescriptor: ctDescriptor,
        verificationNpubHex: verificationNpubHex,
      ),
    };
  }

  static bool _validNpub(String value) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) return false;
    try {
      ECPublic.fromHex('02$value');
      return true;
    } on Exception {
      return false;
    }
  }
}

final class DeleteBullnymRegistrationUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const DeleteBullnymRegistrationUsecase(this._repository, this._authenticator);

  Future<Result<void, BullnymFailure>> execute(String nym) => _runAuthenticated(
    _authenticator.sign(action: 'delete', nym: nym, fields: const []),
    (auth) => _repository.deleteRegistration(auth: auth, nym: nym),
  );
}

final class LookupBullnymRegistrationUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const LookupBullnymRegistrationUsecase(this._repository, this._authenticator);

  Future<Result<BullnymLookupResult, BullnymFailure>> execute() async {
    return switch (await _authenticator.publicKey()) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.lookupRegistration(value),
    };
  }
}

final class GetDonationPageUsecase {
  final BullnymRepository _repository;

  const GetDonationPageUsecase(this._repository);

  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required String nym,
    required String kind,
  }) => _repository.getDonationPage(nym: nym, kind: kind);
}

final class SaveDonationPageUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const SaveDonationPageUsecase(this._repository, this._authenticator);

  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
    required BullnymAliasIntent aliasIntent,
  }) {
    final fields = [
      header,
      description,
      displayCurrency,
      website,
      twitter,
      instagram,
      enabled ? '1' : '0',
      ctDescriptor,
      kind,
      if (aliasIntent case BullnymAliasClaim(:final alias)) alias.value,
    ];
    return _runAuthenticated(
      _authenticator.sign(
        action: 'donation-page-save',
        nym: nym,
        fields: fields,
      ),
      (auth) => _repository.saveDonationPage(
        auth: auth,
        nym: nym,
        ctDescriptor: ctDescriptor,
        header: header,
        description: description,
        displayCurrency: displayCurrency,
        website: website,
        twitter: twitter,
        instagram: instagram,
        enabled: enabled,
        kind: kind,
        aliasIntent: aliasIntent,
      ),
    );
  }
}

final class ArchiveDonationPageUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const ArchiveDonationPageUsecase(this._repository, this._authenticator);

  Future<Result<BullnymDonationPage, BullnymFailure>> execute({
    required String nym,
    required String kind,
  }) => _runAuthenticated(
    _authenticator.sign(
      action: 'donation-page-archive',
      nym: nym,
      fields: [kind],
    ),
    (auth) => _repository.archiveDonationPage(auth: auth, nym: nym, kind: kind),
  );
}

final class GetSupportedCurrenciesUsecase {
  final BullnymRepository _repository;

  const GetSupportedCurrenciesUsecase(this._repository);

  Future<Result<BullnymSupportedCurrencies, BullnymFailure>> execute() =>
      _repository.getSupportedCurrencies();
}

final class LookupRecoveryAddressUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const LookupRecoveryAddressUsecase(this._repository, this._authenticator);

  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  execute() => _runAuthenticated(
    _authenticator.sign(
      action: 'recovery-address-get',
      nym: '',
      fields: const [],
    ),
    _repository.lookupRecoveryAddress,
  );
}

final class RegisterRecoveryAddressUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const RegisterRecoveryAddressUsecase(this._repository, this._authenticator);

  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  execute(String btcAddress) {
    if (btcAddress.isEmpty ||
        btcAddress != btcAddress.trim() ||
        btcAddress.contains('\u0000')) {
      return Future.value(
        const Err(BullnymInvalidInputFailure('Invalid recovery address')),
      );
    }
    return _runAuthenticated(
      _authenticator.sign(
        action: 'recovery-address-set',
        nym: '',
        fields: ['$bullnymRecoveryAddressContractVersion', btcAddress],
      ),
      (auth) => _repository.registerRecoveryAddress(
        auth: auth,
        btcAddress: btcAddress,
      ),
    );
  }
}

final class CreateInvoiceUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const CreateInvoiceUsecase(this._repository, this._authenticator);

  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> execute({
    required String? nym,
    required BullnymCreateInvoiceFields fields,
  }) {
    if (!fields.hasValidPrivatePresentation) {
      return Future.value(
        const Err(BullnymInvalidInputFailure('Invalid invoice presentation')),
      );
    }
    return _runAuthenticated(
      _authenticator.sign(
        action: 'invoice-create',
        nym: nym ?? '',
        fields: [
          '${fields.amountSat ?? ''}',
          '${fields.fiatAmountMinor ?? ''}',
          fields.fiatCurrency ?? '',
          fields.clientRequestId,
          fields.presentationEnvelope,
          '${fields.acceptBtc}',
          '${fields.acceptLn}',
          '${fields.acceptLiquid}',
          fields.bitcoinAddress ?? '',
          fields.liquidAddress ?? '',
          fields.liquidBlindingKeyHex ?? '',
          '${fields.expiresAtUnix ?? ''}',
        ],
      ),
      (auth) => _repository.createInvoice(auth: auth, nym: nym, fields: fields),
    );
  }
}

final class CancelInvoiceUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const CancelInvoiceUsecase(this._repository, this._authenticator);

  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> execute({
    required String? nym,
    required String invoiceId,
  }) => _runAuthenticated(
    _authenticator.sign(
      action: 'invoice-cancel',
      nym: nym ?? '',
      fields: [invoiceId],
    ),
    (auth) =>
        _repository.cancelInvoice(auth: auth, nym: nym, invoiceId: invoiceId),
  );
}

final class ListInvoicesUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const ListInvoicesUsecase(this._repository, this._authenticator);

  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> execute({
    required int page,
    required int pageSize,
    required String? status,
  }) => _runAuthenticated(
    _authenticator.sign(
      action: 'invoice-list',
      nym: '',
      fields: ['$page', '$pageSize', status ?? ''],
    ),
    (auth) => _repository.listInvoices(
      auth: auth,
      page: page,
      pageSize: pageSize,
      status: status,
    ),
  );
}

final class ListFallbackSupervisionUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const ListFallbackSupervisionUsecase(this._repository, this._authenticator);

  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  execute() => _runAuthenticated(
    _authenticator.sign(
      action: 'invoice-recovery-list',
      nym: '',
      fields: const [],
    ),
    _repository.listFallbackSupervision,
  );
}

final class ListGetPaidTransactionsUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const ListGetPaidTransactionsUsecase(this._repository, this._authenticator);

  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>> execute({
    required String cursor,
    required int limit,
  }) {
    if (limit < 1 ||
        limit > bullnymGetPaidTransactionMaxPageSize ||
        cursor.contains('\u0000') ||
        utf8.encode(cursor).length > bullnymGetPaidTransactionMaxCursorBytes) {
      return Future.value(
        const Err(BullnymInvalidInputFailure('Invalid pagination')),
      );
    }
    return _runAuthenticated(
      _authenticator.sign(
        action: 'get-paid-transaction-list',
        nym: '',
        fields: [cursor, '$limit'],
      ),
      (auth) => _repository.listGetPaidTransactions(
        auth: auth,
        cursor: cursor,
        limit: limit,
      ),
    );
  }
}

final class GetInvoiceStatusUsecase {
  final BullnymRepository _repository;

  const GetInvoiceStatusUsecase(this._repository);

  Future<Result<BullnymInvoiceStatus, BullnymFailure>> execute(
    String invoiceId,
  ) => _repository.getInvoiceStatus(invoiceId);
}

final class GetInvoiceQuoteUsecase {
  final BullnymRepository _repository;

  const GetInvoiceQuoteUsecase(this._repository);

  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>> execute({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) => _repository.getInvoiceQuote(invoiceId: invoiceId, rail: rail);
}

final class GetFiatSettlementUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const GetFiatSettlementUsecase(this._repository, this._authenticator);

  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  execute() => _runAuthenticated(
    _authenticator.sign(
      action: 'fiat-settlement-get',
      nym: '',
      fields: const ['$bullnymFiatSettlementContractVersion'],
    ),
    _repository.getFiatSettlementConfiguration,
  );
}

final class SetFiatSettlementUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const SetFiatSettlementUsecase(this._repository, this._authenticator);

  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>> execute({
    required BullnymFiatSettlementProduct product,
    required int fiatPercentage,
    required String? fiatCurrency,
    required String? apiKey,
  }) {
    final disabling = fiatPercentage == 0;
    if (fiatPercentage < 0 ||
        fiatPercentage > 100 ||
        (disabling && (fiatCurrency != null || apiKey != null)) ||
        (!disabling && fiatCurrency == null)) {
      return Future.value(
        const Err(BullnymInvalidInputFailure('Invalid fiat settlement')),
      );
    }
    return _runAuthenticated(
      _authenticator.sign(
        action: 'fiat-settlement-set',
        nym: '',
        fields: [
          '$bullnymFiatSettlementContractVersion',
          product.wire,
          '$fiatPercentage',
          fiatCurrency ?? '',
          apiKey ?? '',
        ],
      ),
      (auth) => _repository.setFiatSettlement(
        auth: auth,
        product: product,
        fiatPercentage: fiatPercentage,
        fiatCurrency: fiatCurrency,
        apiKey: apiKey,
      ),
    );
  }
}

final class FetchBullnymBackupUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const FetchBullnymBackupUsecase(this._repository, this._authenticator);

  Future<Result<BullnymBackupHead, BullnymFailure>> execute(
    BullnymBackupStream stream,
  ) => _runAuthenticated(
    _authenticator.signBackup(
      action: 'backup-fetch',
      stream: stream,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
    ),
    (auth) => _repository.fetchBackup(auth: auth, stream: stream),
  );
}

final class StoreBullnymBackupUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const StoreBullnymBackupUsecase(this._repository, this._authenticator);

  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> execute({
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required BullnymBackupCiphertext ciphertext,
  }) async {
    final generation = currentHead.generation + 1;
    final hash = sha256.convert(base64.decode(ciphertext.value)).toString();
    final signed = await _authenticator.signBackup(
      action: 'backup-store',
      stream: stream,
      generation: generation,
      expectedEtag: currentHead.etag ?? '',
      ciphertextSha256: hash,
      ciphertextBytes: ciphertext.byteLength,
    );
    return switch (signed) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _verifiedStore(
        value,
        stream,
        generation,
        currentHead.etag,
        ciphertext,
        hash,
      ),
    };
  }

  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> _verifiedStore(
    BullnymAuthentication auth,
    BullnymBackupStream stream,
    int generation,
    String? expectedEtag,
    BullnymBackupCiphertext ciphertext,
    String hash,
  ) async {
    final result = await _repository.storeBackup(
      auth: auth,
      stream: stream,
      generation: generation,
      expectedEtag: expectedEtag,
      ciphertext: ciphertext,
      ciphertextSha256: hash,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value)
          when value.generation == generation &&
              value.etag ==
                  computeBullnymBackupEtag(
                    stream: stream,
                    npubHex: auth.npubHex,
                    generation: generation,
                    ciphertextSha256: hash,
                  ) =>
        Ok(value),
      Ok() => const Err(
        BullnymInvalidResponseFailure(
          phase: BullnymRequestPhase.write,
          logMessage: 'Inconsistent backup receipt',
        ),
      ),
    };
  }
}

final class DeleteBullnymBackupUsecase {
  final BullnymRepository _repository;
  final BullnymAuthenticator _authenticator;

  const DeleteBullnymBackupUsecase(this._repository, this._authenticator);

  Future<Result<BullnymBackupDeleteReceipt?, BullnymFailure>> execute({
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) async {
    if (!currentHead.found) return const Ok(null);
    final etag = currentHead.etag;
    if (etag == null) {
      return const Err(BullnymInvalidInputFailure('Incomplete backup head'));
    }
    final generation = currentHead.generation + 1;
    final signed = await _authenticator.signBackup(
      action: 'backup-delete',
      stream: stream,
      generation: generation,
      expectedEtag: etag,
      ciphertextSha256: '',
      ciphertextBytes: 0,
    );
    final BullnymAuthentication auth;
    switch (signed) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        auth = value;
    }
    final result = await _repository.deleteBackup(
      auth: auth,
      stream: stream,
      generation: generation,
      expectedEtag: etag,
    );
    return switch (result) {
      Err(:final failure) => Err(failure),
      Ok(:final value)
          when value.generation == generation &&
              value.etag ==
                  computeBullnymBackupEtag(
                    stream: stream,
                    npubHex: auth.npubHex,
                    generation: generation,
                    ciphertextSha256: '',
                  ) =>
        Ok(value),
      Ok() => const Err(
        BullnymInvalidResponseFailure(
          phase: BullnymRequestPhase.delete,
          logMessage: 'Inconsistent backup receipt',
        ),
      ),
    };
  }
}
