import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Rules of the exchange state machines (packages/exchange,
/// features/bull_exchange) that the compiler can't enforce on its own.
const _exchangeLib = 'packages/exchange/lib';
const _exchangeFeatureLib = 'features/bull_exchange/lib';
const _exchangeRoots = ['packages/exchange', 'features/bull_exchange'];

bool _isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.endsWith('.drift.dart') ||
    p.split(path).contains('generated');

Iterable<File> _dartSources(String root) sync* {
  final directory = Directory(root);
  if (!directory.existsSync()) return;
  for (final entry in directory.listSync(followLinks: false)) {
    if (entry is File &&
        p.extension(entry.path) == '.dart' &&
        !_isGenerated(entry.path)) {
      yield entry;
    }
    if (entry is Directory) {
      final name = p.basename(entry.path);
      if (name.startsWith('.') || name == 'build') continue;
      yield* _dartSources(entry.path);
    }
  }
}

CompilationUnit _parse(File source) => parseString(
  content: source.readAsStringSync(),
  path: source.path,
  throwIfDiagnostics: false,
).unit;

String _where(File source, CompilationUnit unit, AstNode node) =>
    '${p.normalize(source.path)}:'
    '${unit.lineInfo.getLocation(node.offset).lineNumber}: '
    '${node.toSource().split('\n').first}';

// ---------------------------------------------------------------------------
// (a) No catch-all arm in the machines.

/// Files whose every switch is over a flow or step state or event: the step
/// library, and the flow and machine files of the exchange feature.
bool _isMachineFile(String path) {
  final normalized = p.normalize(path);
  if (p.isWithin(p.join(_exchangeLib, 'src', 'steps'), normalized)) {
    return true;
  }
  if (!p.isWithin(_exchangeFeatureLib, normalized)) return false;
  final name = p.basename(normalized);
  return name.endsWith('_flow.dart') || name.endsWith('_machine.dart');
}

/// `_`, or a record of nothing but `_`: an arm that answers every value
/// left, so a new state or event never reaches a decision.
bool _isWildcard(DartPattern pattern) => switch (pattern) {
  WildcardPattern(:final type) => type == null,
  RecordPattern(:final fields) => fields.every(
    (field) => _isWildcard(field.pattern),
  ),
  ParenthesizedPattern(:final pattern) => _isWildcard(pattern),
  _ => false,
};

/// An untyped `final x` arm is a catch-all too, except after a `null` arm
/// (and other `final x` arms only), where it only names the non-null value.
bool _isCatchAll(DartPattern pattern, {required bool afterNull}) =>
    _isWildcard(pattern) ||
    (pattern is DeclaredVariablePattern && pattern.type == null && !afterNull);

bool _isNullArm(DartPattern pattern) =>
    pattern is ConstantPattern && pattern.expression is NullLiteral;

class _CatchAllArms extends RecursiveAstVisitor<void> {
  _CatchAllArms(this.report);

  final void Function(AstNode) report;

  void _check(Iterable<(GuardedPattern, AstNode)> arms) {
    var afterNull = false;
    for (final (guarded, arm) in arms) {
      if (guarded.whenClause == null &&
          _isCatchAll(guarded.pattern, afterNull: afterNull)) {
        report(arm);
      }
      // `null => …, final x when … => …, final x => …` still unwraps.
      afterNull =
          _isNullArm(guarded.pattern) ||
          (afterNull && guarded.pattern is DeclaredVariablePattern);
    }
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    for (final member in node.members) {
      if (member is SwitchDefault) report(member);
    }
    _check([
      for (final member in node.members)
        if (member is SwitchPatternCase) (member.guardedPattern, member),
    ]);
    super.visitSwitchStatement(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _check([for (final arm in node.cases) (arm.guardedPattern, arm)]);
    super.visitSwitchExpression(node);
  }
}

/// Transition functions outside the machine files (named `transition*`).
class _TransitionFunctions extends RecursiveAstVisitor<void> {
  final found = <AstNode>[];

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.name.lexeme.startsWith('transition')) found.add(node);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme.startsWith('transition')) found.add(node);
    super.visitMethodDeclaration(node);
  }
}

List<String> catchAllArms(Iterable<File> sources) {
  final found = <String>[];
  for (final source in sources) {
    final unit = _parse(source);
    void report(AstNode node) => found.add(_where(source, unit, node));
    if (_isMachineFile(source.path)) {
      unit.accept(_CatchAllArms(report));
      continue;
    }
    final transitions = _TransitionFunctions();
    unit.accept(transitions);
    for (final function in transitions.found) {
      function.accept(_CatchAllArms(report));
    }
  }
  return found..sort();
}

// ---------------------------------------------------------------------------
// (b) The exchange knows nothing of the app.

List<String> appImports(Iterable<File> sources) {
  final found = <String>[];
  for (final source in sources) {
    final unit = _parse(source);
    for (final directive in unit.directives) {
      if (directive is! UriBasedDirective) continue;
      final uri = directive.uri.stringValue ?? '';
      if (uri.startsWith('package:bb_mobile/')) {
        found.add(_where(source, unit, directive));
      }
    }
  }
  return found..sort();
}

/// A literal that can be a route path: `/a/b`, `a-b`, `a/:id`.
final _routeShape = RegExp(r'^/?[a-z][a-z0-9_-]*(/[a-z0-9:_-]+)*$');

bool _routeLike(String value) =>
    value.length > 1 &&
    _routeShape.hasMatch(value) &&
    (value.startsWith('/') || value.contains('-') || value.contains('/'));

/// Route paths the app and the other features declare: `path:` arguments,
/// `*Route` enum values, and `*path`/`*Path` constants.
class _DeclaredPaths extends RecursiveAstVisitor<void> {
  final paths = <String>{};

  void _add(AstNode? expression) {
    if (expression is SimpleStringLiteral && _routeLike(expression.value)) {
      paths.add(expression.value);
    }
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    if (node.name.lexeme == 'path') _add(node.argumentExpression);
    super.visitNamedArgument(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    if (node.namePart.typeName.lexeme.endsWith('Route')) {
      for (final constant in node.body.constants) {
        for (final argument
            in constant.arguments?.argumentList.arguments ??
                const <Argument>[]) {
          _add(argument.argumentExpression);
        }
      }
    }
    super.visitEnumDeclaration(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    if (node.name.lexeme.toLowerCase().endsWith('path')) _add(node.initializer);
    super.visitVariableDeclaration(node);
  }
}

Set<String> appRoutePaths() {
  final declared = _DeclaredPaths();
  final appSources = [
    ..._dartSources('lib').where(
      (file) => !p.isWithin(p.join('lib', 'features', 'exchange'), file.path),
    ),
    for (final feature in Directory('features').listSync())
      if (feature is Directory && p.basename(feature.path) != 'bull_exchange')
        ..._dartSources(p.join(feature.path, 'lib')),
  ];
  for (final source in appSources) {
    _parse(source).accept(declared);
  }
  return declared.paths;
}

class _StringLiterals extends RecursiveAstVisitor<void> {
  final literals = <SimpleStringLiteral>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    literals.add(node);
    super.visitSimpleStringLiteral(node);
  }
}

List<String> appPathLiterals(Iterable<File> sources, Set<String> appPaths) {
  final found = <String>[];
  for (final source in sources) {
    final unit = _parse(source);
    final literals = _StringLiterals();
    unit.accept(literals);
    for (final literal in literals.literals) {
      if (appPaths.contains(literal.value)) {
        found.add(_where(source, unit, literal));
      }
    }
  }
  return found..sort();
}

// ---------------------------------------------------------------------------
// (c) The exchange domain is pure Dart.

const _uiLibraries = [
  'dart:ui',
  'package:flutter/',
  'package:flutter_bloc/',
  'package:bull_ui/',
  'package:material_ui/',
];

List<String> uiImports(Iterable<File> sources) {
  final found = <String>[];
  for (final source in sources) {
    final unit = _parse(source);
    for (final directive in unit.directives) {
      if (directive is! UriBasedDirective) continue;
      final uri = directive.uri.stringValue ?? '';
      if (_uiLibraries.any(uri.startsWith)) {
        found.add(_where(source, unit, directive));
      }
    }
  }
  return found..sort();
}

// ---------------------------------------------------------------------------
// (d) Screens never write: writes run in blocs, through the write gate.

/// Names of the exchange's write calls: every method of packages/exchange
/// that answers an `ExchangeWrite`.
class _WriteMethods extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    final returns = node.returnType?.toSource() ?? '';
    if (returns.contains('ExchangeWrite<')) names.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
  }
}

Set<String> exchangeWriteNames() {
  final writes = _WriteMethods();
  for (final source in _dartSources(_exchangeLib)) {
    _parse(source).accept(writes);
  }
  return writes.names;
}

class _NamedCalls extends RecursiveAstVisitor<void> {
  _NamedCalls(this.names);

  final Set<String> names;
  final found = <AstNode>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target != null && names.contains(node.methodName.name)) {
      found.add(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'writeGate') found.add(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.identifier.name == 'writeGate') found.add(node);
    super.visitPrefixedIdentifier(node);
  }
}

/// Widgets under `ui/`. Route and mount files build the blocs, so they hand
/// the gate over and are not screens.
bool _isScreenFile(String path) {
  final normalized = p.normalize(path);
  final name = p.basename(normalized);
  final wiring =
      RegExp(r'_(router|route|routes|mount)\.dart$').hasMatch(name) ||
      name.startsWith('mount_');
  return p.isWithin(p.join(_exchangeFeatureLib, 'src'), normalized) &&
      p.split(normalized).contains('ui') &&
      !wiring;
}

List<String> screenWrites(Iterable<File> sources, Set<String> writes) {
  final found = <String>[];
  for (final source in sources.where((file) => _isScreenFile(file.path))) {
    final unit = _parse(source);
    final calls = _NamedCalls(writes);
    unit.accept(calls);
    found.addAll(calls.found.map((node) => _where(source, unit, node)));
  }
  return found..sort();
}

void main() {
  final exchangeLibSources = [
    ..._dartSources(_exchangeLib),
    ..._dartSources(_exchangeFeatureLib),
  ];

  test('machines and transition functions have no catch-all arm', () {
    expect(_dartSources(p.join(_exchangeLib, 'src', 'steps')), isNotEmpty);
    expect(catchAllArms(exchangeLibSources), isEmpty);
  });

  test('packages/exchange and bull_exchange import nothing from the app', () {
    expect(
      appImports([for (final root in _exchangeRoots) ..._dartSources(root)]),
      isEmpty,
    );
  });

  test('packages/exchange and bull_exchange name no app route path', () {
    final appPaths = appRoutePaths();
    expect(appPaths, contains('/settings'));
    expect(appPathLiterals(exchangeLibSources, appPaths), isEmpty);
  });

  test('packages/exchange/lib imports no Flutter or UI kit', () {
    expect(uiImports(_dartSources(_exchangeLib)), isEmpty);
  });

  test('bull_exchange screens call no exchange write', () {
    final writes = exchangeWriteNames();
    expect(writes, contains('confirmBuyOrder'));
    expect(screenWrites(exchangeLibSources, writes), isEmpty);
  });
}
