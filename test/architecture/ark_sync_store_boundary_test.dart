import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Spend does not borrow the foreground Sync for freeze reads', () {
    final sources = Directory('packages/spend/lib').listSync(recursive: true);
    expect([
      for (final file in sources.whereType<File>())
        if (file.path.endsWith('.dart'))
          for (final loan in _loans(file.readAsStringSync()))
            '${file.path}: $loan',
    ], isEmpty);
  });

  test('Coins and Labels cannot borrow the foreground Sync', () {
    final runtime = File(
      'packages/sync/lib/src/data/runtime/wallet_native_runtime.dart',
    ).readAsStringSync();
    final declarations = parseString(content: runtime).unit.declarations;
    final native = declarations.whereType<ClassDeclaration>().singleWhere(
      (node) => node.namePart.typeName.lexeme == 'WalletNativeRuntime',
    );
    expect(
      native.body.members.whereType<MethodDeclaration>().map(
        (node) => node.name.lexeme,
      ),
      isNot(contains('foreground')),
    );
    final sources = [
      ...Directory('features/coins/lib').listSync(recursive: true),
      ...Directory('packages/labels/lib').listSync(recursive: true),
      File('lib/core_locator.dart'),
      // Present until the historical wallet owner is deleted; kept in the scan
      // so it cannot quietly become a second composition root.
      File('lib/features/wallet/wallet_core_locator.dart'),
      File('lib/locator.dart'),
      File('lib/init.dart'),
      File('test/recoverbull_composition_test.dart'),
    ];
    // These other owners' foreground factories are not runtime loans.
    final allowed = {'WalletHistoryEvents'};
    final access = RegExp(r'(\w+)?\s*\.\s*foreground\b');
    expect([
      for (final file in sources.whereType<File>())
        if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
          for (final match in access.allMatches(file.readAsStringSync()))
            if (!allowed.contains(match.group(1)))
              '${file.path}: ${match.group(0)}',
    ], isEmpty);
  });

  test('detects both direct and multiline store loans', () {
    expect(
      _loans('''
Future<void> inspect() async {
  final gate = unwrap(await runtime.foreground()).stores.spendGate;
  final input = (foreground as Object)
      .value
      .stores
      .inputReservations;
  // unrelated.stores
}
'''),
      ['foreground()', '.stores', '.stores'],
    );
  });

  test(
    'Ark has no raw foreground loans and Sync does not export its getter',
    () {
      final violations = <String>[];
      for (final file in Directory(
        'features/ark/lib',
      ).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final loan in _loans(file.readAsStringSync())) {
          violations.add('${file.path}: $loan');
        }
      }
      final writes = parseString(
        content: File('packages/sync/lib/write.dart').readAsStringSync(),
      ).unit;
      for (final export in writes.directives.whereType<ExportDirective>()) {
        if (export.uri.stringValue != 'src/public/sync.dart') continue;
        final shown = export.combinators.whereType<ShowCombinator>();
        if (shown.isEmpty ||
            shown.any(
              (show) => show.shownNames.any(
                (name) => name.name == 'SyncForegroundStores',
              ),
            )) {
          violations.add('packages/sync/lib/write.dart: SyncForegroundStores');
        }
      }
      expect(violations, isEmpty);
    },
  );
}

List<String> _loans(String source) {
  final visitor = _LoanVisitor();
  parseString(content: source).unit.accept(visitor);
  return visitor.loans;
}

final class _LoanVisitor extends RecursiveAstVisitor<void> {
  final loans = <String>[];

  @override
  void visitPropertyAccess(PropertyAccess node) {
    super.visitPropertyAccess(node);
    if (node.propertyName.name == 'stores') loans.add('.stores');
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'stores') loans.add('.stores');
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'foreground') loans.add('foreground()');
    super.visitMethodInvocation(node);
  }
}
