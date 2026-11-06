import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

/// Symbol-resolved native-write boundary. This is not whole-program path/taint
/// analysis: dynamic IO helpers and new native APIs require policy review.
/// Analysis errors and unresolved sensitive native members fail closed.
Future<void> main(List<String> arguments) async {
  final root = Directory(arguments.isEmpty ? '.' : arguments.single).absolute;
  final report = await checkNativeWrites(root.path);
  for (final violation in report.violations) {
    stderr.writeln(violation);
  }
  stdout.writeln(
    'Native-write boundary: ${report.fileCount} files, '
    '${report.violations.length} violations',
  );
  if (report.violations.isNotEmpty) exitCode = 1;
}

class NativeWriteReport {
  final int fileCount;
  final List<String> violations;

  const NativeWriteReport(this.fileCount, this.violations);
}

Future<NativeWriteReport> checkNativeWrites(String rootPath) async {
  final root = Directory(rootPath).resolveSymbolicLinksSync();
  final collection = AnalysisContextCollection(
    includedPaths: [root],
    sdkPath: dartSdkPath(root),
  );
  final files = productionDartFiles(root);
  final violations = <String>[];
  for (final path in files) {
    final relative = path.substring(root.length + 1);
    final result = await collection
        .contextFor(path)
        .currentSession
        .getResolvedUnit(path);
    if (result is! ResolvedUnitResult) {
      violations.add('$relative: unresolved unit');
      continue;
    }
    for (final diagnostic in result.diagnostics) {
      if (diagnostic.diagnosticCode.severity.name == 'ERROR') {
        violations.add('$relative: ${diagnostic.diagnosticCode.lowerCaseName}');
      }
    }
    violations.addAll(checkUnit(result.unit, relative));
  }
  await collection.dispose();
  return NativeWriteReport(files.length, violations.toSet().toList()..sort());
}

List<String> productionDartFiles(String root) {
  final roots = <Directory>[Directory('$root/lib')];
  for (final group in ['packages', 'features']) {
    final parent = Directory('$root/$group');
    if (!parent.existsSync()) continue;
    for (final member in parent.listSync(followLinks: false)) {
      if (member is Directory) {
        roots.add(Directory('${member.path}/lib'));
      }
    }
  }
  return [
    for (final directory in roots)
      if (directory.existsSync())
        for (final file in directory.listSync(
          recursive: true,
          followLinks: false,
        ))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !RegExp(
                r'\.(g|freezed|gr|config|mocks|steps)\.dart$',
              ).hasMatch(file.path) &&
              !file.path
                  .split(Platform.pathSeparator)
                  .any(
                    (part) => ['generated', 'vendor', 'build'].contains(part),
                  ))
            file.path,
  ]..sort();
}

List<String> checkUnit(CompilationUnit unit, String relativePath) {
  if (relativePath.startsWith('packages/transaction_sync/lib/src/write/') ||
      relativePath.startsWith('packages/transaction_sync/lib/src/engine/')) {
    return [];
  }
  final visitor = _NativeWriteVisitor(relativePath, unit);
  unit.accept(visitor);
  return visitor.violations.toList()..sort();
}

const snapshotModule =
    'packages/transaction_sync/lib/src/read/wallet_snapshot_reader.dart';
const _dryScanFile =
    'lib/core/wallet/data/datasources/bdk_wallet_datasource.dart';

class _NativeWriteVisitor extends RecursiveAstVisitor<void> {
  final String path;
  final CompilationUnit unit;
  final Set<String> violations = {};

  _NativeWriteVisitor(this.path, this.unit);

  void check(Element? element, AstNode node) {
    if (element == null) {
      if (node is SimpleIdentifier &&
          {
            'persist',
            'applyUpdate',
            'applyUpdateEvents',
            'sync_',
            'newSqlite',
            'newInMemory',
          }.contains(node.name)) {
        violations.add('$path: unresolved sensitive member ${node.name}');
      }
      return;
    }
    if (element.library?.uri.toString() == 'dart:io' &&
        {'delete', 'deleteSync'}.contains(element.name) &&
        path != snapshotModule &&
        _nativeIoContext(node)) {
      violations.add('$path: native store deletion');
    }
    final symbol = nativeWriteSymbol(element);
    if (symbol == null) return;
    // One audited snapshot-copy module; never a directory-wide reader bypass.
    if (path == snapshotModule) return;
    if (_inMemoryDryScan(node, symbol)) return;
    violations.add('$path: $symbol');
  }

  bool _inMemoryDryScan(AstNode node, String symbol) {
    if (path != _dryScanFile || !symbol.startsWith('package:bdk_dart/')) {
      return false;
    }
    FunctionDeclaration? function;
    for (AstNode? parent = node; parent != null; parent = parent.parent) {
      if (parent is MethodDeclaration) return false;
      if (parent is FunctionDeclaration) function = parent;
    }
    if (function == null || function.name.lexeme != '_performDryScan') {
      return false;
    }
    final proof = _MemoryOnlyProof();
    function.accept(proof);
    return (proof.memoryPersisters.isNotEmpty ||
            proof.memoryWallets.isNotEmpty) &&
        proof.safe;
  }

  @override
  void visitCommentReference(CommentReference node) {}

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext()) check(node.element, node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    check(node.element, node);
    super.visitNamedType(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    check(node.element, node);
    super.visitConstructorName(node);
  }

  @override
  void visitDotShorthandConstructorInvocation(
    DotShorthandConstructorInvocation node,
  ) {
    check(node.element, node);
    super.visitDotShorthandConstructorInvocation(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    if (element?.library?.uri.toString() == 'dart:io' &&
        {'delete', 'deleteSync'}.contains(element?.name) &&
        path != snapshotModule &&
        _nativeIoContext(node)) {
      violations.add('$path: native store deletion');
    }
    super.visitMethodInvocation(node);
  }

  bool _nativeIoContext(AstNode node) {
    // Covers the legacy facades and locally derived storage paths, including
    // aliases. SDK imports identify old path helpers before caller cutover.
    return unit.directives.whereType<ImportDirective>().any((directive) {
          final uri = directive.uri.stringValue ?? '';
          return uri == 'package:bull_sdk/bdk.dart' ||
              uri == 'package:bull_sdk/lwk.dart';
        }) ||
        unit.toSource().contains('nativeWalletStoragePath') ||
        unit.toSource().contains('_bdk_dart');
  }
}

/// The dry scan may only construct wallets using final local in-memory
/// persisters. A persistent factory, parameter or reassignment closes the hole.
class _MemoryOnlyProof extends RecursiveAstVisitor<void> {
  final Set<Element> memoryPersisters = {};
  final Set<Element> memoryWallets = {};
  bool safe = true;

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final initializer = node.initializer;
    final list = node.parent;
    if (initializer is InstanceCreationExpression &&
        list is VariableDeclarationList &&
        list.isFinal) {
      final constructor = initializer.constructorName.element;
      final element = node.declaredFragment?.element;
      if (element != null &&
          (constructor?.library.uri.toString().startsWith(
                'package:bdk_dart/',
              ) ??
              false)) {
        if (constructor?.enclosingElement.name == 'Persister' &&
            constructor?.name == 'newInMemory') {
          memoryPersisters.add(element);
        }
        if (constructor?.enclosingElement.name == 'Wallet' &&
            _hasMemoryPersister(initializer.argumentList)) {
          memoryWallets.add(element);
        }
      }
    }
    super.visitVariableDeclaration(node);
  }

  bool _hasMemoryPersister(ArgumentList list) {
    final args = list.arguments.whereType<NamedExpression>().where(
      (arg) => arg.name.label.name == 'persister',
    );
    if (args.length != 1) return false;
    final value = args.single.expression;
    if (value is SimpleIdentifier) {
      return memoryPersisters.contains(value.element);
    }
    if (value is InstanceCreationExpression) {
      final constructor = value.constructorName.element;
      return constructor?.enclosingElement.name == 'Persister' &&
          constructor?.name == 'newInMemory' &&
          (constructor?.library.uri.toString().startsWith(
                'package:bdk_dart/',
              ) ??
              false);
    }
    return false;
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final element = node.methodName.element;
    final symbol = element == null ? null : nativeWriteSymbol(element);
    if (symbol != null &&
        symbol.startsWith('package:bdk_dart/') &&
        {
          'persist',
          'applyUpdate',
          'applyUpdateEvents',
        }.contains(node.methodName.name)) {
      final target = node.target;
      if (target is! SimpleIdentifier ||
          !memoryWallets.contains(target.element)) {
        safe = false;
      }
      if (node.methodName.name == 'persist' &&
          !_hasMemoryPersister(node.argumentList)) {
        safe = false;
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element?.library?.uri.toString().startsWith('package:bdk_dart/') ??
        false) {
      final owner = element?.enclosingElement?.name;
      if ({'Persister', 'PersisterInterface'}.contains(owner) &&
          element?.name != 'newInMemory' &&
          element?.name != 'dispose') {
        safe = false;
      }
      if ({'Wallet', 'WalletInterface'}.contains(owner) &&
          {
            'persist',
            'applyUpdate',
            'applyUpdateEvents',
          }.contains(element?.name) &&
          node.parent is! MethodInvocation) {
        safe = false;
      }
      if (element is ConstructorElement && owner == 'Wallet') {
        safe =
            false; // Constructor tear-offs cannot prove their future arguments.
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitDotShorthandConstructorInvocation(
    DotShorthandConstructorInvocation node,
  ) {
    final element = node.element;
    if (element != null && nativeWriteSymbol(element) != null) {
      // Dry scans use explicit constructors so their provenance is auditable.
      safe = false;
    }
    super.visitDotShorthandConstructorInvocation(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    final element = node.element;
    final uri = element?.library.uri.toString() ?? '';
    if (uri.startsWith('package:bdk_dart/')) {
      if (element?.enclosingElement.name == 'Persister' &&
          element?.name != 'newInMemory') {
        safe = false;
      }
      if (element?.enclosingElement.name == 'Wallet') {
        final creation = node.parent;
        if (creation is! InstanceCreationExpression) {
          safe = false;
        } else {
          if (!_hasMemoryPersister(creation.argumentList)) safe = false;
        }
      }
    }
    super.visitConstructorName(node);
  }
}

String? nativeWriteSymbol(Element element) {
  final uri = element.library?.uri.toString();
  if (uri == null) return null;
  final owner = element.enclosingElement?.name;
  final name = element.name;
  final symbol = '$owner.$name';
  var forbidden = false;
  if (uri.startsWith('package:bdk_dart/')) {
    forbidden =
        name == 'Persister' ||
        name == 'PersisterInterface' ||
        owner == 'Persister' ||
        owner == 'PersisterInterface' ||
        ({'Wallet', 'WalletInterface'}.contains(owner) &&
            ({'persist', 'applyUpdate', 'applyUpdateEvents'}.contains(name) ||
                element is ConstructorElement));
  }
  if (uri.startsWith('package:bull_sdk/src/rust/third_party/lwk/')) {
    forbidden = owner == 'Wallet' && {'init', 'sync_'}.contains(name);
  }
  // Calls to legacy deletion wrappers are forbidden as well as direct IO.
  if ({
        'BdkFacade',
        'LwkFacade',
        'BdkWalletDatasource',
        'LwkWalletDatasource',
      }.contains(owner) &&
      name == 'delete') {
    forbidden = true;
  }
  return forbidden ? '$uri#$symbol' : null;
}

String dartSdkPath(String start) {
  var directory = Directory(start);
  while (true) {
    final config = File('${directory.path}/.dart_tool/package_config.json');
    if (config.existsSync()) {
      final packages =
          (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
      final flutter = packages.cast<Map>().firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final root = config.uri
          .resolve(flutter['rootUri'] as String)
          .toFilePath();
      return '${Directory(root).parent.parent.path}/bin/cache/dart-sdk';
    }
    if (directory.parent.path == directory.path) {
      throw StateError('No package_config.json');
    }
    directory = directory.parent;
  }
}
