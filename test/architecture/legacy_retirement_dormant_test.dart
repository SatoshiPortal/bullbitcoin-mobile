import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// No destructive entry point exists in WS5a. Activation requires a separate
// reviewed change, including the recovery provenance contract.

/// The only `retire` method outside the dormant storage retirement revokes a
/// payment admission attempt for this process; it touches no storage. The
/// destructive retirement takes a `LegacyRetirementActivation`, so it is never
/// a no-argument call on an attempt.
const _attemptType = 'PayinWalletAttempt';

/// Names declared in a unit with the process-local attempt type, as variables,
/// fields or regular parameters. A receiver this cannot resolve fails closed:
/// it stays an offender.
class _AttemptReceivers extends RecursiveAstVisitor<void> {
  final names = <String>{};

  void _add(TypeAnnotation? type, String? name) {
    final declared = type?.toSource().replaceAll('?', '').split('.').last;
    if (declared != _attemptType || name == null) return;
    names.add(name);
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    for (final variable in node.variables) {
      _add(node.type, variable.name.lexeme);
    }
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitRegularFormalParameter(RegularFormalParameter node) {
    _add(node.type, node.name?.lexeme);
    super.visitRegularFormalParameter(node);
  }
}

/// `retire` invocations the dormant guard must reject.
class _RetireCalls extends RecursiveAstVisitor<void> {
  _RetireCalls(this.attemptNames);

  final Set<String> attemptNames;
  final found = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'retire') {
      final target = node.target;
      final revocation =
          target is SimpleIdentifier &&
          attemptNames.contains(target.name) &&
          node.argumentList.arguments.isEmpty;
      if (!revocation) found.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// `retire` invocations in [content] that are not the payment attempt's
/// process-local revocation, reported as `path:line: source`.
Iterable<String> _destructiveRetires(String path, String content) sync* {
  if (!content.contains('retire')) return;
  final parsed = parseString(
    content: content,
    path: path,
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    // An unparseable source still fails closed on the raw text.
    if (RegExp(r'\.retire\s*\(').hasMatch(content)) yield path;
    return;
  }
  final attempts = _AttemptReceivers();
  parsed.unit.accept(attempts);
  final calls = _RetireCalls(attempts.names);
  parsed.unit.accept(calls);
  for (final call in calls.found) {
    final line = parsed.unit.lineInfo.getLocation(call.offset).lineNumber;
    yield '$path:$line: ${call.toSource().split('\n').first}';
  }
}

void main() {
  final roots = ['lib', 'packages', 'features'];

  Iterable<File> sources() sync* {
    for (final root in roots) {
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final parts = p.split(entity.path);
        if (parts.contains('test') ||
            parts.contains('.dart_tool') ||
            parts.contains('build')) {
          continue;
        }
        yield entity;
      }
    }
  }

  test('the retirement implementation has no destructive operations', () {
    final files = [
      'packages/legacy_storage/lib/src/coordinator.dart',
      'packages/legacy_storage/lib/src/retirement.dart',
      'packages/secrets/lib/src/data/legacy_retirement.dart',
      'packages/exchange/lib/src/data/storage/exchange_credential_retirement.dart',
      'features/recoverbull/lib/src/data/database/recoverbull_retirement.dart',
    ];
    for (final path in files) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('LegacyRetirementActivation')), reason: path);
      expect(text, isNot(contains('deleteLegacyEntries')), reason: path);
      expect(text, isNot(contains('.deleteSync(')), reason: path);
      expect(
        text,
        isNot(contains('Future<Result<void, LegacyImportFailure>> retire(')),
        reason: path,
      );
    }
  });

  test('no production code calls the destructive retirement', () {
    // Same-named methods exist: a payment admission attempt revokes itself for
    // this process. The dormant storage retirement takes a
    // `LegacyRetirementActivation`, so only a no-argument call on a receiver
    // declared as `PayinWalletAttempt` is exempt; every other `retire` call,
    // including one on an unresolved receiver, fails here.
    final offenders = [
      for (final file in sources())
        ..._destructiveRetires(file.path, file.readAsStringSync()),
    ];
    expect(offenders, isEmpty);
  });

  test('the dormant guard still recognizes a destructive call', () {
    const destructive =
        'class A { Future<void> f(c, activation) => c.retire(activation); }';
    const unresolved = 'void f(c) { c.retire(); }';
    const revocation =
        'PayinWalletAttempt? attempt; void f() { attempt?.retire(); }';
    expect(_destructiveRetires('a.dart', destructive), isNotEmpty);
    expect(_destructiveRetires('a.dart', unresolved), isNotEmpty);
    expect(_destructiveRetires('a.dart', revocation), isEmpty);
  });

  test('no production code calls the retirement diagnostic', () {
    final offenders = [
      for (final file in sources())
        if (RegExp(r'\.evaluateRetirement\s*\(')
            .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });

  test('the shell composes no retirement participant', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            RegExp(
              r'retirementParticipants|SecretsRetirement|'
              r'ExchangeCredentialRetirement|RecoverBullRetirement',
            ).hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty);
  });
}
