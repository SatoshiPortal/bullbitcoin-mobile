import 'dart:async';

import 'package:ark/ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_account_screen_test.dart' show Client, controller;

void main() {
  test('a refresh asked during another runs once more after it', () async {
    final client = Client();
    final first = Completer<Result<ArkPassOutcome, ArkWalletFailure>>();
    client.passReply = first;
    final cubit = controller(client);
    final running = cubit.refresh();
    await Future<void>.delayed(Duration.zero);
    unawaited(cubit.refresh());
    unawaited(cubit.refresh());
    expect(client.calls.where((c) => c == 'sync'), hasLength(1));
    final second = Completer<Result<ArkPassOutcome, ArkWalletFailure>>();
    client.passReply = second;
    first.complete(const Err(ArkUnavailableFailure()));
    await Future<void>.delayed(Duration.zero);
    expect(client.calls.where((c) => c == 'sync'), hasLength(2));
    second.complete(const Err(ArkUnavailableFailure()));
    await running;
    expect(client.calls.where((c) => c == 'sync'), hasLength(2));
  });
}
