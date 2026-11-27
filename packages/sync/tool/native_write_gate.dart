import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import 'native_import_allowlist.dart';

/// Symbol-resolved native-write and RecoverBull backup-preparation boundary.
/// This is not whole-program path/taint
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
  final importers = <String>{};
  for (final path in files) {
    final relative = path.substring(root.length + 1);
    final result = await resolveProductionUnit(collection, path);
    if (result == null) {
      violations.add('$relative: unresolved unit');
      continue;
    }
    for (final diagnostic in result.diagnostics) {
      if (diagnostic.diagnosticCode.severity.name == 'ERROR') {
        violations.add('$relative: ${diagnostic.diagnosticCode.lowerCaseName}');
      }
    }
    violations.addAll(checkUnit(result.unit, relative));
    final imports = checkNativeImports(result.unit, relative);
    violations.addAll(imports);
    if (imports.isEmpty && usesNativeWallets(result.unit)) {
      importers.add(relative);
    }
  }
  await collection.dispose();
  violations.addAll(staleNativeImportEntries(importers));
  return NativeWriteReport(files.length, violations.toSet().toList()..sort());
}

/// Resolves [path], including a file the analysis options exclude, such as
/// generated code: the session of the context whose root contains it still
/// resolves it. Null (failing closed) when no context contains it.
Future<ResolvedUnitResult?> resolveProductionUnit(
  AnalysisContextCollection collection,
  String path,
) async {
  final containing = collection.contexts
      .where((context) => path.startsWith('${context.contextRoot.root.path}/'))
      .toList();
  if (containing.isEmpty) return null;
  containing.sort(
    (a, b) => b.contextRoot.root.path.length - a.contextRoot.root.path.length,
  );
  final session = containing.first.currentSession;
  // analyzer 13 resolves an excluded `part of` file (generated code) on its
  // own, without its library, so every name it uses is undefined. Resolve the
  // library that owns it instead and take the part's unit from it.
  final parsed = session.getParsedUnit(path);
  if (parsed is ParsedUnitResult) {
    final partOf = parsed.unit.directives.whereType<PartOfDirective>();
    if (partOf.isNotEmpty) {
      final uri = partOf.single.uri?.stringValue;
      if (uri == null) return null;
      final library = File(path).parent.uri.resolve(uri).toFilePath();
      final resolved = await session.getResolvedLibrary(library);
      return resolved is ResolvedLibraryResult
          ? resolved.unitWithPath(path)
          : null;
    }
  }
  final result = await session.getResolvedUnit(path);
  return result is ResolvedUnitResult ? result : null;
}

/// Every Dart file under a `lib/` of the app and its workspace members,
/// generated code included: nothing compiled into the app is exempt.
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
          if (file is File && file.path.endsWith('.dart')) file.path,
  ]..sort();
}

List<String> checkUnit(CompilationUnit unit, String relativePath) {
  final backup = _BackupBoundaryVisitor(relativePath);
  unit.accept(backup);
  // Native store mutations are confined to the writer, sync passes included.
  if (relativePath.startsWith(writerModules)) return backup.violations.toList();
  final visitor = _NativeWriteVisitor(relativePath, unit);
  unit.accept(visitor);
  return {...visitor.violations, ...backup.violations}.toList()..sort();
}

/// RecoverBull backup preparation is a privileged inventory operation. This
/// checks resolved declarations, including aliases and tear-offs, not names
/// alone. Dynamic dispatch remains outside this static boundary.
class _BackupBoundaryVisitor extends RecursiveAstVisitor<void> {
  final String path;
  final Set<String> violations = {};

  _BackupBoundaryVisitor(this.path);

  bool _recoverBull(String uri) =>
      uri.startsWith('package:bull_recoverbull/') ||
      uri.contains('/features/recoverbull/lib/');

  bool _testing(String? uri) =>
      uri == 'package:bull_recoverbull/testing.dart' ||
      (uri?.endsWith('/features/recoverbull/lib/testing.dart') ?? false);

  @override
  void visitImportDirective(ImportDirective node) {
    final uri = node.libraryImport?.importedLibrary?.uri.toString();
    if (_testing(uri)) {
      violations.add('$path: RecoverBull testing library in production');
    }
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    final uri = node.libraryExport?.exportedLibrary?.uri.toString();
    if (_testing(uri)) {
      violations.add('$path: RecoverBull testing library in production');
    }
    super.visitExportDirective(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext()) _check(node.element, node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    _check(node.element, node);
    super.visitConstructorName(node);
  }

  void _check(Element? element, AstNode node) {
    // This library is the fixture-only boundary itself, not a consumer.
    if (path == 'features/recoverbull/lib/testing.dart') return;
    final uri = element?.library?.uri.toString() ?? '';
    final owner = element?.enclosingElement?.name;
    final name = element?.name;
    if (_recoverBull(uri) &&
        {
          'writeWalletBackupForTesting',
          'removeWalletBackupForTesting',
          'openRecoverBullDatabaseForTesting',
          'recoverBullStorageForTesting',
          'recoverBullCutoverForTesting',
        }.contains(name)) {
      violations.add('$path: RecoverBull testing helper $name');
    }
    if (_recoverBull(uri) &&
        owner == 'RecoverBullWalletBackups' &&
        name == 'prepare' &&
        path !=
            'features/recoverbull/lib/src/data/database/recoverbull_wallet_properties.dart') {
      violations.add('$path: RecoverBullWalletBackups.prepare');
    }
    if (((_recoverBull(uri) && owner == 'RecoverBullWalletProperties') ||
            ((uri.startsWith('package:secrets/') ||
                    uri.contains('/packages/secrets/lib/')) &&
                owner == 'WalletPropertyStore')) &&
        name == 'prepareWallet') {
      AstNode? cursor = node;
      while (cursor != null && cursor is! MethodDeclaration) {
        cursor = cursor.parent;
      }
      if (path != 'packages/provisioning/lib/src/wallet_provisioning.dart' ||
          cursor is! MethodDeclaration ||
          cursor.name.lexeme != '_prepareProperties') {
        violations.add('$path: $owner.prepareWallet');
      }
    }
    if ((uri.startsWith('package:provisioning/') ||
            uri.contains('/packages/provisioning/lib/')) &&
        owner == '_WalletProvisioning' &&
        name == '_prepareProperties') {
      var inCallback = false;
      AstNode? cursor = node;
      while (cursor != null && cursor is! MethodDeclaration) {
        if (cursor is NamedArgument &&
            cursor.name.lexeme == 'prepareProperties') {
          final arguments = cursor.parent;
          final call = arguments?.parent;
          if (call is MethodInvocation) {
            final target = call.methodName.element;
            final source = target?.library?.uri.toString() ?? '';
            inCallback =
                target?.name == 'registerWallet' &&
                target?.enclosingElement?.name == 'SecretsInventory' &&
                (source.startsWith('package:secrets/') ||
                    source.contains('/packages/secrets/lib/'));
          }
        }
        cursor = cursor.parent;
      }
      if (path != 'packages/provisioning/lib/src/wallet_provisioning.dart' ||
          !inCallback ||
          cursor is! MethodDeclaration ||
          cursor.name.lexeme != '_provision') {
        violations.add(
          '$path: provisioning property preparation outside inventory callback',
        );
      }
    }
    if (_recoverBull(uri) &&
        owner == 'RecoverBullCutover' &&
        (name == 'open' ||
            name == 'openForInventory' ||
            name == 'withTestExecutor') &&
        !{
          'features/recoverbull/lib/src/data/database/recoverbull_wallet_backups.dart',
          'features/recoverbull/lib/src/data/database/wallet_backup_import.dart',
          'features/recoverbull/lib/src/data/database/recoverbull_storage.dart',
        }.contains(path)) {
      violations.add('$path: RecoverBullCutover.$name');
    }
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if ({'prepare', 'prepareWallet'}.contains(node.methodName.name) &&
        node.methodName.element == null) {
      violations.add('$path: unresolved ${node.methodName.name}');
    }
    super.visitMethodInvocation(node);
  }
}

const writerModules = 'packages/sync/lib/src/data/write/';

/// The package that owns native wallet state may use BDK and LWK anywhere.
const nativeOwner = 'packages/sync/';

/// The package that declares the BDK and LWK bindings, not a consumer of them.
const nativeProvider = 'packages/rust_bindings/';

/// Directive URIs that bring BDK or LWK wallet bindings into a library.
bool isNativeWalletUri(String uri) =>
    uri == 'package:rust_bindings/bdk.dart' ||
    uri == 'package:rust_bindings/lwk.dart' ||
    uri.startsWith('package:bdk_dart/') ||
    uri.startsWith('package:rust_bindings/src/rust/third_party/lwk/') ||
    uri == 'package:rust_bindings/src/lwk_consolidate.dart';

/// Whether [unit] imports, exports or references a BDK or LWK symbol. The
/// symbol check catches a re-export bridge that never names the SDK.
bool usesNativeWallets(CompilationUnit unit) {
  final directives = unit.directives.whereType<NamespaceDirective>().any(
    (directive) => isNativeWalletUri(directive.uri.stringValue ?? ''),
  );
  if (directives) return true;
  final visitor = _NativeSymbolVisitor();
  unit.accept(visitor);
  return visitor.found;
}

/// Ratchet: outside [nativeOwner], only the files listed in
/// [nativeImportAllowlist] may touch BDK or LWK. The list only shrinks.
List<String> checkNativeImports(CompilationUnit unit, String relativePath) {
  if (relativePath.startsWith(nativeOwner) ||
      relativePath.startsWith(nativeProvider)) {
    return const [];
  }
  if (nativeImportAllowlist.contains(relativePath)) return const [];
  return usesNativeWallets(unit)
      ? ['$relativePath: BDK/LWK outside sync (native import ratchet)']
      : const [];
}

/// An allowlisted file that no longer uses BDK or LWK must leave the list,
/// so the exception cannot be reused by a later change.
List<String> staleNativeImportEntries(Set<String> importers) => [
  for (final entry in nativeImportAllowlist)
    if (!importers.contains(entry))
      '$entry: stale native import allowlist entry, remove it',
];

class _NativeSymbolVisitor extends RecursiveAstVisitor<void> {
  bool found = false;

  void _check(Element? element) {
    final uri = element?.library?.uri.toString();
    if (uri != null && isNativeWalletUri(uri)) found = true;
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _check(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _check(node.element);
    super.visitNamedType(node);
  }
}

/// Reader modules may hydrate existing stores, never mutate them.
const readerModules = 'packages/sync/lib/src/data/read/';
const snapshotModule = '${readerModules}wallet_snapshot_reader.dart';
const _dryScanFile = 'packages/sync/lib/src/data/chain/bitcoin_prescan.dart';

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
            'revealNextAddress',
            'revealAddressesTo',
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
        !_signerAllowance(node, element) &&
        _nativeIoContext(node)) {
      violations.add('$path: native store deletion');
    }
    final symbol = nativeWriteSymbol(element);
    if (symbol == null) return;
    if (path.startsWith(readerModules)) {
      final owner = element.enclosingElement?.name;
      if (element.name == 'Persister' ||
          element.name == 'PersisterInterface' ||
          ({'Persister', 'PersisterInterface'}.contains(owner) &&
              {'newSqlite', 'dispose'}.contains(element.name)) ||
          (owner == 'Wallet' && {'load', 'init'}.contains(element.name))) {
        return;
      }
    }
    if (_signerAllowance(node, element)) return;
    if (_inMemoryDryScan(node, symbol)) return;
    violations.add('$path: $symbol');
  }

  MethodDeclaration? _method(AstNode node) {
    for (AstNode? cursor = node; cursor != null; cursor = cursor.parent) {
      if (cursor is MethodDeclaration) return cursor;
    }
    return null;
  }

  bool _signerAllowance(AstNode node, Element element) {
    final method = _method(node);
    AstNode? owner = method?.parent;
    while (owner != null && owner is! ClassDeclaration) {
      owner = owner.parent;
    }
    if (method == null || owner is! ClassDeclaration) return false;
    if (path == 'packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart' &&
        owner.namePart.typeName.lexeme == 'BitcoinSigner' &&
        method.name.lexeme == '_wallet') {
      final proof = _SignerMemoryProof();
      method.accept(proof);
      return proof.valid && proof.allows(element, node);
    }
    if (path != 'packages/secrets/lib/src/crypto/signers/liquid_signer.dart' ||
        owner.namePart.typeName.lexeme != 'LiquidSigner') {
      return false;
    }
    if (method.name.lexeme == 'signPset') {
      final proof = _ScratchProof();
      method.accept(proof);
      final invocation = node is MethodInvocation ? node : node.parent;
      if (invocation is! MethodInvocation) return false;
      if (element.library?.uri.toString() == 'dart:io' &&
          {'delete', 'deleteSync'}.contains(element.name)) {
        return proof.temporaryTarget(invocation.target);
      }
      if (element.enclosingElement?.name != 'Wallet' ||
          element.name != 'init') {
        return false;
      }
      final arguments = invocation.argumentList.arguments
          .whereType<NamedArgument>()
          .where((arg) => arg.name.lexeme == 'dbpath');
      return arguments.length == 1 &&
          proof.temporaryPath(arguments.single.argumentExpression);
    }
    if (method.name.lexeme == 'sweepStale' &&
        element.library?.uri.toString() == 'dart:io' &&
        {'delete', 'deleteSync'}.contains(element.name)) {
      final invocation = node is MethodInvocation ? node : node.parent;
      if (invocation is! MethodInvocation ||
          invocation.target is! SimpleIdentifier) {
        return false;
      }
      final target = invocation.target as SimpleIdentifier;
      for (
        AstNode? parent = node;
        parent != null && parent != method;
        parent = parent.parent
      ) {
        if (parent is ForStatement &&
            parent.forLoopParts is ForEachPartsWithDeclaration) {
          final parts = parent.forLoopParts as ForEachPartsWithDeclaration;
          final iterable = parts.iterable;
          if (parts.loopVariable.declaredFragment?.element != target.element ||
              iterable is! MethodInvocation) {
            continue;
          }
          final resolved = iterable.methodName.element;
          return resolved?.library?.uri.toString() == 'dart:io' &&
              resolved?.name == 'list' &&
              target.staticType?.getDisplayString() == 'Directory';
        }
      }
    }
    return false;
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
        element != null &&
        !_signerAllowance(node, element) &&
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
          return uri == 'package:rust_bindings/bdk.dart' ||
              uri == 'package:rust_bindings/lwk.dart';
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
    final args = list.arguments.whereType<NamedArgument>().where(
      (arg) => arg.name.lexeme == 'persister',
    );
    if (args.length != 1) return false;
    final value = args.single.argumentExpression;
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
            'revealNextAddress',
            'revealAddressesTo',
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

/// Prove the nullable local used by the signer is assigned exactly once, from
/// newInMemory. Native mutations remain forbidden even in this method.
class _SignerMemoryProof extends RecursiveAstVisitor<void> {
  final Map<Element, int> assignments = {};
  final Set<Element> memory = {};
  bool valid = true;

  void _assignment(Element? variable, Expression? value) {
    if (variable == null || value == null) return;
    assignments.update(variable, (count) => count + 1, ifAbsent: () => 1);
    if (value is InstanceCreationExpression) {
      final constructor = value.constructorName.element;
      if (constructor?.library.uri.toString().startsWith('package:bdk_dart/') ==
              true &&
          constructor?.enclosingElement.name == 'Persister' &&
          constructor?.name == 'newInMemory') {
        memory.add(variable);
      }
    }
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _assignment(node.declaredFragment?.element, node.initializer);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide;
    if (left is SimpleIdentifier) _assignment(left.element, node.rightHandSide);
    super.visitAssignmentExpression(node);
  }

  bool _memoryArgument(ArgumentList arguments) {
    final values = arguments.arguments.whereType<NamedArgument>().where(
      (arg) => arg.name.lexeme == 'persister',
    );
    if (values.length != 1) return false;
    final value = values.single.argumentExpression;
    return value is SimpleIdentifier &&
        memory.contains(value.element) &&
        assignments[value.element] == 1;
  }

  bool allows(Element element, AstNode node) {
    if (!(element.library?.uri.toString().startsWith('package:bdk_dart/') ??
        false)) {
      return false;
    }
    final owner = element.enclosingElement?.name;
    if (element.name == 'Persister' || element.name == 'PersisterInterface') {
      return true;
    }
    if (owner == 'Persister' &&
        element is ConstructorElement &&
        element.name == 'newInMemory') {
      return memory.any((local) => assignments[local] == 1);
    }
    if ({'Persister', 'PersisterInterface'}.contains(owner) &&
        element.name == 'dispose') {
      final access = node.parent;
      final target = switch (access) {
        MethodInvocation() => access.target,
        PropertyAccess() => access.target,
        _ => null,
      };
      return target is SimpleIdentifier &&
          memory.contains(target.element) &&
          assignments[target.element] == 1;
    }
    if (owner == 'Wallet' &&
        element is ConstructorElement &&
        (element.name == null || element.name == 'new' || element.name == '')) {
      final constructor = node is ConstructorName ? node : node.parent;
      return constructor is ConstructorName &&
          constructor.parent is InstanceCreationExpression &&
          _memoryArgument(
            (constructor.parent as InstanceCreationExpression).argumentList,
          );
    }
    return false;
  }
}

class _ScratchProof extends RecursiveAstVisitor<void> {
  final Set<Element> temporary = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    var value = node.initializer;
    if (value is AwaitExpression) value = value.expression;
    final list = node.parent;
    if (list is VariableDeclarationList &&
        list.isFinal &&
        value is MethodInvocation &&
        value.methodName.element?.library?.uri.toString() == 'dart:io' &&
        value.methodName.element?.name == 'createTemp') {
      final local = node.declaredFragment?.element;
      if (local != null) temporary.add(local);
    }
    super.visitVariableDeclaration(node);
  }

  bool temporaryTarget(Expression? target) =>
      target is SimpleIdentifier && temporary.contains(target.element);

  bool temporaryPath(Expression value) => switch (value) {
    PrefixedIdentifier(:final prefix, :final identifier) =>
      temporaryTarget(prefix) &&
          identifier.name == 'path' &&
          identifier.element?.library?.uri.toString() == 'dart:io',
    PropertyAccess(:final target, :final propertyName) =>
      temporaryTarget(target) &&
          propertyName.name == 'path' &&
          propertyName.element?.library?.uri.toString() == 'dart:io',
    _ => false,
  };
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
            ({
                  'persist',
                  'applyUpdate',
                  'applyUpdateEvents',
                  'revealNextAddress',
                  'revealAddressesTo',
                }.contains(name) ||
                element is ConstructorElement));
  }
  if (uri.startsWith('package:rust_bindings/src/rust/third_party/lwk/')) {
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
