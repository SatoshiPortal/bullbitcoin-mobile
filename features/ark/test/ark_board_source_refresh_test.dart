import 'dart:async';

import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_display_data_usecase.dart';
import 'package:bull_ark/src/domain/usecases/refresh_ark_board_source_usecase.dart';
import 'package:bull_ark/src/presentation/ark_display_data_cubit.dart';
import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_board_amount_screen_test.dart' show edit, review;
import 'ark_information_widget_test.dart' show app, config;
import 'ark_operations_test.dart' show account;

class _Source implements ArkBoardSourcePort {
  final updates = StreamController<void>.broadcast(sync: true);
  final replies = <Completer<Result<ArkDisplayData, ArkFailure>>>[];
  ArkDisplayData? published;
  bool active = true;
  @override
  Stream<void> changes(ArkAccountId account) => updates.stream;
  @override
  bool accepts(ArkDisplayData value) => active && identical(value, published);
  @override
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account) async {
    final value = published;
    return value == null
        ? const Err(ArkServiceUnavailableFailure())
        : Ok(value);
  }

  @override
  Future<Result<ArkDisplayData, ArkFailure>> refresh(ArkAccountId account) {
    published = null;
    final reply = Completer<Result<ArkDisplayData, ArkFailure>>();
    replies.add(reply);
    return reply.future;
  }

  void complete(Sats? amount) {
    final value = ArkDisplayData(
      account: account(),
      walletId: 'source',
      available: amount,
    );
    published = value;
    replies.last.complete(Ok(value));
  }
}

void main() {
  late _Source source;
  late ArkDisplayDataCubit cubit;
  setUp(() {
    source = _Source();
    cubit = ArkDisplayDataCubit(
      ReadArkDisplayDataUsecase(source),
      account: account(),
      refresh: RefreshArkBoardSourceUsecase(source),
    );
  });
  tearDown(() async {
    await cubit.close();
    await source.updates.close();
  });

  test('only explicit refresh scans; coalesced passive changes do not retire its result', () async {
    await cubit.load();
    expect(source.replies, isEmpty);
    expect(cubit.state, isA<ArkDisplayDataUnavailable>());
    final first = cubit.refreshSource();
    expect(cubit.refreshSource(), same(first));
    source.updates.add(null);
    source.updates.add(null);
    source.complete(Sats.fromInt(100000));
    await first;
    await Future<void>.delayed(Duration.zero);
    expect(source.replies, hasLength(1));
    final value = (cubit.state as ArkDisplayDataReady).source;
    expect(value.available, Sats.fromInt(100000));
    expect(cubit.accepts(value), isTrue);
    await cubit.load();
    expect(source.replies, hasLength(1));
    source.active = false;
    expect(
      cubit.accepts(value),
      isFalse,
      reason: 'Reject a stale callback before rebuild',
    );
  });

  test(
    'failed scan is retryable; successful but unavailable balance is distinct',
    () async {
      var running = cubit.refreshSource();
      source.replies.last.complete(const Err(ArkServiceUnavailableFailure()));
      await running;
      expect(cubit.state, isA<ArkDisplayDataUnavailable>());
      running = cubit.refreshSource();
      source.complete(null);
      await running;
      final value = (cubit.state as ArkDisplayDataReady).source;
      expect(value.available, isNull);
      expect(cubit.accepts(value), isTrue);
      running = cubit.refreshSource();
      expect(cubit.accepts(value), isFalse);
      source.complete(Sats.zero);
      await running;
      expect((cubit.state as ArkDisplayDataReady).source.available, Sats.zero);
    },
  );

  testWidgets(
    'a funded frame callback refuses invalidated source before rebuild',
    (tester) async {
      var ready = true;
      var submitted = 0;
      final accountConfig = config();
      ArkBoardAmountScreen form() => ArkBoardAmountScreen(
        config: accountConfig,
        sourceReady: () => ready,
        displayData: ArkDisplayData(
          account: account(),
          walletId: 'source',
          available: Sats.fromInt(100000),
        ),
        onReviewRequest: (_, _) => submitted++,
      );
      await tester.pumpWidget(app(form()));
      await edit(tester, '20000');
      final stale = review(tester);
      expect(stale.disabled, isFalse);
      ready = false;
      stale.onPressed();
      expect(submitted, 0);
      await tester.pumpWidget(app(form()));
      expect(review(tester).disabled, isTrue);
      ready = true;
      await tester.pumpWidget(
        app(
          ArkBoardAmountScreen(
            config: config(),
            sourceReady: () => ready,
            displayData: ArkDisplayData(
              account: account(),
              walletId: 'source',
              available: Sats.zero,
            ),
            onReviewRequest: (_, _) => submitted++,
          ),
        ),
      );
      await edit(tester, '1');
      expect(review(tester).disabled, isTrue);
      review(tester).onPressed();
      expect(submitted, 0);
    },
  );
}
