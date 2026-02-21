import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/swaps/data/models/swap_model.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:boltz/boltz.dart' as boltz;

class ManualSwapStatusResetUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  ManualSwapStatusResetUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<
      ({
        Swap? swap,
        int? nextReverseIndex,
        int? nextChainIndex,
        int? nextSubmarineIndex,
      })> execute(String swapId) async {
    try {
      final id = swapId.trim();
      if (id.isEmpty) {
        return (
          swap: null,
          nextReverseIndex: null,
          nextChainIndex: null,
          nextSubmarineIndex: null,
        );
      }

      log.fine('Rescue: Starting rescue for swap $id');

      final settings = await _settingsRepository.fetch();
      final repository = settings.environment.isTestnet
          ? _testnetRepository
          : _mainnetRepository;

      final existing = await repository.fetchSwapModel(id);
      if (existing != null &&
          (existing.status == SwapStatus.paid.name ||
              existing.status == SwapStatus.pending.name)) {
        log.fine(
          'Rescue: Swap $id already exists in SQLite with status paid or pending, skipping',
        );
        return (
          swap: existing.toEntity(),
          nextReverseIndex: null,
          nextChainIndex: null,
          nextSubmarineIndex: null,
        );
      }
      if (existing != null) {
        log.fine(
          'Rescue: Swap $id exists in SQLite with status: ${existing.status}, updating status to paid and clearing completionTime',
        );
        final swap = existing.toEntity();
        final updated = swap.copyWith(
          status: SwapStatus.paid,
          completionTime: null,
        );
        await repository.updateSwap(swap: updated);
        log.fine('Rescue: Updated swap $id in SQLite');
        return (
          swap: updated,
          nextReverseIndex: null,
          nextChainIndex: null,
          nextSubmarineIndex: null,
        );
      }

      log.fine('Rescue: Swap $id not found in SQLite, trying secure storage');
      final secureStorageSwap =
          await repository.tryFetchSwapFromSecureStorage(id);
      if (secureStorageSwap != null) {
        await _recreateFromSecureStorage(
          repository: repository,
          secureStorageSwap: secureStorageSwap,
          isTestnet: settings.environment.isTestnet,
          environment: settings.environment,
        );
        final model = await repository.fetchSwapModel(id);
        return (
          swap: model?.toEntity(),
          nextReverseIndex: null,
          nextChainIndex: null,
          nextSubmarineIndex: null,
        );
      }
      log.fine('Rescue: Swap $id not found in secure storage');
      final indices = await repository.getNextSwapIndices();
      return (
        swap: null,
        nextReverseIndex: indices.nextReverse,
        nextChainIndex: indices.nextChain,
        nextSubmarineIndex: indices.nextSubmarine,
      );
    } catch (e, stackTrace) {
      log.severe(
        'Rescue: Failed to rescue swap $swapId',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _recreateFromSecureStorage({
    required BoltzSwapRepository repository,
    required Object secureStorageSwap,
    required bool isTestnet,
    required Environment environment,
  }) async {
    if (secureStorageSwap is boltz.LbtcLnSwap) {
      await _recreateLbtcLnSwap(
        repository: repository,
        lbtcLnSwap: secureStorageSwap,
        isTestnet: isTestnet,
        environment: environment,
      );
    } else if (secureStorageSwap is boltz.BtcLnSwap) {
      await _recreateBtcLnSwap(
        repository: repository,
        btcLnSwap: secureStorageSwap,
        isTestnet: isTestnet,
        environment: environment,
      );
    } else if (secureStorageSwap is boltz.ChainSwap) {
      await _recreateChainSwap(
        repository: repository,
        chainSwap: secureStorageSwap,
        isTestnet: isTestnet,
        environment: environment,
      );
    }
  }

  Future<void> _recreateLbtcLnSwap({
    required BoltzSwapRepository repository,
    required boltz.LbtcLnSwap lbtcLnSwap,
    required bool isTestnet,
    required Environment environment,
  }) async {
    final liquidWallets = await _walletRepository.getWallets(
      environment: environment,
      onlyLiquid: true,
      onlyDefaults: true,
    );
    if (liquidWallets.isEmpty) {
      log.warning('Rescue: No liquid wallet found for LbtcLnSwap');
      return;
    }
    if (lbtcLnSwap.kind == boltz.SwapType.submarine) {
      final swapModel = SwapModel.lnSend(
        id: lbtcLnSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.liquidToLightning.name,
        isTestnet: isTestnet,
        keyIndex: lbtcLnSwap.keyIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: liquidWallets.first.id,
        invoice: lbtcLnSwap.invoice,
        paymentAddress: lbtcLnSwap.scriptAddress,
        paymentAmount: lbtcLnSwap.outAmount.toInt(),
      );
      await repository.updateSwap(swap: swapModel.toEntity());
      log.fine('Rescue: Recreated LbtcLnSwap ${lbtcLnSwap.id} in SQLite');
    } else {
      final swapModel = SwapModel.lnReceive(
        id: lbtcLnSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.lightningToLiquid.name,
        isTestnet: isTestnet,
        keyIndex: lbtcLnSwap.keyIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        receiveWalletId: liquidWallets.first.id,
        invoice: lbtcLnSwap.invoice,
      );
      await repository.updateSwap(swap: swapModel.toEntity());
      log.fine(
        'Rescue: Recreated LbtcLnSwap reverse ${lbtcLnSwap.id} in SQLite',
      );
    }
  }

  Future<void> _recreateBtcLnSwap({
    required BoltzSwapRepository repository,
    required boltz.BtcLnSwap btcLnSwap,
    required bool isTestnet,
    required Environment environment,
  }) async {
    final bitcoinWallets = await _walletRepository.getWallets(
      environment: environment,
      onlyLiquid: false,
      onlyDefaults: true,
    );
    final btcWallets = bitcoinWallets.where((w) => w.isBitcoin).toList();
    if (btcWallets.isEmpty) {
      log.warning('Rescue: No bitcoin wallet found for BtcLnSwap');
      return;
    }
    if (btcLnSwap.kind == boltz.SwapType.submarine) {
      final swapModel = SwapModel.lnSend(
        id: btcLnSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.bitcoinToLightning.name,
        isTestnet: isTestnet,
        keyIndex: btcLnSwap.keyIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: btcWallets.first.id,
        invoice: btcLnSwap.invoice,
        paymentAddress: btcLnSwap.scriptAddress,
        paymentAmount: btcLnSwap.outAmount.toInt(),
      );
      await repository.updateSwap(swap: swapModel.toEntity());
      log.fine('Rescue: Recreated BtcLnSwap ${btcLnSwap.id} in SQLite');
    } else {
      final swapModel = SwapModel.lnReceive(
        id: btcLnSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.lightningToBitcoin.name,
        isTestnet: isTestnet,
        keyIndex: btcLnSwap.keyIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        receiveWalletId: btcWallets.first.id,
        invoice: btcLnSwap.invoice,
      );
      await repository.updateSwap(swap: swapModel.toEntity());
      log.fine('Rescue: Recreated BtcLnSwap reverse ${btcLnSwap.id} in SQLite');
    }
  }

  Future<void> _recreateChainSwap({
    required BoltzSwapRepository repository,
    required boltz.ChainSwap chainSwap,
    required bool isTestnet,
    required Environment environment,
  }) async {
    final liquidWallets = await _walletRepository.getWallets(
      environment: environment,
      onlyLiquid: true,
      onlyDefaults: true,
    );
    final bitcoinWallets = await _walletRepository.getWallets(
      environment: environment,
      onlyLiquid: false,
      onlyDefaults: true,
    );
    final btcWallets = bitcoinWallets.where((w) => w.isBitcoin).toList();
    if (liquidWallets.isEmpty || btcWallets.isEmpty) {
      log.warning('Rescue: Need both liquid and bitcoin wallets for ChainSwap');
      return;
    }
    if (chainSwap.direction == boltz.ChainSwapDirection.lbtcToBtc) {
      final swapModel = SwapModel.chain(
        id: chainSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.liquidToBitcoin.name,
        isTestnet: isTestnet,
        keyIndex: chainSwap.claimIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: liquidWallets.first.id,
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveWalletId: btcWallets.first.id,
      );
      await repository.updateSwap(swap: swapModel.toEntity());
    } else {
      final swapModel = SwapModel.chain(
        id: chainSwap.id,
        status: SwapStatus.paid.name,
        type: SwapType.bitcoinToLiquid.name,
        isTestnet: isTestnet,
        keyIndex: chainSwap.claimIndex.toInt(),
        creationTime: DateTime.now().millisecondsSinceEpoch,
        sendWalletId: btcWallets.first.id,
        paymentAddress: chainSwap.scriptAddress,
        paymentAmount: chainSwap.outAmount.toInt(),
        receiveWalletId: liquidWallets.first.id,
      );
      await repository.updateSwap(swap: swapModel.toEntity());
    }
    log.fine('Rescue: Recreated ChainSwap ${chainSwap.id} in SQLite');
  }
}
