import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/background_wallet_storage_guard.dart';

/// Headless sync can open admitted descriptors without seed or PIN access.
void main() {
  group('background tasks stay out of the keystore', () {
    test('the task set contains only wallet sync, Ark maintenance and legacy tasks', () {
      expect(
        BackgroundTask.values.map((t) => t.name),
        unorderedEquals([
          'wallets-sync',
          'ark-renewal',
          'bitcoin-sync',
          'liquid-sync',
          'swaps-sync',
          'logs-prune',
        ]),
      );
    });

    test('the handler reaches no secret-mutating use case', () {
