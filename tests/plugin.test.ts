import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The machine files land side by side in core/scripts/plugins/nextcloud/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/nextcloud\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-nextcloud.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-nextcloud-project.sh'), /^# workspace-name: Nextcloud/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-nextcloud-occ.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, 'scripts/nextcloud-site.sh']) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the site script runs in the web container with the server\'s own occ, with every verb the functions call', () => {
  const src = read('scripts/nextcloud-site.sh');
  for (const verb of ['download', 'install', 'configure', 'accounts', 'cancel', 'empty', 'list', 'version', 'occ']) assert.match(src, new RegExp(`^    ${verb}\\)$`, 'm'), `nextcloud-site.sh has the verb ${verb}`);
  assert.match(src, /occ\(\) \{ php "\$SERVER\/occ" --no-interaction --no-ansi "\$@"; \}/, 'the server\'s own occ');
  assert.match(src, /OC_PASS="\$password" occ user:add --password-from-env/, 'a password reaches occ in its environment, never on a command line');
  assert.match(src, /SITE_PAYLOAD/, 'the payload comes on the first line of the input');
  assert.match(src, /P\["\$\{line%%=\*\}"\]/, 'each line of the payload is split by hand: read would drop a single trailing "="');
  assert.match(src, /sha256sum -c --quiet -/, 'the release tarball is checked against the sum the server publishes');
  assert.match(src, /appstoreenabled --value=false/, 'no app store: only the apps the release bundles');
  assert.match(src, /has_internet_connection --value=false/, 'no call to an outside service');
  assert.match(src, /app:disable firstrunwizard/, 'no first-run wizard');
  const functions = read('scripts/functions/fun-nextcloud.sh');
  for (const call of functions.matchAll(/nextcloud_site "?([a-z ]+?)"? [A-Z_]/g)) {
    for (const word of call[1].split(' ')) assert.match(src, new RegExp(`^    ${word}\\)$`, 'm'), `fun-nextcloud.sh calls the verb ${word}`);
  }
});

test('the functions carry the names the core\'s tools look for, and run the server the official way', () => {
  const src = read('scripts/functions/fun-nextcloud.sh');
  for (const fn of ['set_nextcloud_users', 'add_nextcloud_users', 'cancel_nextcloud_users', 'testing_configure_nextcloud', 'nextcloud_build', 'nextcloud_occ_tool']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(src, /--project-type=php --docroot=nextcloud --webserver-type=apache-fpm/, 'a PHP project served by Apache, from nextcloud/');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the project carries the Node.js of the workspace rule');
  assert.match(src, /apc\.enable_cli = 1/, 'APCu on the command line too: the site\'s local memory cache');
  assert.match(src, /php -f \/var\/www\/html\/nextcloud\/cron\.php/, 'background jobs by cron');
  assert.match(src, /ADMIN_USER="\$\{account_name\}" ADMIN_PASSWORD="\$\{account_pass\}"/, 'the workspace account is the administrator');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-nextcloud-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/nextcloud-tester.md');
  assert.match(tester, /Never create or delete an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'nextcloud', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-nextcloud.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
});
