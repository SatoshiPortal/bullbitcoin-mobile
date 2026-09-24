'use strict';

// Tree-wide custody gate for `make checks` and CI: every tracked Dart file and pubspec, every line.
const { execFileSync } = require('node:child_process');
const { readFileSync, existsSync } = require('node:fs');
const { reviewTree } = require('./custody');

const paths = execFileSync('git', ['ls-files', '--', '*.dart', '*pubspec.yaml'], { encoding: 'utf8' }).split('\n').filter(Boolean);
const files = paths.filter((path) => existsSync(path)).map((path) => ({ path, text: readFileSync(path, 'utf8') }));
const findings = reviewTree(files);
if (findings.length > 0) {
  for (const f of findings) console.error(`${f.path}:${f.line}: ${f.text}\n  ${f.why}`);
  console.error(`\n${findings.length} custody finding(s): see tools/pr_governance/custody.js`);
  process.exit(1);
}
console.log(`custody boundary holds across ${files.length} files`);
