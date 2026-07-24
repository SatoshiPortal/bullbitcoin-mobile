import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
// ignore: unused_import
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

/// Floor for `usedScriptIndex` on a CBF recovery scan when a wallet's own
/// [WalletMetadataModel.lastReceiveAddressIndex] is smaller — including the
/// common case of an import that never recorded one (index 0). This is a
/// conservative default, not a measured value: an imported wallet has not
/// had a chance to have its true usage tracked yet, so recovery must scan
/// wide enough to find funds at addresses Bull itself never indexed.
const cbfMinimumRecoveryUsedScriptIndex = 100;

/// Resolves the `bdk.ScanType` a CBF session should start with for a given
/// wallet, based on its already-persisted [WalletMetadataModel] and the
/// already-loaded `bdk.Wallet`'s own local chain tip. Injected into
/// `CbfWalletDatasource` (see `cbf_wallet_datasource.dart`) as its own
/// seam: the selection below is a plain function of its inputs — no FFI
/// session, no native call beyond building the returned `bdk.ScanType`
/// value itself — so it can be unit tested without a fake session or any
/// of the FFI-heavy machinery the default session factory needs.
///
/// Only [bdk.SyncScanType] and [bdk.RecoveryScanType] are ever returned;
/// no other `bdk.ScanType` variant is constructed here.
abstract interface class CbfScanTypeResolver {
  /// [walletLatestCheckpointHeight] is the height of `wallet
  /// .latestCheckpoint()` for the already-built `bdk.Wallet` this session
  /// is about to scan with — the caller's only source for whether that
  /// wallet's own local chain has ever had a real `Update` applied (see
  /// [DefaultCbfScanTypeResolver] for why this, not just [metadata]'s
  /// `syncedAt`, is what this resolver actually keys its choice on).
  bdk.ScanType resolve(
    WalletMetadataModel metadata, {
    required int walletLatestCheckpointHeight,
  });
}

/// The default [CbfScanTypeResolver]:
///
/// * A wallet whose already-loaded `bdk.Wallet` has a real local chain tip
///   past genesis (`walletLatestCheckpointHeight > 0` — some `Update` has
///   actually been applied, Electrum today or a previous CBF session) uses
///   [bdk.SyncScanType]. Verified against the pinned dependency chain
///   (`bdk_dart` `1.0.0-rc.3` / `bdk-ffi` `17c48b8b` / `bdk_kyoto` `0.17.0`):
///   `bdk.SyncScanType` lowers to `bdk_kyoto::ScanType::Sync`, which
///   `BuilderExt::build_with_wallet` (`bdk_kyoto-0.17.0/src/builder.rs:90-93`)
///   resolves to `wallet.latest_checkpoint()` — the BDK wallet's own
///   already-persisted local chain tip, nothing this resolver constructs.
/// * Every other case — a wallet with no real local chain tip yet
///   (`walletLatestCheckpointHeight == 0`, `bdk_wallet` `3.0.0`'s
///   `Wallet::create_with_params` seeds a fresh chain via
///   `LocalChain::from_genesis_hash`, `bdk_wallet-3.0.0/src/wallet/mod.rs:321`)
///   — uses [bdk.RecoveryScanType], anchored at [WalletMetadataModel]'s own
///   persisted [WalletBirthdayCheckpoint] (`metadata.birthdayCheckpoint`):
///   a verified `(height, hash)` pair lowered to a
///   `bdk.OtherRecoveryPoint(bdk.BlockId(...))`. This covers both the
///   ordinary first-sync case (`metadata.syncedAt == null`, so the local
///   chain is genesis because no sync has ever completed) and the
///   otherwise-anomalous case of `syncedAt` already set but the local BDK
///   state missing anyway (e.g. the wallet's sqlite db was lost or never
///   restored) — in both, only the persisted checkpoint, never `syncedAt`
///   alone, decides whether recovery is safe to start from something
///   other than genesis.
///
/// A wallet with no persisted [WalletBirthdayCheckpoint] in the second case
/// above throws [CbfMissingBirthdayCheckpointException] rather than falling
/// back to any guessed recovery point: there is no trusted source in that
/// situation to resolve a scan start point without one, and guessing a
/// script-type-based default (e.g. segwit activation, or genesis) would be
/// a fund-safety risk, not a convenience — see
/// `docs/compact-block-filters-technical-design.md` §4.
///
/// Turning `birthday` into a verified `bdk.RecoveryPoint.other` `BlockId`
/// requires both a height *and* a hash — `BlockId` is expressible (see
/// `OtherRecoveryPoint`/`BlockId` in the pinned `bdk_dart`), but only once
/// something upstream of this resolver has actually resolved and persisted
/// that pair as [WalletMetadataModel.birthdayCheckpoint]; this resolver
/// itself never derives one from a raw `birthday` timestamp.
class DefaultCbfScanTypeResolver implements CbfScanTypeResolver {
  const DefaultCbfScanTypeResolver();

  @override
  bdk.ScanType resolve(
    WalletMetadataModel metadata, {
    required int walletLatestCheckpointHeight,
  }) {
    if (metadata.syncedAt != null && walletLatestCheckpointHeight > 0) {
      return bdk.SyncScanType();
    }

    final checkpoint = metadata.birthdayCheckpoint;
    if (checkpoint == null) {
      throw CbfMissingBirthdayCheckpointException(metadata.id);
    }

    final storedIndex = metadata.lastReceiveAddressIndex;
    final usedScriptIndex = storedIndex > cbfMinimumRecoveryUsedScriptIndex
        ? storedIndex
        : cbfMinimumRecoveryUsedScriptIndex;

    return bdk.RecoveryScanType(
      usedScriptIndex: usedScriptIndex,
      checkpoint: bdk.OtherRecoveryPoint(
        bdk.BlockId(
          height: checkpoint.blockHeight,
          hash: bdk.BlockHash.fromString(hex: checkpoint.blockHash),
        ),
      ),
    );
  }
}

/// Thrown by [DefaultCbfScanTypeResolver.resolve] when a CBF session would
/// otherwise need to start a recovery scan (no established local BDK chain
/// tip) but [WalletMetadataModel.birthdayCheckpoint] is unset for this
/// wallet. Deliberately not swallowed or guessed around here: it propagates
/// out of the `CbfNativeSessionFactory` call in
/// `CbfWalletDatasource._runLocked`, which already catches any exception
/// from that call and turns it into a `WalletSyncCbfFailure` — so this
/// becomes an ordinary, typed sync failure rather than an unhandled
/// exception or a silently-wrong scan.
class CbfMissingBirthdayCheckpointException extends BullException {
  CbfMissingBirthdayCheckpointException(String walletId)
    : super(
        'CBF recovery scan requires a persisted birthday checkpoint for '
        'wallet $walletId, but none is stored',
      );
}
