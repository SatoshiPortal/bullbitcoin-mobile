import 'dart:async';

import 'package:bb_mobile/core/fees/domain/fee_preview_cache.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_plan.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_quote.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/broadcast_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_own_change_addresses_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_sweep_display_settings_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/parse_sweep_address_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/preview_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/sign_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_cubit.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../coins/wallet_utxo_fixture.dart';

class _MockGetFees extends Mock implements GetSweepFeesUsecase {}

class _MockParseAddress extends Mock implements ParseSweepAddressUsecase {}

class _MockBuildPsbt extends Mock implements BuildSweepPsbtUsecase {}

class _MockSignPsbt extends Mock implements SignSweepPsbtUsecase {}

class _MockBroadcast extends Mock implements BroadcastSweepPsbtUsecase {}

class _MockGetWallet extends Mock implements GetWalletUsecase {}

class _MockPreviewFees extends Mock implements PreviewSweepFeesUsecase {}

class _MockGetOwnChangeAddresses extends Mock
    implements GetOwnChangeAddressesUsecase {}

class _MockGetDisplaySettings extends Mock
    implements GetSweepDisplaySettingsUsecase {}

const _alice = 'tb1qalice000000000000000000000000000000000';
const _bob = 'tb1qbob00000000000000000000000000000000000';

void main() {
  late _MockGetFees getFees;
  late _MockParseAddress parseAddress;
  late _MockBuildPsbt buildPsbt;
  late _MockSignPsbt signPsbt;
  late _MockBroadcast broadcast;
  late _MockGetWallet getWallet;
  late _MockPreviewFees previewFees;
  late _MockGetOwnChangeAddresses getOwnChangeAddresses;
  late _MockGetDisplaySettings getDisplaySettings;

  // 60 000 + 40 000 = 100 000 sats of selected coins.
  final inputs = <WalletUtxo>[
    walletUtxoFixture(sats: 60000, txId: 'a', vout: 0),
    walletUtxoFixture(sats: 40000, txId: 'b', vout: 1),
  ];

  final presets = FeeOptions(
    fastest: NetworkFee.relativeFromSatPerVbyte(10),
    economic: NetworkFee.relativeFromSatPerVbyte(4),
    slow: NetworkFee.relativeFromSatPerVbyte(1),
    minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
  );

  SweepCubit buildCubit() => SweepCubit(
    walletId: 'wallet-1',
    network: Network.bitcoinTestnet,
    inputs: inputs,
    getSweepFeesUsecase: getFees,
    previewSweepFeesUsecase: previewFees,
    parseSweepAddressUsecase: parseAddress,
    getOwnChangeAddressesUsecase: getOwnChangeAddresses,
    buildSweepPsbtUsecase: buildPsbt,
    signSweepPsbtUsecase: signPsbt,
    broadcastSweepPsbtUsecase: broadcast,
    getWalletUsecase: getWallet,
    getSweepDisplaySettingsUsecase: getDisplaySettings,
  );

  SweepQuote quoteOf(SweepPlan plan) => SweepQuote(
    plan: plan,
    networkFee: presets.economic,
    unsignedPsbt: 'unsigned',
    txSize: 220,
    feeSat: BigInt.from(440),
  );

  void stubFeesOk() {
    when(
      () => getFees.execute(),
    ).thenAnswer((_) async => Ok<FeeOptions, SweepFailure>(presets));
  }

  /// Address parsing behaves as the identity for a well-formed address.
  void stubParsePassthrough() {
    when(
      () => parseAddress.execute(
        input: any(named: 'input'),
        network: any(named: 'network'),
      ),
    ).thenAnswer((invocation) async {
      final input = invocation.namedArguments[const Symbol('input')] as String;
      return Ok<ParsedSweepAddress, SweepFailure>((
        address: input.trim(),
        amountSat: null,
      ));
    });
  }

  void stubBuildOk() {
    when(
      () => buildPsbt.execute(
        walletId: any(named: 'walletId'),
        plan: any(named: 'plan'),
        networkFee: any(named: 'networkFee'),
        floorSatPerKwu: any(named: 'floorSatPerKwu'),
      ),
    ).thenAnswer((invocation) async {
      final plan = invocation.namedArguments[const Symbol('plan')] as SweepPlan;
      return Ok<SweepQuote, SweepFailure>(quoteOf(plan));
    });
  }

  void stubSignOk() {
    when(
      () => signPsbt.execute(
        walletId: any(named: 'walletId'),
        unsignedPsbt: any(named: 'unsignedPsbt'),
        floorSatPerKwu: any(named: 'floorSatPerKwu'),
      ),
    ).thenAnswer((_) async => const Ok<String, SweepFailure>('signed'));
  }

  void stubBroadcastOk() {
    when(
      () => broadcast.execute(signedPsbt: any(named: 'signedPsbt')),
    ).thenAnswer((_) async => const Ok<String, SweepFailure>('txid-1'));
    when(
      () => getWallet.execute(any(), sync: any(named: 'sync')),
    ).thenAnswer((_) async => null);
  }

  /// Drives the cubit to a built quote sitting on the review step.
  Future<SweepCubit> reviewing() async {
    stubFeesOk();
    stubParsePassthrough();
    stubBuildOk();
    final cubit = buildCubit();
    await cubit.init();
    cubit
      ..addressChanged(0, _alice)
      ..amountChanged(0, BigInt.from(25000));
    await cubit.review();
    return cubit;
  }

  setUpAll(() {
    registerFallbackValue(Network.bitcoinTestnet);
    registerFallbackValue(NetworkFee.absolute(0));
    final samplePlan = SweepPlan.validate(
      inputs: inputs,
      allocations: [
        SweepAllocation(address: _alice, amountSat: BigInt.from(1000)),
      ],
    );
    registerFallbackValue((samplePlan as Ok<SweepPlan, SweepFailure>).value);
  });

  setUp(() {
    getFees = _MockGetFees();
    parseAddress = _MockParseAddress();
    buildPsbt = _MockBuildPsbt();
    signPsbt = _MockSignPsbt();
    broadcast = _MockBroadcast();
    getWallet = _MockGetWallet();
    previewFees = _MockPreviewFees();
    getOwnChangeAddresses = _MockGetOwnChangeAddresses();
    getDisplaySettings = _MockGetDisplaySettings();

    // init() also loads decoration (fiat hint, own change addresses). Neither
    // blocks the flow, so every test stubs them as unavailable unless it cares.
    when(
      () => getOwnChangeAddresses.execute(
        walletId: any(named: 'walletId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const Ok<List<WalletAddress>, SweepFailure>([]));
    when(() => getDisplaySettings.execute()).thenAnswer(
      (_) async => const Err<SweepDisplaySettings, SweepFailure>(
        SweepUnexpectedFailure(),
      ),
    );
  });

  group('initial state', () {
    test('starts on the allocation step with one empty row', () {
      final cubit = buildCubit();

      expect(cubit.state.step, SweepStep.allocate);
      expect(cubit.state.allocations, [const SweepAllocation(address: '')]);
      expect(cubit.state.totalInputSat, BigInt.from(100000));
      expect(cubit.state.canReview, isFalse);

      cubit.close();
    });
  });

  group('loadFees', () {
    test(
      'loads display preferences without exposing Settings internals',
      () async {
        stubFeesOk();
        when(() => getDisplaySettings.execute()).thenAnswer(
          (_) async => const Ok<SweepDisplaySettings, SweepFailure>(
            SweepDisplaySettings(
              bitcoinUnit: BitcoinUnit.sats,
              hideAmounts: false,
              exchangeRate: 42000,
              fiatCurrencyCode: 'CAD',
            ),
          ),
        );
        final cubit = buildCubit();

        await cubit.init();

        expect(cubit.state.bitcoinUnit, BitcoinUnit.sats);
        expect(cubit.state.hideAmounts, isFalse);
        expect(cubit.state.exchangeRate, 42000);
        expect(cubit.state.fiatCurrencyCode, 'CAD');
        await cubit.close();
      },
    );

    test('stores the presets', () async {
      stubFeesOk();
      final cubit = buildCubit();

      await cubit.init();

      expect(cubit.state.feePresets, presets);
      expect(cubit.state.loadingFees, isFalse);
      expect(cubit.state.selectedFee, presets.economic);
      await cubit.close();
    });

    test('surfaces a fee failure', () async {
      when(() => getFees.execute()).thenAnswer(
        (_) async =>
            const Err<FeeOptions, SweepFailure>(SweepFeesUnavailableFailure()),
      );
      final cubit = buildCubit();

      await cubit.init();

      expect(cubit.state.failure, isA<SweepFeesUnavailableFailure>());
      expect(cubit.state.loadingFees, isFalse);
      await cubit.close();
    });
  });

  group('allocation form', () {
    test('addRecipient appends an empty row', () async {
      final cubit = buildCubit()..addRecipient();

      expect(cubit.state.allocations.length, 2);
      await cubit.close();
    });

    test('removeRecipient never empties the form', () async {
      final cubit = buildCubit()..removeRecipient(0);

      expect(cubit.state.allocations.length, 1);
      await cubit.close();
    });

    test('an out-of-range index is ignored', () async {
      final cubit = buildCubit()..addressChanged(5, _alice);

      expect(cubit.state.allocations.single.address, isEmpty);
      await cubit.close();
    });

    test('amountChanged feeds the running totals', () async {
      final cubit = buildCubit()..amountChanged(0, BigInt.from(25000));

      expect(cubit.state.allocatedSat, BigInt.from(25000));
      expect(cubit.state.unallocatedSat, BigInt.from(75000));
      expect(cubit.state.isOverAllocated, isFalse);
      await cubit.close();
    });

    test('takeRemainder is exclusive and clears that row amount', () async {
      final cubit = buildCubit()
        ..addRecipient()
        ..amountChanged(0, BigInt.from(10000))
        ..takeRemainder(0)
        ..takeRemainder(1);

      expect(cubit.state.allocations[0].takesRemainder, isFalse);
      expect(cubit.state.allocations[1].takesRemainder, isTrue);
      expect(cubit.state.allocations[1].amountSat, isNull);
      expect(cubit.state.hasRemainderRow, isTrue);
      await cubit.close();
    });

    test('typing an amount takes the row off remainder duty', () async {
      final cubit = buildCubit()
        ..takeRemainder(0)
        ..amountChanged(0, BigInt.from(5000));

      expect(cubit.state.allocations[0].takesRemainder, isFalse);
      expect(cubit.state.allocations[0].amountSat, BigInt.from(5000));
      await cubit.close();
    });

    test('releaseRemainder gives the rest back to the wallet', () async {
      final cubit = buildCubit()
        ..takeRemainder(0)
        ..releaseRemainder(0);

      expect(cubit.state.hasRemainderRow, isFalse);
      await cubit.close();
    });

    test('over-allocating is detected and blocks review', () async {
      stubFeesOk();
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        ..amountChanged(0, BigInt.from(100001));

      expect(cubit.state.isOverAllocated, isTrue);
      expect(cubit.state.canReview, isFalse);
      await cubit.close();
    });

    test('canReview needs an address, an amount and a fee', () async {
      stubFeesOk();
      final cubit = buildCubit();

      cubit
        ..addressChanged(0, _alice)
        ..amountChanged(0, BigInt.from(25000));
      // No fee loaded yet.
      expect(cubit.state.canReview, isFalse);

      await cubit.init();
      expect(cubit.state.canReview, isTrue);

      await cubit.close();
    });

    test('a remainder row needs no amount to be reviewable', () async {
      stubFeesOk();
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        ..takeRemainder(0);

      expect(cubit.state.canReview, isTrue);
      await cubit.close();
    });
  });

  group('fee selection on the review step', () {
    test('re-prices at the newly picked rate instead of dropping', () async {
      final cubit = await reviewing();
      expect(cubit.state.quote, isNotNull);

      await cubit.feeOptionSelected(FeeSelection.fastest);

      expect(cubit.state.selectedFeeOption, FeeSelection.fastest);
      expect(cubit.state.quote, isNotNull);
      expect(cubit.state.step, SweepStep.review);
      verify(
        () => buildPsbt.execute(
          walletId: 'wallet-1',
          plan: any(named: 'plan'),
          networkFee: presets.fastest,
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).called(1);
      await cubit.close();
    });

    test('reuses a cached build rather than rebuilding', () async {
      final cubit = await reviewing();

      // review() built and cached the economic slot; fastest builds once; going
      // back to economic must come from the cache. Three selections, two builds.
      await cubit.feeOptionSelected(FeeSelection.fastest);
      await cubit.feeOptionSelected(FeeSelection.economic);

      verify(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).called(2);
      expect(cubit.state.selectedFeeOption, FeeSelection.economic);
      await cubit.close();
    });

    test('only the latest concurrent fee build can stage a psbt', () async {
      final cubit = await reviewing();
      final plan = cubit.state.quote!.plan;
      final fastest = Completer<Result<SweepQuote, SweepFailure>>();
      final slow = Completer<Result<SweepQuote, SweepFailure>>();
      reset(buildPsbt);
      when(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).thenAnswer((invocation) {
        final fee = invocation.namedArguments[const Symbol('networkFee')];
        return fee == presets.fastest ? fastest.future : slow.future;
      });

      final first = cubit.feeOptionSelected(FeeSelection.fastest);
      final second = cubit.feeOptionSelected(FeeSelection.slow);
      slow.complete(
        Ok(
          SweepQuote(
            plan: plan,
            networkFee: presets.slow,
            unsignedPsbt: 'slow-psbt',
            txSize: 210,
            feeSat: BigInt.from(210),
          ),
        ),
      );
      await second;
      fastest.complete(
        Ok(
          SweepQuote(
            plan: plan,
            networkFee: presets.fastest,
            unsignedPsbt: 'fast-psbt',
            txSize: 210,
            feeSat: BigInt.from(2100),
          ),
        ),
      );
      await first;

      expect(cubit.state.selectedFeeOption, FeeSelection.slow);
      expect(cubit.state.quote?.unsignedPsbt, 'slow-psbt');
      await cubit.close();
    });

    test('a failed reprice keeps the last reviewed fee and psbt', () async {
      final cubit = await reviewing();
      when(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: presets.fastest,
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).thenAnswer(
        (_) async => const Err<SweepQuote, SweepFailure>(SweepBuildFailure()),
      );

      await cubit.feeOptionSelected(FeeSelection.fastest);

      expect(cubit.state.selectedFeeOption, FeeSelection.economic);
      expect(cubit.state.quote?.unsignedPsbt, 'unsigned');
      expect(cubit.state.failure, isA<SweepBuildFailure>());
      await cubit.close();
    });

    test('arming a custom rate keeps a rollback target', () async {
      final cubit = await reviewing();

      cubit.armCustomFee(NetworkFee.relativeFromSatPerVbyte(7));

      expect(cubit.state.selectedFeeOption, FeeSelection.custom);
      expect(cubit.state.armPriorSelection, FeeSelection.economic);
      // The custom slot must be cleared: it would otherwise price the old rate.
      expect(
        cubit.state.feePreviewCache.slotFor(FeeSelection.custom).isCacheReady,
        isFalse,
      );
      await cubit.close();
    });

    test('disarming restores the previous selection', () async {
      final cubit = await reviewing();
      cubit.armCustomFee(NetworkFee.relativeFromSatPerVbyte(7));

      cubit.disarmCustomFee();

      expect(cubit.state.selectedFeeOption, FeeSelection.economic);
      expect(cubit.state.armPriorSelection, isNull);
      await cubit.close();
    });

    test('accepts a sub-1 sat/vB rate above the relay floor', () async {
      // Nothing in the flow may assume whole sat/vB: 0.2 is 50 sat/kwu, exactly
      // representable, and clears the 0.1 floor the presets carry.
      final cubit = await reviewing();
      final subOne = NetworkFee.relativeFromSatPerVbyte(0.2);
      cubit.armCustomFee(subOne);

      cubit.finalizeArmedCustomFee();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.failure, isNull);
      expect(cubit.state.selectedFeeOption, FeeSelection.custom);
      verify(
        () => buildPsbt.execute(
          walletId: 'wallet-1',
          plan: any(named: 'plan'),
          networkFee: subOne,
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a below-floor rate rolls back and is reported', () async {
      final cubit = await reviewing();
      // 0.01 sat/vB is under the 0.1 relay floor carried by the presets.
      cubit.armCustomFee(NetworkFee.relativeFromSatPerVbyte(0.01));

      cubit.finalizeArmedCustomFee();

      expect(cubit.state.selectedFeeOption, FeeSelection.economic);
      expect(cubit.state.failure, isA<SweepFeeTooLowFailure>());
      await cubit.close();
    });

    test('an invalid edit restores the prior custom rate', () async {
      final cubit = await reviewing();
      final prior = NetworkFee.relativeFromSatPerVbyte(2);
      cubit.armCustomFee(prior);
      cubit.finalizeArmedCustomFee();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.selectedFeeOption, FeeSelection.custom);

      cubit.armCustomFee(NetworkFee.relativeFromSatPerVbyte(0.01));
      cubit.finalizeArmedCustomFee();

      expect(cubit.state.selectedFeeOption, FeeSelection.custom);
      expect(cubit.state.customFee, prior);
      await cubit.close();
    });

    test('an acceptable rate is committed on dismissal', () async {
      final cubit = await reviewing();
      cubit.armCustomFee(NetworkFee.relativeFromSatPerVbyte(7));

      cubit.finalizeArmedCustomFee();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.selectedFeeOption, FeeSelection.custom);
      expect(cubit.state.failure, isNull);
      verify(
        () => buildPsbt.execute(
          walletId: 'wallet-1',
          plan: any(named: 'plan'),
          networkFee: NetworkFee.relativeFromSatPerVbyte(7),
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).called(1);
      await cubit.close();
    });
  });

  group('quote invalidation', () {
    test('editing a recipient drops a built quote', () async {
      final cubit = await reviewing();

      cubit.addressChanged(0, _bob);

      expect(cubit.state.quote, isNull);
      await cubit.close();
    });

    test('editing while review builds cancels the stale result', () async {
      stubFeesOk();
      final parsed = Completer<Result<ParsedSweepAddress, SweepFailure>>();
      when(
        () => parseAddress.execute(
          input: any(named: 'input'),
          network: any(named: 'network'),
        ),
      ).thenAnswer((_) => parsed.future);
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        ..amountChanged(0, BigInt.from(25000));

      final review = cubit.review();
      expect(cubit.state.building, isTrue);
      cubit.addressChanged(0, _bob);
      expect(cubit.state.building, isFalse);
      parsed.complete(
        const Ok<ParsedSweepAddress, SweepFailure>((
          address: _alice,
          amountSat: null,
        )),
      );
      await review;

      expect(cubit.state.quote, isNull);
      expect(cubit.state.allocations.single.address, _bob);
      verifyNever(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      );
      await cubit.close();
    });

    test(
      'a preview from an abandoned plan cannot repopulate the cache',
      () async {
        final cubit = await reviewing();
        final preview = Completer<BitcoinFeePreviewSlot>();
        when(
          () => previewFees.one(
            walletId: any(named: 'walletId'),
            plan: any(named: 'plan'),
            networkFee: any(named: 'networkFee'),
            floorSatPerKwu: any(named: 'floorSatPerKwu'),
          ),
        ).thenAnswer((_) => preview.future);

        unawaited(
          cubit.previewCustomFee(NetworkFee.relativeFromSatPerVbyte(3)),
        );
        await Future<void>.delayed(const Duration(milliseconds: 650));
        cubit.backToAllocation();
        preview.complete(
          const BitcoinFeePreviewSlot(
            feeSat: 600,
            unsignedPsbt: 'stale-psbt',
            txSize: 200,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.feePreviewCache.slotFor(FeeSelection.custom).isCacheReady,
          isFalse,
        );
        await cubit.close();
      },
    );
  });

  group('review', () {
    test('refuses without a fee', () async {
      final cubit = buildCubit();

      await cubit.review();

      expect(cubit.state.failure, isA<SweepFeesUnavailableFailure>());
      expect(cubit.state.step, SweepStep.allocate);
      await cubit.close();
    });

    test('surfaces an invalid address without building', () async {
      stubFeesOk();
      when(
        () => parseAddress.execute(
          input: any(named: 'input'),
          network: any(named: 'network'),
        ),
      ).thenAnswer(
        (_) async => const Err<ParsedSweepAddress, SweepFailure>(
          SweepInvalidAddressFailure('nope'),
        ),
      );
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, 'nope')
        ..amountChanged(0, BigInt.from(25000));

      await cubit.review();

      expect(cubit.state.failure, isA<SweepInvalidAddressFailure>());
      expect(cubit.state.step, SweepStep.allocate);
      expect(cubit.state.building, isFalse);
      verifyNever(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      );
      await cubit.close();
    });

    test('surfaces a plan rule without building', () async {
      stubFeesOk();
      stubParsePassthrough();
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        // Every satoshi allocated — nothing left for the fee.
        ..amountChanged(0, BigInt.from(100000));

      await cubit.review();

      expect(cubit.state.failure, isA<SweepNoRoomForFeeFailure>());
      expect(cubit.state.step, SweepStep.allocate);
      verifyNever(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      );
      await cubit.close();
    });

    test('moves to review with the built quote', () async {
      final cubit = await reviewing();

      expect(cubit.state.step, SweepStep.review);
      expect(cubit.state.quote?.feeSat, BigInt.from(440));
      expect(cubit.state.quote?.txSize, 220);
      expect(cubit.state.building, isFalse);
      await cubit.close();
    });

    test('builds with the fee currently selected', () async {
      stubFeesOk();
      stubParsePassthrough();
      stubBuildOk();
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        ..amountChanged(0, BigInt.from(25000))
        ..feeOptionSelected(FeeSelection.fastest);

      await cubit.review();

      verify(
        () => buildPsbt.execute(
          walletId: 'wallet-1',
          plan: any(named: 'plan'),
          networkFee: presets.fastest,
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a build failure keeps the user on the form', () async {
      stubFeesOk();
      stubParsePassthrough();
      when(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).thenAnswer(
        (_) async => Err<SweepQuote, SweepFailure>(
          SweepInsufficientFundsFailure(BigInt.from(120)),
        ),
      );
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, _alice)
        ..amountChanged(0, BigInt.from(99900));

      await cubit.review();

      expect(cubit.state.step, SweepStep.allocate);
      expect(cubit.state.failure, isA<SweepInsufficientFundsFailure>());
      expect(cubit.state.quote, isNull);
      await cubit.close();
    });

    test('a BIP21 amount prefills an empty row', () async {
      stubFeesOk();
      stubBuildOk();
      when(
        () => parseAddress.execute(
          input: any(named: 'input'),
          network: any(named: 'network'),
        ),
      ).thenAnswer(
        (_) async => Ok<ParsedSweepAddress, SweepFailure>((
          address: _alice,
          amountSat: BigInt.from(12345),
        )),
      );
      final cubit = buildCubit();
      await cubit.init();
      cubit.addressChanged(0, 'bitcoin:$_alice?amount=0.00012345');

      await cubit.review();

      expect(cubit.state.allocations.single.address, _alice);
      expect(cubit.state.allocations.single.amountSat, BigInt.from(12345));
      expect(cubit.state.step, SweepStep.review);
      await cubit.close();
    });

    test('a typed amount wins over the one carried by a BIP21 uri', () async {
      stubFeesOk();
      stubBuildOk();
      when(
        () => parseAddress.execute(
          input: any(named: 'input'),
          network: any(named: 'network'),
        ),
      ).thenAnswer(
        (_) async => Ok<ParsedSweepAddress, SweepFailure>((
          address: _alice,
          amountSat: BigInt.from(12345),
        )),
      );
      final cubit = buildCubit();
      await cubit.init();
      cubit
        ..addressChanged(0, 'bitcoin:$_alice?amount=0.00012345')
        ..amountChanged(0, BigInt.from(30000));

      await cubit.review();

      expect(cubit.state.allocations.single.amountSat, BigInt.from(30000));
      await cubit.close();
    });
  });

  group('confirm', () {
    test('does not sign while a replacement fee psbt is building', () async {
      final cubit = await reviewing();
      final replacement = Completer<Result<SweepQuote, SweepFailure>>();
      reset(buildPsbt);
      when(
        () => buildPsbt.execute(
          walletId: any(named: 'walletId'),
          plan: any(named: 'plan'),
          networkFee: any(named: 'networkFee'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).thenAnswer((_) => replacement.future);

      final reprice = cubit.feeOptionSelected(FeeSelection.fastest);
      expect(cubit.state.building, isTrue);
      await cubit.confirm();

      verifyNever(
        () => signPsbt.execute(
          walletId: any(named: 'walletId'),
          unsignedPsbt: any(named: 'unsignedPsbt'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      );
      replacement.complete(
        Ok(
          SweepQuote(
            plan: cubit.state.quote!.plan,
            networkFee: presets.fastest,
            unsignedPsbt: 'replacement',
            txSize: 200,
            feeSat: BigInt.from(2000),
          ),
        ),
      );
      await reprice;
      await cubit.close();
    });

    test('signs, broadcasts and lands on success', () async {
      final cubit = await reviewing();
      stubSignOk();
      stubBroadcastOk();

      await cubit.confirm();

      expect(cubit.state.txId, 'txid-1');
      expect(cubit.state.step, SweepStep.success);
      expect(cubit.state.broadcasting, isFalse);
      verify(() => broadcast.execute(signedPsbt: 'signed')).called(1);
      // The wallet is pulled forward so the coin list reflects the spend.
      verify(() => getWallet.execute('wallet-1', sync: true)).called(1);
      await cubit.close();
    });

    test('signs the psbt that was reviewed', () async {
      final cubit = await reviewing();
      stubSignOk();
      stubBroadcastOk();

      await cubit.confirm();

      verify(
        () => signPsbt.execute(
          walletId: 'wallet-1',
          unsignedPsbt: 'unsigned',
          floorSatPerKwu: presets.minRelay.satPerKwu,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a signing failure never reaches broadcast', () async {
      final cubit = await reviewing();
      when(
        () => signPsbt.execute(
          walletId: any(named: 'walletId'),
          unsignedPsbt: any(named: 'unsignedPsbt'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).thenAnswer(
        (_) async => const Err<String, SweepFailure>(SweepSignFailure()),
      );

      await cubit.confirm();

      expect(cubit.state.failure, isA<SweepSignFailure>());
      expect(cubit.state.step, SweepStep.review);
      expect(cubit.state.broadcasting, isFalse);
      verifyNever(
        () => broadcast.execute(signedPsbt: any(named: 'signedPsbt')),
      );
      await cubit.close();
    });

    test('a broadcast failure keeps the review step and no txid', () async {
      final cubit = await reviewing();
      stubSignOk();
      when(
        () => broadcast.execute(signedPsbt: any(named: 'signedPsbt')),
      ).thenAnswer(
        (_) async => const Err<String, SweepFailure>(SweepBroadcastFailure()),
      );

      await cubit.confirm();

      expect(cubit.state.failure, isA<SweepBroadcastFailure>());
      expect(cubit.state.step, SweepStep.review);
      expect(cubit.state.txId, isNull);
      await cubit.close();
    });

    test('refuses to broadcast the same sweep twice', () async {
      final cubit = await reviewing();
      stubSignOk();
      stubBroadcastOk();

      await cubit.confirm();
      await cubit.confirm();

      verify(
        () => signPsbt.execute(
          walletId: any(named: 'walletId'),
          unsignedPsbt: any(named: 'unsignedPsbt'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      ).called(1);
      verify(
        () => broadcast.execute(signedPsbt: any(named: 'signedPsbt')),
      ).called(1);
      await cubit.close();
    });

    test('refuses to confirm without a quote', () async {
      final cubit = buildCubit();

      await cubit.confirm();

      expect(cubit.state.failure, isA<SweepBuildFailure>());
      verifyNever(
        () => signPsbt.execute(
          walletId: any(named: 'walletId'),
          unsignedPsbt: any(named: 'unsignedPsbt'),
          floorSatPerKwu: any(named: 'floorSatPerKwu'),
        ),
      );
      await cubit.close();
    });
  });

  group('navigation and failures', () {
    test('backToAllocation drops the quote', () async {
      final cubit = await reviewing();

      cubit.backToAllocation();

      expect(cubit.state.step, SweepStep.allocate);
      expect(cubit.state.quote, isNull);
      await cubit.close();
    });

    test('clearFailure clears a shown failure', () async {
      final cubit = buildCubit();
      await cubit.review(); // fails: no fee
      expect(cubit.state.failure, isNotNull);

      cubit.clearFailure();

      expect(cubit.state.failure, isNull);
      await cubit.close();
    });
  });
}
