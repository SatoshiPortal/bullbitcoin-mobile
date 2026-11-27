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
