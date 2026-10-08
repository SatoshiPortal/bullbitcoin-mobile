import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

/// A resolved-symbol boundary, not a whole-program secret-flow analysis.
///
/// Imports, re-exports, aliases and tear-offs resolve to the declaration being
/// used. The test keystore is also forbidden in production consumers.
/// Validation, word lists, mnemonic formatting and public-key derivation
/// remain available to the app. New cryptographic dependencies or APIs require
/// updating this policy; arbitrary cryptography and dynamic dispatch are not
/// proven safe by this gate. Analysis errors fail closed.
Future<void> main(List<String> arguments) async {
  final root = Directory(arguments.isEmpty ? '.' : arguments.single).absolute;
  final report = await checkKeyMaterial(root.path);
  for (final violation in report.violations) {
    stderr.writeln(violation);
  }
  stdout.writeln(
    'Key-material boundary: ${report.fileCount} files, '
    '${report.violations.length} violations',
  );
  if (report.violations.isNotEmpty) exitCode = 1;
  // A root that yields no file proves nothing; a green report on it would be
  // a gate that silently stopped looking.
  if (report.fileCount == 0) {
    stderr.writeln('Key-material boundary: no production Dart file found');
    exitCode = 1;
  }
}

class KeyMaterialReport {
  final int fileCount;
  final List<String> violations;

  const KeyMaterialReport(this.fileCount, this.violations);
}

Future<KeyMaterialReport> checkKeyMaterial(String rootPath) async {
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
  return KeyMaterialReport(files.length, violations.toSet().toList()..sort());
}

List<String> productionDartFiles(String root) {
  final roots = <Directory>[Directory('$root/lib')];
  for (final group in ['packages', 'features']) {
    final parent = Directory('$root/$group');
    if (!parent.existsSync()) continue;
    for (final member in parent.listSync(followLinks: false)) {
      if (member is Directory && member.path != '$root/packages/secrets') {
        roots.add(Directory('${member.path}/lib'));
      }
    }
  }
  // Every Dart file under a production `lib/` is checked, generated or not: a
  // name or a directory says nothing about who wrote a file, and generated
  // code references none of the forbidden symbols.
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
  final visitor = _KeyMaterialVisitor(relativePath);
  unit.accept(visitor);
  return visitor.violations.toList()..sort();
}

class _KeyMaterialVisitor extends RecursiveAstVisitor<void> {
  final String path;
  final Set<String> violations = {};

  _KeyMaterialVisitor(this.path);

  void check(Element? element, AstNode node) {
    if (element == null) {
      if (node is SimpleIdentifier &&
          _unresolvedSensitiveMembers.contains(node.name) &&
          (node.parent is PropertyAccess ||
              node.parent is PrefixedIdentifier ||
              node.parent is MethodInvocation ||
              node.parent is DotShorthandInvocation)) {
        violations.add('$path: unresolved sensitive member ${node.name}');
      }
      return;
    }
    final symbol = materialSymbol(element);
    if (symbol == null || _isException(path, node, symbol)) {
      return;
    }
    violations.add('$path: $symbol');
  }

  void checkTestingLibrary(String? uri) {
    if (uri != null && _isTestingLibrary(uri)) {
      violations.add('$path: $uri#test-only library');
    }
  }

  @override
  void visitImportDirective(ImportDirective node) {
    checkTestingLibrary(node.libraryImport?.importedLibrary?.uri.toString());
    checkTestingLibrary(node.uri.stringValue);
    for (final configuration in node.configurations) {
      checkTestingLibrary(configuration.uri.stringValue);
    }
    super.visitImportDirective(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    checkTestingLibrary(node.libraryExport?.exportedLibrary?.uri.toString());
    checkTestingLibrary(node.uri.stringValue);
    for (final configuration in node.configurations) {
      checkTestingLibrary(configuration.uri.stringValue);
    }
    super.visitExportDirective(node);
  }

  void checkChannel(String? value) {
    if (value == 'plugins.it_nomads.com/flutter_secure_storage') {
      violations.add('$path: flutter_secure_storage platform channel');
    }
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    checkChannel(node.stringValue);
    super.visitAdjacentStrings(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    checkChannel(node.stringValue);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitCommentReference(CommentReference node) {}

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (!node.inDeclarationContext()) check(node.element, node);
    super.visitSimpleIdentifier(node);
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
}

// Dynamic or otherwise unresolved access to these sensitive entry points must
// be replaced by a statically resolved call. Generic names such as `sign` are
// deliberately absent: this is not a blanket ban on dynamic app data.
const _unresolvedSensitiveMembers = {
  'seed',
  'fromSeed',
  'fromPrivateKey',
  'deriveHardened',
  'secretBytes',
  'newConfidential',
  'restoreBackup',
  'signedPsetWithExtraDetails',
  'signSilentPaymentPsbt',
  'dartBwkApiSpSignerSignSilentPaymentPsbt',
  'initMock',
};

const _dartBwk = 'package:bull_sdk/src/rust/third_party/dart_bwk/';
const _frbGenerated = 'package:bull_sdk/src/rust/frb_generated.dart';

bool _isTestingLibrary(String uri) =>
    uri == 'package:secrets/testing.dart' ||
    uri.startsWith('package:secrets/src/testing/');

String? materialSymbol(Element element) {
  final uri = element.library?.uri.toString();
  if (uri != null &&
      (uri.startsWith('package:flutter_secure_storage') ||
          (uri.startsWith('package:secrets/') &&
              element.metadata.hasInternal))) {
    return '$uri#${element.enclosingElement?.name}.${element.name}';
  }
  if (uri != null && _isTestingLibrary(uri)) {
    return '$uri#${element.name}';
  }
  if (element is! ExecutableElement || uri == null) return null;
  final owner = element.enclosingElement?.name;
  final member = element.name;
  final symbol = '$owner.$member';
  final forbidden = switch (uri) {
    _ when uri.startsWith('package:bip39_mnemonic/') =>
      symbol == 'Mnemonic.seed',
    _ when uri.startsWith('package:bip32_keys/') =>
      owner == 'Bip32Keys' &&
          {
            'new',
            'fromSeed',
            'fromBase58',
            'fromPrivateKey',
            'private',
            'deriveHardened',
            'sign',
            'toWIF',
          }.contains(member),
    _ when uri.startsWith('package:bip85_entropy/') =>
      owner == 'Bip85Entropy' && (member?.startsWith('derive') ?? false),
    _ when uri.startsWith('package:bdk_dart/') =>
      {'DescriptorSecretKey', 'DescriptorSecretKeyInterface'}.contains(owner) ||
          (owner == 'Mnemonic' && element is ConstructorElement) ||
          (owner == 'Descriptor' &&
              {
                'newBip44',
                'newBip49',
                'newBip84',
                'newBip86',
              }.contains(member)),
    _ when uri.startsWith('package:bull_sdk/src/rust/third_party/lwk/') =>
      symbol == 'Descriptor.newConfidential' ||
          {
            'Wallet.signTx',
            'Wallet.signedPsetWithExtraDetails',
          }.contains(symbol),
    _ when uri.startsWith('package:bull_sdk/src/rust/third_party/boltz/') =>
      owner == 'SwapMasterKey' &&
          {'new', 'create', 'xprv', 'mnemonic'}.contains(member),
    // bwk's silent payments signer takes the spend key and the taproot
    // account xprv: only the package derives them, and only the package may
    // hand them to it. The account itself holds no spend authority.
    _ when uri.startsWith(_dartBwk) => member == 'signSilentPaymentPsbt',
    // The same signer reached through the generated FFI entry point, and the
    // mock seam that would route every FFI call, the lent keys included,
    // to a Dart object.
    _ when uri == _frbGenerated =>
      member == 'dartBwkApiSpSignerSignSilentPaymentPsbt' ||
          symbol == 'BullSdk.initMock',
    _ when uri.startsWith('package:recoverbull/') =>
      symbol == 'RecoverBull.restoreBackup' ||
          symbol == 'EncryptionService.decrypt',
    _ => false,
  };
  return forbidden ? '$uri#$symbol' : null;
}

bool _isException(String path, AstNode node, String symbol) {
  String? function;
  String? owner;
  for (AstNode? current = node; current != null; current = current.parent) {
    if (current is FunctionDeclaration) function = current.name.lexeme;
    if (current is MethodDeclaration) function = current.name.lexeme;
    if (current is ConstructorDeclaration) {
      function = current.name?.lexeme ?? 'new';
    }
    if (current is ClassDeclaration) owner = current.namePart.typeName.lexeme;
  }
  final member = symbol.split('#').last;
  // This adapter replaces version bytes with the public xpub version before
  // decoding. Elsewhere this mixed decoder could import private extended keys.
  if (path == 'lib/core/utils/bip32_derivation.dart' &&
      owner == 'Bip32Derivation' &&
      function == 'getBip32Xpub' &&
      member == 'Bip32Keys.fromBase58') {
    return true;
  }
  // Pre-import discovery operates on user input before there is a stored Secret.
  if (path == 'lib/core/wallet/data/datasources/bdk_wallet_datasource.dart' &&
      function == '_performDryScan' &&
      owner == null) {
    return {
      'Mnemonic.fromEntropy',
      'DescriptorSecretKey.new',
      'Descriptor.newBip44',
      'Descriptor.newBip49',
      'Descriptor.newBip84',
    }.contains(member);
  }
  // The exported swap master key is a documented, independent child secret.
  if (path == 'lib/core/swaps/data/models/swap_master_key_model.dart' &&
      owner == 'SwapMasterKeyModel') {
    return (function == 'fromBoltz' &&
            {
              'SwapMasterKey.xprv',
              'SwapMasterKey.mnemonic',
            }.contains(member)) ||
        (function == 'toBoltz' && member == 'SwapMasterKey.new');
  }
  return false;
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
