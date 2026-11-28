import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:ark/ark.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart' as sync;
import 'package:sync/write.dart';

import 'package:fees/fees.dart';

import 'sqlite_ark_funding_reservations.dart';

/// Main-wallet Board funding. No Bark key, raw PSBT or data binding leaves here.
/// Every ambiguous signer/delivery result retains the original operation/holds.
final class WalletArkBoardFunding implements ArkTransferBoardFundingPort {
  final ArkClient _client;
  final WalletNativeRuntime _runtime;
  final SqliteArkFundingReservations _authority;
  final WalletInventory _inventory;
  final Future<Result<void, sync.SyncFailure>> Function(sync.WalletKey)
  _sourceSync;
  final Secrets _secrets;
  final Fees _fees;
  final ParentCustodyAdmissionPort _custody;
  final Future<String> Function(ArkAccountId) _sourceWalletId;
  final Set<Future<void>> _requests = {};
  final Map<
    (ArkAccountId, String, String),
    Future<Result<ArkOperation, ArkFailure>>
  >
  _confirming = {};
  final Set<ArkAccountId> _preparing = {};
  bool _closed = false;

  WalletArkBoardFunding({
    required this._client,
    required this._runtime,
    required this._authority,
    required this._inventory,
    required this._sourceSync,
    required this._secrets,
    required this._fees,
    required this._custody,
    required this._sourceWalletId,
  });

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepare(
    ArkAccountConfig config,
    Sats amount,
  ) => _prepare(config, amount);

  static String _exitReserveId(ArkAccountId account) =>
      'exit-reserve-${sha256.convert(utf8.encode(account.canonical))}';

  Future<Result<String?, ArkFailure>> readInitialExitDestination(
    ArkAccountId account,
    List<String> selectedIds,
  ) => _track(() async {
    try {
      final entry = _sync(
        await _authority.readExitReserveRequest(_exitReserveId(account)),
      );
      if (entry == null) return const Ok(null);
      final saved = jsonDecode(entry.context);
      final ids = selectedIds.toList()..sort();
      if (saved is Map<String, dynamic> &&
          saved['account'] == account.canonical &&
          jsonEncode(saved['ids']) == jsonEncode(ids)) {
        if (saved['destination'] case final String destination) {
          return Ok(destination);
        }
      }
      return const Ok(null);
    } on FormatException {
      return const Err(ArkFeatureStorageFailure());
    } on _HostFailure catch (error) {
      return Err(error.failure);
    }
  });

  Future<Result<ArkExitReserveFunding, ArkFailure>> fundInitialExit(
    ArkQuote quote,
    String? reserveAddress, {
    required bool Function() isCurrent,
  }) => _track(() async {
    final account = quote.account;
    final destination = quote.destination;
    if (quote.kind != ArkOperationKind.emergencyExit ||
        destination == null ||
        reserveAddress == null ||
        reserveAddress.isEmpty ||
        quote.fee.value <= BigInt.zero) {
      return const Err(ArkInvalidRequestFailure());
    }
    if (!_preparing.add(account)) return const Err(ArkOperationBusyFailure());
    final id = _exitReserveId(account);
    try {
      final metadata = await _eligible(await _sourceWalletId(account));
      final parent = metadata.secretFingerprint;
      if (parent == null || parent != account.parent) {
        return const Err(ArkAccountRecoveryFailure());
      }
      final key = sync.WalletKey(id: metadata.id, network: metadata.network);
      final ids = quote.selectedIds.toList()..sort();
      final terms = {
        'version': 1,
        'type': 'exitReserve',
        'account': account.canonical,
        'ids': ids,
        'destination': destination,
        'reserveAddress': reserveAddress,
        'chainSource': quote.chainSource.toString(),
      };
      var entry = _sync(await _authority.readExitReserveRequest(id));
      // The CPFP output must remain spendable after the last fee debit.
      var amount = Sats(quote.fee.value + BigInt.from(1000));
      var context = jsonEncode({...terms, 'sats': amount.value.toString()});
      if (entry == null) {
        if (!DateTime.now().toUtc().isBefore(quote.validUntil)) {
          return const Err(ArkReviewExpiredFailure());
        }
        final handle = _sync(await _runtime.wallet(key));
        final pinned = await _custody.runExclusive<void>(parent, (lease) async {
          if (lease.readState() case Ok(value: ParentCustodyState.ready)) {
            if (await _secrets.fetch(parent) case Ok(:final value)
                when value.info.isMnemonic) {
              return switch (await _authority.beginExitReserveRequest(
                operationId: id,
                accountIdentity: account.canonical,
                sourceParent: parent,
                key: key,
                generation: handle.generation,
                context: context,
              )) {
                Ok() => const Ok(null),
                Err() => const Err(ParentCustodyStorageFailure()),
              };
            }
          }
          return const Err(ParentCustodyStateFailure());
        });
        if (pinned is Err) return const Err(ArkAccountRecoveryFailure());
        entry = _sync(await _authority.readExitReserveRequest(id));
      }
      if (entry == null) return const Err(ArkFeatureStorageFailure());
      final saved = jsonDecode(entry.context);
      if (saved is! Map<String, dynamic> || saved['sats'] is! String) {
        return const Err(ArkFeatureStorageFailure());
      }
      final sats = BigInt.tryParse(saved['sats'] as String);
      if (sats == null || sats < quote.fee.value) {
        return Err(ArkSubmissionUncertainFailure(id));
      }
      amount = Sats(sats);
      context = jsonEncode({...terms, 'sats': sats.toString()});
      if (entry.context != context ||
          entry.state == 'conflicted' ||
          entry.state == 'tombstoned') {
        return Err(ArkSubmissionUncertainFailure(id));
      }
      if (entry.confirmed) {
        final binding = _sync(await _authority.readBinding(id));
        final txid = entry.txid;
        if (txid == null ||
            txid != binding.unsignedTxid ||
            binding.key != key ||
            binding.sourceParent != parent ||
            binding.context != context) {
          return const Err(ArkFeatureStorageFailure());
        }
        // Scuttle verifies the output against the active chain at quote time.
        return Ok(ArkExitReserveFunding(txid: txid, amount: amount));
      }
      _sync(await _refreshSource(metadata));
      final handle = _sync(await _runtime.wallet(key));
      if (entry.state == 'requested') {
        final fastest = switch (await _fees.estimate(metadata.network)) {
          Ok(:final value) => value.fastest,
          Err() => throw const _HostFailure(ArkNetworkUnavailableFailure()),
        };
        if (fastest is! RelativeFee || fastest.satPerKwu <= 0) {
          return const Err(ArkNetworkUnavailableFailure());
        }
        _sync(
          await handle.tx.prepareFunding(
            sync.BitcoinSpendRequest(
              recipients: [
                sync.SpendRecipient(reserveAddress, amountSat: sats.toInt()),
              ],
              fee: sync.SpendFeeRate(fastest.satPerKwu),
              owner: sync.SpendOwner(protocol: 'ark', session: id),
            ),
            context: context,
          ),
        );
      }
      final binding = _sync(await _authority.readBinding(id));
      _require(
        binding.key == key &&
            binding.sourceParent == parent &&
            binding.context == context,
      );
      final loaded = _sync(await handle.load());
      final history = handle.history.now;
      if (history.revision == loaded &&
          history.status == sync.ValueStatus.ready) {
        final transactions = history.data?.whereType<sync.BitcoinTransaction>();
        if (transactions != null) {
          for (final tx in transactions) {
            if (tx.txid != binding.unsignedTxid) continue;
            if ((tx.confirmationTime ?? 0) > 0) {
              _sync(
                await _runtime.withBitcoinRevisionAdmission(key, (
                  revision,
                ) async {
                  _require(revision == loaded);
                  _sync(
                    await _authority.observe(
                      key,
                      history,
                      admittedRevision: revision,
                    ),
                  );
                }),
              );
              final settled = _sync(
                await _authority.readExitReserveRequest(id),
              );
              if (settled?.confirmed != true || settled?.txid != tx.txid) {
                return const Err(ArkFeatureStorageFailure());
              }
              return Ok(ArkExitReserveFunding(txid: tx.txid, amount: amount));
            }
            return const Err(ArkOperationBusyFailure());
          }
        }
      }
      if (!isCurrent()) return const Err(ArkServiceUnavailableFailure());
      final String signed;
      if (entry.signedPsbt case final String savedSigned) {
        signed = savedSigned;
      } else {
        final ownership = _sync(await handle.ownership());
        _require(ownership.revision == loaded);
        _checkOutputs(
          _sync(sync.inspectBitcoinPsbt(binding.unsignedPsbt)),
          reserveAddress,
          amount,
          ownership,
        );
        _sync(
          await _runtime.withBitcoinRevisionAdmission(key, (revision) async {
            _require(revision == loaded);
            _sync(
              await _authority.admitExitReserveSigning(
                expected: binding,
                admittedRevision: revision,
              ),
            );
          }),
        );
        final secret = _secret(await _secrets.fetch(parent));
        _require(secret.info.isMnemonic);
        final candidate = _secret(
          await secret.sign.psbt(
            binding.unsignedPsbt,
            network: BitcoinNetwork.regtest,
            scriptType: metadata.scriptType,
          ),
        );
        signed = candidate;
        _sync(await _authority.recordSigned(id, signed));
      }
      if (!isCurrent()) return const Err(ArkServiceUnavailableFailure());
      final receipt = _sync(
        await _runtime.broadcast(
          key,
          sync.SignedPsbt(signed),
          network: BitcoinNetwork.regtest,
          built: sync.UnsignedSpend(
            revision: binding.revision,
            encoded: binding.unsignedPsbt,
            inputs: binding.inputs,
            owner: sync.SpendOwner(protocol: 'ark', session: id),
          ),
        ),
      );
      _require(
        receipt.durable &&
            receipt.guarded &&
            receipt.txid == binding.unsignedTxid,
      );
      return const Err(ArkOperationBusyFailure());
    } catch (error) {
      if (error is Error) rethrow;
      return Err(_failure(error));
    } finally {
      _preparing.remove(account);
    }
  });

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> prepareFrom(
    ArkAccountConfig config,
    Sats amount, {
    required String sourceWalletId,
  }) => _prepare(config, amount, expectedSourceWalletId: sourceWalletId);

  Future<Result<ArkBoardPreparation, ArkFailure>> _prepare(
    ArkAccountConfig config,
    Sats amount, {
    String? expectedSourceWalletId,
  }) => _track(() async {
    if (!_preparing.add(config.id)) return const Err(ArkOperationBusyFailure());
    final id = _id();
    bool journalAttempted = false;
    try {
      _require(
        config.id.network == BitcoinNetwork.regtest &&
            amount.value > BigInt.zero,
      );
      final sourceWalletId = await _sourceWalletId(config.id);
      _require(
        expectedSourceWalletId == null ||
            expectedSourceWalletId == sourceWalletId,
      );
      final existing = _sync(
        await _authority.pendingForAccount(config.id.canonical),
      );
      if (existing != null) {
        await reconcileSource(existing);
        final remaining = _sync(
          await _authority.pendingForAccount(config.id.canonical),
        );
        if (remaining != null) {
          return Err(ArkSubmissionUncertainFailure(remaining));
        }
      }
      final metadata = await _eligible(sourceWalletId);
      final parent = metadata.secretFingerprint;
      if (parent == null) throw const _HostFailure(ArkAccountRecoveryFailure());
      _require(parent == config.id.parent);
      await _refreshSource(metadata);
      final handle = _sync(
        await _runtime.wallet(
          sync.WalletKey(id: metadata.id, network: metadata.network),
        ),
      );
      _sync(await handle.load());
      final fastest = switch (await _fees.estimate(metadata.network)) {
        Ok(:final value) => value.fastest,
        Err() => throw const _HostFailure(ArkNetworkUnavailableFailure()),
      };
      if (fastest is! RelativeFee || fastest.satPerKwu <= 0) {
        throw const _HostFailure(ArkNetworkUnavailableFailure());
      }
      final quote = _ark(
        await _client.quote(config.id, ArkQuoteRequest.board(amount: amount)),
      );
      _require(
        quote.account == config.id &&
            (quote.chainSource == config.primaryEsploraUrl ||
                quote.chainSource == config.fallbackEsploraUrl) &&
            quote.kind == ArkOperationKind.board &&
            quote.amount == amount &&
            quote.fee.value + quote.net.value == quote.amount.value &&
            quote.net.value > BigInt.zero &&
            DateTime.now().toUtc().isBefore(quote.validUntil),
      );
      final evidence = quote.boardEvidence;
      final context = jsonEncode({
        'version': evidence == null ? 1 : 2,
        'account': config.id.canonical,
        'quoteId': quote.id,
        'amount': quote.amount.value.toString(),
        'arkFee': quote.fee.value.toString(),
        'net': quote.net.value.toString(),
        'fastSatPerKwu': fastest.satPerKwu,
        'validUntil': quote.validUntil.toUtc().toIso8601String(),
        'chainSource': quote.chainSource.toString(),
        'configGeneration': quote.configGeneration,
        'arkUrl': config.arkUrl.toString(),
        'primary': config.primaryEsploraUrl.toString(),
        'fallback': config.fallbackEsploraUrl?.toString(),
        if (evidence != null) ...{
          'observedTip': quote.observedTip,
          'tipHash': evidence.tipHash,
          'serverKey': evidence.serverKey,
          'requiredConfirmations': evidence.requiredConfirmations,
        },
      });
      final pinned = await _custody.runExclusive<void>(parent, (lease) async {
        if (lease.readState() case Ok(value: ParentCustodyState.ready)) {
          if (await _secrets.fetch(parent) case Ok(:final value)
              when value.info.isMnemonic) {
            journalAttempted = true; // Err may follow a durable request commit.
            return switch (await _authority.beginBoardRequest(
              operationId: id,
              accountIdentity: config.id.canonical,
              sourceParent: parent,
              key: handle.key,
              generation: handle.generation,
              context: context,
            )) {
              Ok() => const Ok(null),
              Err() => const Err(ParentCustodyStorageFailure()),
            };
          }
          return const Err(ParentCustodySeedUnavailableFailure());
        }
        return const Err(ParentCustodyStateFailure());
      });
      if (pinned is Err) throw const _HostFailure(ArkAccountRecoveryFailure());
      // No parent/source lease spans package native work or the human review.
      final operation = _ark(
        await _client.submit(
          config.id,
          ArkSubmission.boardFunding(operationId: id, quoteId: quote.id),
        ),
      );
      final funding = operation.boardFunding;
      _require(
        operation.id == id &&
            operation.kind == ArkOperationKind.board &&
            operation.status == ArkOperationStatus.prepared &&
            funding != null &&
            operation.chainSource == quote.chainSource &&
            operation.configGeneration == quote.configGeneration,
      );
      if (funding == null ||
          (funding.scuttleToken != null) != (evidence != null)) {
        throw const _HostFailure(ArkServiceUnavailableFailure());
      }
      final built = _sync(
        await handle.tx.prepareFunding(
          sync.BitcoinSpendRequest(
            recipients: [
              sync.SpendRecipient(
                funding.address,
                amountSat: quote.amount.value.toInt(),
              ),
            ],
            fee: sync.SpendFeeRate(fastest.satPerKwu),
            owner: sync.SpendOwner(protocol: 'ark', session: id),
          ),
          context: context,
        ),
      );
      _sync(await handle.load());
      final ownership = _sync(await handle.ownership());
      final facts = _sync(sync.inspectBitcoinPsbt(built.encoded));
      _checkOutputs(facts, funding.address, quote.amount, ownership);
      _require(
        built.inputs.length == facts.inputs.length &&
            built.inputs.every(ownership.ownsOutpoint) &&
            ownership.revision.generation == built.revision.generation,
      );
      final registered = _ark(
        await _client.submit(
          config.id,
          ArkSubmission.registerBoard(
            operationId: id,
            unfinalisedPsbt: built.encoded,
            keypairIndex: funding.keypairIndex,
            expiryHeight: funding.expiryHeight,
          ),
        ),
      );
      _require(
        registered.status == ArkOperationStatus.pending &&
            registered.nativeReference == facts.unsignedTxid &&
            registered.id == id,
      );
      _sync(
        await _authority.saveBoardReview(
          id,
          jsonEncode({
            'request': context,
            'address': funding.address,
            'keypairIndex': ?funding.keypairIndex,
            if (funding.scuttleToken case final token?)
              'scuttleTokenDigest': _fundingTokenDigest(token),
            'expiryHeight': funding.expiryHeight,
            'minerFee': facts.feeSat,
          }),
        ),
      );
      if (evidence == null) {
        // Preserve Bark's complete inventory barrier.
        final pass = _ark(await _client.synchronize(config.id, renew: false));
        _require(
          pass.failedStages.isEmpty &&
              !pass.snapshot.stale &&
              pass.snapshot.account == config.id,
        );
      }
      return switch (await _read(config.id, id)) {
        Ok(:final value) => Ok(value),
        Err() => Err(ArkSubmissionUncertainFailure(id)),
      };
    } catch (error) {
      if (error is Error) rethrow;
      final cause = _failure(error);
      if (journalAttempted) {
        log.warning('Ark board prepare failed: ${cause.runtimeType}');
        // Preparing never signs, so nothing can have left the wallet. Settle
        // the reservation now: once it is released the outcome is known,
        // and the user is told why and may simply try again.
        _preparing.remove(config.id);
        await reconcileSource(id);
        final pending = await _authority.pendingForAccount(config.id.canonical);
        if (pending case Ok(value: null)) {
          return Err(
            cause is ArkSubmissionUncertainFailure
                ? const ArkServiceUnavailableFailure()
                : cause,
          );
        }
        return Err(
          ArkSubmissionUncertainFailure(switch (pending) {
            Ok(:final value) => value ?? id,
            Err() => id,
          }),
        );
      }
      return Err(cause);
    } finally {
      _preparing.remove(config.id);
    }
  });

  @override
  Future<Result<ArkBoardPreparation, ArkFailure>> readPrepared(
    ArkAccountId account,
    String operationId,
  ) => _track(() => _read(account, operationId));

  Future<Result<ArkBoardPreparation, ArkFailure>> _read(
    ArkAccountId account,
    String operationId,
  ) async {
    try {
      final entry = _sync(await _authority.readBoardReview(operationId));
      _require(entry.binding.accountIdentity == account.canonical);
      if (entry.phase != 'prepared') {
        return Err(ArkSubmissionUncertainFailure(operationId));
      }
      final review = _Review(entry, account);
      await _eligible(entry.binding.key.id, expected: entry.binding);
      final handle = _sync(await _runtime.wallet(entry.binding.key));
      _sync(await handle.load());
      final ownership = _sync(await handle.ownership());
      _checkOutputs(
        _sync(sync.inspectBitcoinPsbt(entry.binding.unsignedPsbt)),
        review.address,
        review.display.fundingAmount,
        ownership,
      );
      if (review.boardEvidence == null) {
        final snapshot = _ark(await _client.read(account));
        _packageOperation(snapshot, review);
        _require(!snapshot.stale);
      } else {
        await _fresh(review);
      }
      _unexpired(review);
      return Ok(review.display);
    } catch (error) {
      if (error is Error) rethrow;
      return Err(_failure(error));
    }
  }

  @override
  Future<Result<ArkOperation, ArkFailure>> confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) {
    final key = (account, operationId, reviewBinding);
    final previous = _confirming[key];
    if (previous != null) return previous;
    final action = _track(() => _confirm(account, operationId, reviewBinding));
    _confirming[key] = action;
    // Durable DB phase, not this map, arbitrates another engine/restart.
    unawaited(
      action.then<void>(
        (_) {
          _confirming.remove(key);
        },
        onError: (Object error, StackTrace stack) {
          _confirming.remove(key);
        },
      ),
    );
    return action;
  }

  Future<Result<ArkOperation, ArkFailure>> _confirm(
    ArkAccountId account,
    String operationId,
    String reviewBinding,
  ) async {
    bool admitted = false;
    try {
      final entry = _sync(await _authority.readBoardReview(operationId));
      final review = _Review(entry, account);
      _require(review.display.reviewBinding == reviewBinding);
      if (entry.phase == 'broadcast') {
        return Ok(_packageOperation(_ark(await _client.read(account)), review));
      }
      if (entry.phase != 'prepared') {
        return Err(ArkSubmissionUncertainFailure(operationId));
      }
      final metadata = await _eligible(
        entry.binding.key.id,
        expected: entry.binding,
      );
      await _fresh(review);
      final handle = _sync(
        await _runtime.wallet(
          sync.WalletKey(id: metadata.id, network: metadata.network),
        ),
      );
      final loaded = _sync(await handle.load());
      final ownership = _sync(await handle.ownership());
      _require(
        loaded == ownership.revision &&
            loaded.generation == entry.binding.revision.generation,
      );
      _checkOutputs(
        _sync(sync.inspectBitcoinPsbt(entry.binding.unsignedPsbt)),
        review.address,
        review.display.fundingAmount,
        ownership,
      );
      _sync(
        await _runtime.withBitcoinRevisionAdmission(entry.binding.key, (
          revision,
        ) async {
          _require(revision == loaded);
          // A failed CAS may follow a durable irreversible seal.
          admitted = true;
          _sync(
            await _authority.admitBoardSigning(
              expected: entry.binding,
              admittedRevision: revision,
            ),
          );
        }),
      );
      // The normal source lease is actually CLOSED before the first signer.
      _unexpired(review);
      final secret = _secret(await _secrets.fetch(entry.binding.sourceParent));
      _require(secret.info.isMnemonic);
      final signed = _secret(
        await secret.sign.psbt(
          entry.binding.unsignedPsbt,
          network: BitcoinNetwork.regtest,
          scriptType: metadata.scriptType,
        ),
      );
      _sync(await _authority.recordSigned(operationId, signed));
      _sync(
        await _authority.advanceBoardDelivery(
          operationId,
          expectedPhase: 'signing',
          nextPhase: 'signed',
        ),
      );
      // Refresh current provider/tip/fees after signing, before broadcast admission.
      await _fresh(review);
      _sync(
        await _authority.advanceBoardDelivery(
          operationId,
          expectedPhase: 'signed',
          nextPhase: 'broadcasting',
        ),
      );
      _unexpired(review);
      final built = sync.UnsignedSpend(
        revision: entry.binding.revision,
        encoded: entry.binding.unsignedPsbt,
        inputs: entry.binding.inputs,
        owner: sync.SpendOwner(protocol: 'ark', session: operationId),
      );
      final receipt = _sync(
        await _runtime.broadcast(
          sync.WalletKey(id: metadata.id, network: metadata.network),
          sync.SignedPsbt(signed),
          network: BitcoinNetwork.regtest,
          built: built,
        ),
      );
      _require(
        receipt.guarded &&
            receipt.durable &&
            receipt.txid == entry.binding.unsignedTxid,
      );
      _sync(await _authority.finishBoardBroadcast(operationId, receipt));
      return Ok(_packageOperation(_ark(await _client.read(account)), review));
    } catch (error) {
      if (error is Error) rethrow;
      log.warning(
        'Ark board confirm stopped: ${_failure(error).runtimeType} '
        'signed=$admitted',
      );
      return Err(
        admitted ? ArkSubmissionUncertainFailure(operationId) : _failure(error),
      );
    }
  }

  /// Finishes a Board the user confirmed and the app signed but did not
  /// broadcast: the check before broadcasting refused it then (a block
  /// landed, Ark was busy, the app closed). Its coins stay held, and only
  /// these signed bytes can move them, so the background check broadcasts
  /// them once the same checks pass again. Never while a confirm for it
  /// runs here; the durable phase arbitrates anything else.
  Future<Result<void, ArkFailure>> deliverSigned(
    ArkAccountId account,
    String operationId,
  ) => _track(() async {
    if (_confirming.keys.any((key) => key.$2 == operationId)) {
      return const Ok(null);
    }
    try {
      final entry = _sync(await _authority.readBoardReview(operationId));
      final signed = entry.signedPsbt;
      if (signed == null ||
          (entry.phase != 'signed' && entry.phase != 'broadcasting')) {
        return const Ok(null);
      }
      final review = _Review(entry, account);
      final metadata = await _eligible(
        entry.binding.key.id,
        expected: entry.binding,
      );
      await _fresh(review, quoteLifetime: false);
      if (entry.phase == 'signed') {
        _sync(
          await _authority.advanceBoardDelivery(
            operationId,
            expectedPhase: 'signed',
            nextPhase: 'broadcasting',
          ),
        );
      }
      final built = sync.UnsignedSpend(
        revision: entry.binding.revision,
        encoded: entry.binding.unsignedPsbt,
        inputs: entry.binding.inputs,
        owner: sync.SpendOwner(protocol: 'ark', session: operationId),
      );
      final receipt = _sync(
        await _runtime.broadcast(
          sync.WalletKey(id: metadata.id, network: metadata.network),
          sync.SignedPsbt(signed),
          network: BitcoinNetwork.regtest,
          built: built,
        ),
      );
      _require(
        receipt.guarded &&
            receipt.durable &&
            receipt.txid == entry.binding.unsignedTxid,
      );
      _sync(await _authority.finishBoardBroadcast(operationId, receipt));
      log.fine('Ark board delivered after signing');
      return const Ok(null);
    } catch (error) {
      if (error is Error) rethrow;
      final failure = _failure(error);
      log.warning('Ark board delivery waiting: ${failure.runtimeType}');
      return Err(failure);
    }
  });

  /// Positive native source evidence may close only its source pin. No caller
  /// history, package acknowledgement or absence proof. The only local closure
  /// is a request that never reserved, fenced against every future old reserve.
  Future<Result<void, ArkFailure>> reconcileSource(
    String operationId,
  ) => _track(() async {
    try {
      final request = _sync(
        await _authority.readUnpreparedRequest(operationId),
      );
      final binding = request == null
          ? _sync(await _authority.readBinding(operationId))
          : null;
      final key = request?.key ?? binding?.key;
      final parent = request?.sourceParent ?? binding?.sourceParent;
      if (key == null || parent == null) {
        throw const _HostFailure(ArkFeatureStorageFailure());
      }
      final expiredUnsigned =
          binding != null &&
          _sync(
            await _authority.expiredUnsignedBoardReview(
              operationId,
              DateTime.now().toUtc(),
            ),
          );
      // A reservation that stopped before Ark registered it can never be
      // signed: release it, unless this app is preparing it right now.
      final unregistered =
          binding != null &&
          !_preparing.any(
            (account) => account.canonical == binding.accountIdentity,
          ) &&
          _sync(await _authority.unregisteredNeverSignedBoard(operationId));
      final metadata = await _eligible(key.id, expected: binding);
      _require(metadata.secretFingerprint == parent);
      _sync(await _refreshSource(metadata));
      final handle = _sync(
        await _runtime.wallet(
          sync.WalletKey(id: metadata.id, network: metadata.network),
        ),
      );
      final loaded = _sync(await handle.load());
      final ownership = _sync(await handle.ownership());
      final history = handle.history.now;
      _require(
        loaded == ownership.revision &&
            history.revision == loaded &&
            history.status == sync.ValueStatus.ready &&
            history.data != null,
      );
      _sync(
        await _runtime.withBitcoinRevisionAdmission(key, (revision) async {
          _require(revision == loaded);
          if (request != null) {
            _sync(
              await _authority.closeNeverPrepared(
                expected: request,
                admittedRevision: revision,
              ),
            );
          } else {
            // Positive confirmed settlement takes precedence over local expiry.
            _sync(
              await _authority.observe(
                key,
                history,
                admittedRevision: revision,
              ),
            );
            if ((expiredUnsigned &&
                    _sync(
                      await _authority.expiredUnsignedBoardReview(
                        operationId,
                        DateTime.now().toUtc(),
                      ),
                    )) ||
                (unregistered &&
                    _sync(
                      await _authority.unregisteredNeverSignedBoard(
                        operationId,
                      ),
                    ))) {
              // The CAS loses to every irreversible signing-start, including a
              // signer that has not yet persisted its signed bytes.
              _sync(
                await _authority.tombstoneNeverSigned(
                  expected: binding,
                  admittedRevision: revision,
                ),
              );
            }
          }
        }),
      );
      return const Ok(null);
    } catch (error) {
      if (error is Error) rethrow;
      return Err(_failure(error));
    }
  });

  /// Settles this account's unfinished Board, if any: a confirmed funding is
  /// recorded, and a reservation that can no longer be signed gives its coins
  /// back. Run by the host on startup and resume, never mid-preparation.
  Future<Result<void, ArkFailure>> reconcilePending(
    ArkAccountId account,
  ) async {
    if (_preparing.contains(account)) return const Ok(null);
    final String? pending;
    switch (await _authority.pendingForAccount(account.canonical)) {
      case Ok(:final value):
        pending = value;
      case Err():
        return const Err(ArkFeatureStorageFailure());
    }
    if (pending == null) return const Ok(null);
    // Signed but never broadcast: finish it, then settle as usual.
    if (await _authority.readBoardReview(pending) case Ok(
      value: ArkBoardJournalEntry(phase: 'signed' || 'broadcasting'),
    )) {
      await deliverSigned(account, pending);
    }
    return reconcileSource(pending);
  }

  /// Current provider, tip, config and price still match [review]. A
  /// signed Board resumed later skips only the quote's own lifetime
  /// ([quoteLifetime] false): it is priced afresh here and must match.
  Future<void> _fresh(_Review review, {bool quoteLifetime = true}) async {
    if (quoteLifetime) _unexpired(review);
    if (review.boardEvidence case final evidence?) {
      final fresh = _ark(
        await _client.quote(
          review.account,
          ArkQuoteRequest.board(
            amount: review.display.fundingAmount,
            anchor: ArkBoardChainAnchor(
              height: review.observedTip,
              hash: evidence.tipHash,
            ),
          ),
        ),
      );
      final observed = fresh.boardEvidence;
      _require(
        fresh.account == review.account &&
            fresh.kind == ArkOperationKind.board &&
            fresh.validUntil.isAfter(DateTime.now().toUtc()) &&
            fresh.observedTip >= review.observedTip &&
            (fresh.observedTip != review.observedTip ||
                observed?.tipHash == evidence.tipHash) &&
            observed?.serverKey == evidence.serverKey &&
            observed?.requiredConfirmations == evidence.requiredConfirmations &&
            _sameBoardTerms(fresh, review),
      );
      if (review.display.expiryHeight - fresh.observedTip < 6) {
        throw const _HostFailure(ArkReviewExpiredFailure());
      }
      _packageOperation(_ark(await _client.read(review.account)), review);
      if (quoteLifetime) _unexpired(review);
      return;
    }
    final pass = _ark(await _client.synchronize(review.account, renew: false));
    final snapshot = pass.snapshot;
    final tip = snapshot.tipHeight;
    final age = DateTime.now().toUtc().difference(snapshot.observedAt);
    _require(
      !age.isNegative &&
          pass.failedStages.isEmpty &&
          !snapshot.stale &&
          tip != null &&
          snapshot.account == review.account &&
          DateTime.now().toUtc().difference(snapshot.observedAt) <=
              const Duration(seconds: 15),
    );
    if (tip == null || review.display.expiryHeight - tip < 6) {
      throw const _HostFailure(ArkReviewExpiredFailure());
    }
    _require(
      snapshot.usingFallback
          ? review.display.chainSource.toString() == review._request['fallback']
          : review.display.chainSource.toString() == review._request['primary'],
    );
    _packageOperation(snapshot, review);
    // Native quote reads current provider/config/fees. Never rebuild funding.
    final fresh = _ark(
      await _client.quote(
        review.account,
        ArkQuoteRequest.board(amount: review.display.fundingAmount),
      ),
    );
    _require(_sameBoardTerms(fresh, review));
    if (quoteLifetime) _unexpired(review);
  }

  bool _sameBoardTerms(ArkQuote fresh, _Review review) =>
      fresh.chainSource == review.display.chainSource &&
      fresh.configGeneration == review.display.configGeneration &&
      fresh.fee == review.display.arkFee &&
      fresh.net == review.display.net &&
      fresh.amount == review.display.fundingAmount;

  ArkOperation _packageOperation(ArkSnapshot snapshot, _Review review) {
    final matches = snapshot.operations
        .where((op) => op.id == review.entry.binding.operationId)
        .toList();
    _require(matches.length == 1);
    final operation = matches.single, funding = operation.boardFunding;
    _require(
      operation.kind == ArkOperationKind.board &&
          operation.status != ArkOperationStatus.outcomeUnknown &&
          operation.status != ArkOperationStatus.failed &&
          operation.status != ArkOperationStatus.conflicted &&
          operation.chainSource == review.display.chainSource &&
          operation.configGeneration == review.display.configGeneration &&
          operation.nativeReference == review.entry.binding.unsignedTxid &&
          funding != null,
    );
    if (funding == null) {
      throw const _HostFailure(ArkServiceUnavailableFailure());
    }
    final token = funding.scuttleToken;
    _require(
      funding.address == review.address &&
          funding.keypairIndex == review.keypairIndex &&
          (token == null ? null : _fundingTokenDigest(token)) ==
              review.scuttleTokenDigest &&
          funding.expiryHeight == review.display.expiryHeight,
    );
    return operation;
  }

  /// The native revision checks that follow a prepare decide on a stale source.
  /// A reconcile must not read the journal from a source it could not refresh,
  /// so it surfaces the refresh failure through [_sync] instead.
  Future<Result<void, sync.SyncFailure>> _refreshSource(
    WalletRegistration metadata,
  ) async {
    final refreshed = await _sourceSync(
      sync.WalletKey(id: metadata.id, network: metadata.network),
    );
    if (refreshed case Err(:final failure)) {
      log.warning('Ark Board source sync failed: ${failure.runtimeType}');
    }
    return refreshed;
  }

  Future<WalletRegistration> _eligible(
    String walletId, {
    ArkFundingBinding? expected,
  }) async {
    final metadata = _secret(await _inventory.readWallet(walletId));
    // The legacy source checked account zero in the wallet ID. The public
    // descriptor path must also identify account zero before signing.
    final idOrigin = RegExp(r'\[[a-fA-F0-9]+/84h/\d+h/0h\]');
    final path = metadata.derivationPath;
    final accountPath = RegExp(r"^m/84[hH']/\d+[hH']/0[hH']$");
    _require(
      metadata.id == walletId &&
          metadata.network == BitcoinNetwork.regtest &&
          metadata.signer == WalletSigner.local &&
          metadata.isDefault &&
          metadata.scriptType == ScriptType.bip84 &&
          idOrigin.hasMatch(metadata.id) &&
          path != null &&
          accountPath.hasMatch(path) &&
          metadata.secretFingerprint != null,
    );
    if (expected != null) {
      _require(
        metadata.id == expected.key.id &&
            metadata.network == expected.key.network &&
            expected.key.network == BitcoinNetwork.regtest &&
            metadata.secretFingerprint == expected.sourceParent,
      );
    }
    return metadata;
  }

  static void _checkOutputs(
    sync.BitcoinPsbtFacts facts,
    String target,
    Sats amount,
    sync.OwnershipIndex ownership,
  ) {
    int targets = 0;
    for (final output in facts.outputs) {
      final address = sync.bitcoinScriptAddress(
        output.scriptPubkey,
        BitcoinNetwork.regtest,
      );
      if (address case Ok(:final value) when value == target) {
        _require(output.valueSat == amount.value.toInt());
        targets++;
      } else {
        _require(ownership.ownsScript(Uint8List.fromList(output.scriptPubkey)));
      }
    }
    _require(
      targets == 1 && facts.finalTransaction == null && facts.feeSat >= 0,
    );
  }

  static void _unexpired(_Review review) {
    if (!DateTime.now().toUtc().isBefore(review.display.validUntil)) {
      throw const _HostFailure(ArkReviewExpiredFailure());
    }
  }

  Future<Result<T, ArkFailure>> _track<T>(
    Future<Result<T, ArkFailure>> Function() run,
  ) {
    if (_closed) return Future.value(const Err(ArkServiceUnavailableFailure()));
    final future = run();
    late final Future<void> tracked;
    tracked = future
        .then<void>((_) {}, onError: (Object error, StackTrace stack) {})
        .whenComplete(() => _requests.remove(tracked));
    _requests.add(tracked);
    return future;
  }

  Future<void> close() async {
    _closed = true;
    while (_requests.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_requests));
    }
  }

  static String _id() {
    final random = Random.secure();
    return 'ark-board-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
  }

  static void _require(bool condition) {
    if (!condition) throw const _HostFailure(ArkInvalidRequestFailure());
  }

  static T _sync<T>(Result<T, sync.SyncFailure> value) => switch (value) {
    Ok(:final value) => value,
    Err(failure: sync.SyncBusyFailure()) => throw const _HostFailure(
      ArkOperationBusyFailure(),
    ),
    Err(failure: sync.SyncStorageFailure()) => throw const _HostFailure(
      ArkFeatureStorageFailure(),
    ),
    Err() => throw const _HostFailure(ArkServiceUnavailableFailure()),
  };
  static T _ark<T>(Result<T, ArkWalletFailure> value) => switch (value) {
    Ok(:final value) => value,
    Err(failure: ArkOutcomeUnknownFailure(:final operationId)) =>
      throw _HostFailure(ArkSubmissionUncertainFailure(operationId)),
    Err(failure: ArkInsufficientFundsFailure()) => throw const _HostFailure(
      ArkPaymentInsufficientFundsFailure(),
    ),
    Err(failure: ArkStaleQuoteFailure()) => throw const _HostFailure(
      ArkReviewExpiredFailure(),
    ),
    Err(failure: ArkWriterBusyFailure()) => throw const _HostFailure(
      ArkOperationBusyFailure(),
    ),
    Err(
      failure: ArkValidationFailure(
        reason: ArkFailureReason.belowMinimum,
        minimum: final minimum?,
      ),
    )
        when minimum.value > BigInt.zero =>
      throw _HostFailure(ArkBoardBelowMinimumFailure(minimum)),
    Err() => throw const _HostFailure(ArkServiceUnavailableFailure()),
  };
  static T _secret<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => throw const _HostFailure(ArkAccountRecoveryFailure()),
  };
  static ArkFailure _failure(Object error) => switch (error) {
    _HostFailure(:final failure) => failure,
    _ => const ArkServiceUnavailableFailure(),
  };
}

final class _HostFailure implements Exception {
  final ArkFailure failure;
  const _HostFailure(this.failure);
}

String _fundingTokenDigest(String token) =>
    sha256.convert(utf8.encode(token)).toString();

final class _Review {
  final ArkBoardJournalEntry entry;
  final ArkAccountId account;
  late final Map<String, dynamic> _payload = _map(jsonDecode(entry.payload));
  late final Map<String, dynamic> _request = _map(
    jsonDecode(entry.binding.context),
  );
  late final String address = _text(_payload['address']);
  late final int? keypairIndex = _payload.containsKey('keypairIndex')
      ? _number(_payload['keypairIndex'])
      : null;
  late final String? scuttleTokenDigest =
      _payload.containsKey('scuttleTokenDigest')
      ? _text(_payload['scuttleTokenDigest'])
      : null;
  late final int observedTip = _number(_request['observedTip']);
  late final ArkBoardQuoteEvidence? boardEvidence = _request['version'] == 2
      ? ArkBoardQuoteEvidence(
          serverKey: _text(_request['serverKey']),
          tipHash: _text(_request['tipHash']),
          requiredConfirmations: _number(_request['requiredConfirmations']),
        )
      : null;
  late final ArkBoardPreparation display = _display();

  _Review(this.entry, this.account);

  ArkBoardPreparation _display() {
    final version = _request['version'];
    final digest = scuttleTokenDigest;
    if (entry.binding.accountIdentity != account.canonical ||
        _payload['request'] != entry.binding.context ||
        version is! int ||
        (version != 1 && version != 2) ||
        (version == 1 && (keypairIndex == null || digest != null)) ||
        (version == 2 &&
            (keypairIndex != null ||
                digest == null ||
                !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest))) ||
        _request['account'] != account.canonical ||
        account.network != BitcoinNetwork.regtest) {
      throw const FormatException('Board review scope');
    }
    final facts = WalletArkBoardFunding._sync(
      sync.inspectBitcoinPsbt(entry.binding.unsignedPsbt),
    );
    final fee = _number(_payload['minerFee']);
    if (facts.unsignedTxid != entry.binding.unsignedTxid ||
        facts.feeSat != fee ||
        entry.binding.key.network != account.network ||
        facts.finalTransaction != null) {
      throw const FormatException('Board review facts');
    }
    final amount = _amount(_request['amount']),
        arkFee = _amount(_request['arkFee']),
        net = _amount(_request['net']);
    if (amount.value != arkFee.value + net.value ||
        net.value <= BigInt.zero ||
        _number(_request['fastSatPerKwu']) == 0) {
      throw const FormatException('Board quote amounts');
    }
    return ArkBoardPreparation(
      operationId: entry.binding.operationId,
      reviewBinding: sha256
          .convert(
            utf8.encode('${entry.binding.unsignedPsbt}\n${entry.payload}'),
          )
          .toString(),
      account: account,
      sourceWalletId: entry.binding.key.id,
      sourceParent: entry.binding.sourceParent,
      sourceGeneration: entry.binding.revision.generation,
      fundingAmount: _amount(_request['amount']),
      minerFee: Sats.fromInt(fee),
      arkFee: _amount(_request['arkFee']),
      net: _amount(_request['net']),
      feeRate: FeeRate(_number(_request['fastSatPerKwu']) / 250),
      unsignedTxid: entry.binding.unsignedTxid,
      expiryHeight: _number(_payload['expiryHeight']),
      validUntil: DateTime.parse(_text(_request['validUntil'])).toUtc(),
      chainSource: Uri.parse(_text(_request['chainSource'])),
      configGeneration: _number(_request['configGeneration']),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Board object');
    }
    return value;
  }

  static String _text(Object? value) {
    if (value is! String || value.isEmpty) {
      throw const FormatException('Board text');
    }
    return value;
  }

  static int _number(Object? value) {
    if (value is! int || value < 0) throw const FormatException('Board number');
    return value;
  }

  static Sats _amount(Object? value) {
    final amount = BigInt.tryParse(_text(value));
    if (amount == null ||
        amount < BigInt.zero ||
        amount > BigInt.from(2100000000000000)) {
      throw const FormatException('Board amount');
    }
    return Sats(amount);
  }
}
