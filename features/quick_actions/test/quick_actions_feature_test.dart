import 'dart:async';

import 'package:bull_quick_actions/bull_quick_actions.dart';
import 'package:bull_quick_actions/setup.dart';
import 'package:flutter_test/flutter_test.dart';

const _choices = 'quick_actions';
const _dismissal = 'quick_actions_exchange_prompt_dismissed';

final class _Storage implements QuickActionsStorage {
  final reads = <String>[];
  Completer<String?>? pendingDismissal;

  @override
  Future<String?> read(String key) async {
    reads.add(key);
    if (key == _dismissal) return pendingDismissal?.future;
    return null;
  }

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> remove(String key) async {}
}

final class _Source {
  var creations = 0;
  var listens = 0;
  var cancels = 0;
  late final events = StreamController<bool>.broadcast(
    onListen: () => listens++,
    onCancel: () => cancels++,
  );

  Stream<bool> create() {
    creations++;
    return events.stream;
  }

  (int, int, int) get counts => (creations, listens, cancels);
}

void main() {
  late _Storage storage;
  late _Source trading;
  late _Source entry;
  late _Source offered;
  late QuickActionsFeature owner;

  setUp(() {
    storage = _Storage();
    trading = _Source();
    entry = _Source();
    offered = _Source();
    owner = QuickActionsFeature.mount(
      storage: storage,
      isIOS: true,
      warning: (_) {},
      exchangeVisible: trading.create,
      exchangeEntry: entry.create,
      exchangeOffered: offered.create,
    );
  });

  tearDown(() async {
    await owner.close();
    await Future.wait([
      trading.events.close(),
      entry.events.close(),
      offered.events.close(),
    ]);
  });

  for (final (choices, prompt) in [
    (false, false),
    (true, false),
    (false, true),
    (true, true),
  ]) {
    test(
      'closes only instantiated cubits (choices: $choices, prompt: $prompt)',
      () async {
        expect(trading.counts, (0, 0, 0));
        expect(entry.counts, (0, 0, 0));
        expect(offered.counts, (0, 0, 0));
        expect(storage.reads, isEmpty);

        final actions = choices ? owner.quickActions : null;
        final exchangePrompt = prompt ? owner.exchangePrompt : null;
        if (actions != null) {
          expect(actions, same(owner.quickActions));
          expect(actions.state.defaults, QuickActionsLayout.iosDefaults);
        }
        if (exchangePrompt != null) {
          expect(exchangePrompt, same(owner.exchangePrompt));
        }
        expect(storage.reads, [if (prompt) _dismissal]);
        final closed = owner.close();
        expect(owner.close(), same(closed));
        await closed;

        expect(trading.counts, choices ? (1, 1, 1) : (0, 0, 0));
        expect(entry.counts, choices ? (1, 1, 1) : (0, 0, 0));
        expect(offered.counts, prompt ? (1, 1, 1) : (0, 0, 0));
        expect(actions?.isClosed, choices ? true : null);
        expect(exchangePrompt?.isClosed, prompt ? true : null);
        expect(() => owner.quickActions, throwsStateError);
        expect(() => owner.exchangePrompt, throwsStateError);
      },
    );
  }

  test(
    'preload reads choices once after visibility without creating the prompt',
    () async {
      final pending = owner.preload();
      expect(storage.reads, isEmpty);
      expect(trading.counts, (1, 1, 0));
      expect(entry.counts, (1, 1, 0));
      expect(offered.counts, (0, 0, 0));
      trading.events.add(false);
      await pending;
      await owner.quickActions.load();
      expect(owner.quickActions.state.initialized, isTrue);
      expect(storage.reads, [_choices]);
      expect(offered.counts, (0, 0, 0));
    },
  );

  test(
    'closing a preload suspended on visibility does not read choices',
    () async {
      final pending = owner.preload();
      expect(trading.counts, (1, 1, 0));
      expect(storage.reads, isEmpty);
      await owner.close();
      await pending;
      trading.events.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(storage.reads, isEmpty);
      expect(trading.counts, (1, 1, 1));
      expect(entry.counts, (1, 1, 1));
      expect(offered.counts, (0, 0, 0));
    },
  );

  for (final closeBeforeRead in [false, true]) {
    test('late prompt restoration (closed: $closeBeforeRead)', () async {
      final pending = Completer<String?>();
      storage.pendingDismissal = pending;
      final prompt = owner.exchangePrompt;
      final states = <bool>[];
      final subscription = prompt.stream.listen(states.add);
      offered.events.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(prompt.state, isFalse);
      expect(states, everyElement(isFalse));
      if (closeBeforeRead) await owner.close();
      pending.complete(null);
      await Future<void>.delayed(Duration.zero);
      expect(prompt.state, !closeBeforeRead);
      if (closeBeforeRead) expect(states, everyElement(isFalse));
      expect(storage.reads, [_dismissal]);
      expect(trading.counts, (0, 0, 0));
      expect(entry.counts, (0, 0, 0));
      await subscription.cancel();
    });
  }
}
