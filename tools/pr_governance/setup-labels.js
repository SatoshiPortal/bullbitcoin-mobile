'use strict';

const labels = [
  ['ready', 'Ready for implementation by any contributor', '0E8A16'],
  ['no-issue-needed', 'This pull request is exempt from the issue readiness policy', '5319E7'],
  ['not-ready', 'A local open ready issue is required before implementation', 'D93F0B'],
  ['stale', 'No qualifying human activity recently; positive queue reminder or closure', 'FBCA04'],
];

if (require.main === module) {
  if (!process.argv.includes('--apply')) {
    console.log('Dry run: would ensure these labels exist:');
    labels.forEach(([name, description, color]) => console.log(`${name}: ${description} (${color})`));
    console.log('Pass --apply with gh authenticated to mutate labels.');
    process.exit(0);
  }
  if (!process.env.GITHUB_REPOSITORY) throw new Error('GITHUB_REPOSITORY is required with --apply');
  const { execFileSync } = require('node:child_process');
  for (const [name, description, color] of labels) {
    execFileSync('gh', ['label', 'create', name, '--repo', process.env.GITHUB_REPOSITORY, '--description', description, '--color', color, '--force'], { stdio: 'inherit' });
  }
}

module.exports = { labels };
