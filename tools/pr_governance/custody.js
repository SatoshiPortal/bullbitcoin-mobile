'use strict';

// Changes that touch the boundary around users' seeds, and why each is flagged.
//
// One policy, two uses: `custody-check.js` fails `make checks` on the whole tree, and the
// `PR custody review` workflow comments on a pull request's added lines to ask the contributor why.

const MARKER = '<!-- bull-custody-review -->';

// The app's own secure key-value store predates packages/secrets and keeps the PIN and
// preferences in the same OS keystore; it refuses the package's key prefixes
// (`Secrets.reservedKeyPrefixes`). These files may import the plugin; any other importer is new.
const FSS_IMPORTERS_ALLOWED = new Set([
  'lib/core/storage/storage_locator.dart',
  'lib/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart',
  'test/core_test/storage/secure_storage_reserved_keys_test.dart',
]);

const inSecrets = (path) => path.startsWith('packages/secrets/');
const isDart = (path) => path.endsWith('.dart');
const isPubspec = (path) => /(^|\/)pubspec\.yaml$/.test(path);

const RULES = [
  {
    id: 'seal-ignore',
    applies: isDart,
    matches: (text) => /\bignore(_for_file)?\s*:.*\binvalid_use_of_internal_member\b/.test(text),
    why: 'silences `invalid_use_of_internal_member`, the analyzer seal on package:secrets (`Secret.revealMnemonic`, every constructor the package does not export)',
  },
  {
    id: 'fss-import',
    applies: (path) => isDart(path) && !inSecrets(path) && !FSS_IMPORTERS_ALLOWED.has(path),
    matches: (text) => /^\s*(import|export)\s+['"]package:flutter_secure_storage/.test(text),
    why: 'reaches the OS keystore that holds the seeds from outside packages/secrets',
  },
  {
    id: 'secrets-src-import',
    applies: (path) => isDart(path) && !inSecrets(path),
    matches: (text) => /^\s*(import|export)\s+['"]package:secrets\/src\//.test(text),
    why: 'imports package:secrets internals instead of `package:secrets/secrets.dart`',
  },
  {
    id: 'fss-dependency',
    applies: (path) => isPubspec(path) && path !== 'packages/secrets/pubspec.yaml' && path !== 'pubspec.yaml',
    matches: (text) => /^\s*flutter_secure_storage(_[a-z_]+)?\s*:/.test(text),
    why: 'adds a dependency on the keystore plugin outside packages/secrets',
  },
];

const relevant = (path) => RULES.some((rule) => rule.applies(path));

function check(path, line, text) {
  return RULES.filter((rule) => rule.applies(path) && rule.matches(text)).map((rule) => ({ rule: rule.id, path, line, text: text.trim(), why: rule.why }));
}

// Added lines of a pull request, from the REST `pulls.listFiles` entries ({ filename, status, patch }).
function reviewFiles(files) {
  const findings = [];
  const uninspected = [];
  for (const file of files || []) {
    const path = file.filename;
    if (!relevant(path) || file.status === 'removed') continue;
    if (typeof file.patch !== 'string') {
      uninspected.push(path); // GitHub omits the patch of large diffs
      continue;
    }
    let line = 0;
    for (const raw of file.patch.split('\n')) {
      const hunk = /^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(raw);
      if (hunk) {
        line = Number(hunk[1]);
      } else if (raw.startsWith('+')) {
        findings.push(...check(path, line, raw.slice(1)));
        line++;
      } else if (!raw.startsWith('-') && !raw.startsWith('\\')) {
        line++;
      }
    }
  }
  return { findings, uninspected };
}

// Every line of every tracked file ({ path, text }), for the tree-wide gate.
function reviewTree(files) {
  const findings = [];
  for (const { path, text } of files || []) {
    if (!relevant(path)) continue;
    text.split('\n').forEach((content, index) => findings.push(...check(path, index + 1, content)));
  }
  return findings;
}

const cell = (text) => '`' + text.replace(/`/g, "'").replace(/\|/g, '\\|') + '`';

// The PR comment, or null when there is nothing to say and no earlier comment to update.
function commentBody({ findings, uninspected }, { hadComment = false } = {}) {
  if (findings.length === 0 && uninspected.length === 0) {
    return hadComment ? `${MARKER}\n### Custody review\n\nNo change to the custody boundary remains in this pull request. Thank you.` : null;
  }
  const lines = [
    MARKER,
    '### Custody review',
    '',
    'This pull request touches the boundary around users\' seeds. Could you explain, in a reply, why each change below is needed? A maintainer reviews it before merge, and a safer route usually exists: `package:secrets/secrets.dart` is the only supported way to reach seed material, and the app\'s own secure store is `KeyValueStorageDatasource`.',
    '',
  ];
  if (findings.length > 0) {
    lines.push('| file | line | change | why it is flagged |', '|---|---|---|---|');
    for (const f of findings) lines.push(`| ${cell(f.path)} | ${f.line} | ${cell(f.text)} | ${f.why} |`);
    lines.push('');
  }
  if (uninspected.length > 0) {
    lines.push('These files could not be inspected, because GitHub does not return a diff this large; please say whether they touch the keystore or the package seal:', '');
    for (const path of uninspected) lines.push(`- ${cell(path)}`);
    lines.push('');
  }
  return lines.join('\n');
}

module.exports = { MARKER, FSS_IMPORTERS_ALLOWED, RULES, reviewFiles, reviewTree, commentBody };
