import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swaps_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'swap_rescue_cubit.freezed.dart';
part 'swap_rescue_state.dart';

class SwapRescueCubit extends Cubit<SwapRescueState> {
  SwapRescueCubit({
    required GetSwapsUsecase getSwapsUsecase,
    required GetReceiveAddressUsecase getReceiveAddressUsecase,
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required SettingsRepository settingsRepository,
  })  : _getSwapsUsecase = getSwapsUsecase,
        _getReceiveAddressUsecase = getReceiveAddressUsecase,
        _mainnetRepo = mainnetBoltzSwapRepository,
        _testnetRepo = testnetBoltzSwapRepository,
        _settingsRepository = settingsRepository,
        super(const SwapRescueState());

  final GetSwapsUsecase _getSwapsUsecase;
  final GetReceiveAddressUsecase _getReceiveAddressUsecase;
  final BoltzSwapRepository _mainnetRepo;
  final BoltzSwapRepository _testnetRepo;
  final SettingsRepository _settingsRepository;

  Future<BoltzSwapRepository> _repo() async {
    final settings = await _settingsRepository.fetch();
    return settings.environment.isTestnet ? _testnetRepo : _mainnetRepo;
  }

  Future<void> loadSwaps() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final swaps = await _getSwapsUsecase.execute();
      swaps.sort((a, b) => _creationTime(b).compareTo(_creationTime(a)));
      emit(state.copyWith(swaps: swaps, loading: false));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> markCompleted(String swapId) async {
    emit(state.copyWith(actionLoading: true, error: null, successMessage: null));
    try {
      final repo = await _repo();
      final swap = await repo.getSwap(swapId: swapId);
      final updated = switch (swap) {
        LnReceiveSwap() => swap.copyWith(
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        ),
        LnSendSwap() => swap.copyWith(
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        ),
        ChainSwap() => swap.copyWith(
          status: SwapStatus.completed,
          completionTime: DateTime.now(),
        ),
      };
      await repo.updateSwap(swap: updated);
      final updatedList =
          state.swaps.map((s) => s.id == swapId ? updated : s).toList();
      emit(
        state.copyWith(
          swaps: updatedList,
          actionLoading: false,
          successMessage: 'Swap marked as completed',
        ),
      );
    } catch (e) {
      emit(state.copyWith(actionLoading: false, error: e.toString()));
    }
  }

  Future<void> updateClaimAddress(String swapId, String walletId) async {
    emit(state.copyWith(actionLoading: true, error: null, successMessage: null));
    try {
      final repo = await _repo();
      final swap = await repo.getSwap(swapId: swapId);

      if (swap is LnSendSwap) {
        throw Exception(
          'Lightning Send Swaps do not support claim address updates',
        );
      }

      final walletAddress = await _getReceiveAddressUsecase.execute(
        walletId: walletId,
      );
      final address = walletAddress.address;

      final updated = switch (swap) {
        LnReceiveSwap() => swap.copyWith(receiveAddress: address),
        ChainSwap() => swap.copyWith(receiveAddress: address),
        LnSendSwap() => throw Exception(
          'Lightning Send Swaps do not support claim address updates',
        ),
      };
      await repo.updateSwap(swap: updated);

      final updatedList =
          state.swaps.map((s) => s.id == swapId ? updated : s).toList();
      emit(
        state.copyWith(
          swaps: updatedList,
          actionLoading: false,
          successMessage: 'Claim address updated',
        ),
      );
    } catch (e) {
      emit(state.copyWith(actionLoading: false, error: e.toString()));
    }
  }

  Future<void> updateRefundAddress(String swapId, String walletId) async {
    emit(state.copyWith(actionLoading: true, error: null, successMessage: null));
    try {
      final repo = await _repo();
      final swap = await repo.getSwap(swapId: swapId);

      if (swap is LnReceiveSwap) {
        throw Exception(
          'Lightning Receive Swaps do not have refund addresses',
        );
      }

      final walletAddress = await _getReceiveAddressUsecase.execute(
        walletId: walletId,
      );
      final address = walletAddress.address;

      final updated = switch (swap) {
        LnSendSwap() => swap.copyWith(refundAddress: address),
        ChainSwap() => swap.copyWith(refundAddress: address),
        LnReceiveSwap() => throw Exception(
          'Lightning Receive Swaps do not have refund addresses',
        ),
      };
      await repo.updateSwap(swap: updated);

      final updatedList =
          state.swaps.map((s) => s.id == swapId ? updated : s).toList();
      emit(
        state.copyWith(
          swaps: updatedList,
          actionLoading: false,
          successMessage: 'Refund address updated',
        ),
      );
    } catch (e) {
      emit(state.copyWith(actionLoading: false, error: e.toString()));
    }
  }

  DateTime _creationTime(Swap swap) => switch (swap) {
    LnReceiveSwap(:final creationTime) => creationTime,
    LnSendSwap(:final creationTime) => creationTime,
    ChainSwap(:final creationTime) => creationTime,
  };

  bool claimIsLiquid(Swap swap) {
    return switch (swap) {
      LnReceiveSwap(:final type) => type == SwapType.lightningToLiquid,
      ChainSwap(:final type) => type == SwapType.bitcoinToLiquid,
      LnSendSwap() => throw Exception(
        'Lightning Send Swaps do not support claim address updates',
      ),
    };
  }

  bool refundIsLiquid(Swap swap) {
    return switch (swap) {
      LnSendSwap(:final type) => type == SwapType.liquidToLightning,
      ChainSwap(:final type) => type == SwapType.liquidToBitcoin,
      LnReceiveSwap() => throw Exception(
        'Lightning Receive Swaps do not have refund addresses',
      ),
    };
  }

  List<Wallet> walletsForClaim(Swap swap, List<Wallet> allWallets) {
    final isLiquid = claimIsLiquid(swap);
    return allWallets
        .where(
          (w) =>
              (isLiquid ? w.isLiquid : w.isBitcoin) &&
              w.isTestnet == swap.environment.isTestnet,
        )
        .toList();
  }

  List<Wallet> walletsForRefund(Swap swap, List<Wallet> allWallets) {
    final isLiquid = refundIsLiquid(swap);
    return allWallets
        .where(
          (w) =>
              (isLiquid ? w.isLiquid : w.isBitcoin) &&
              w.isTestnet == swap.environment.isTestnet,
        )
        .toList();
  }
}
