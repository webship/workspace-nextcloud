import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-nextcloud.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['tsx/cjs'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

/**
 * A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled.
 * A site of this plugin has the builder's .ddev/config.nextcloud.yaml; an installed one, its config.php.
 */
function project(kind: 'nextcloud' | 'drupal', installed = true) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'nextcloud-plugin-'));
  const dir = path.join(root, 'dev', 'site1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: site1\ntype: ${kind === 'nextcloud' ? 'php' : 'drupal11'}\n`);
  if (kind === 'nextcloud') {
    fs.writeFileSync(path.join(dir, '.ddev', 'config.nextcloud.yaml'), 'web_environment:\n  - NEXTCLOUD_VERSION=35.0.3\n');
    fs.mkdirSync(path.join(dir, 'nextcloud', 'config'), { recursive: true });
    fs.writeFileSync(path.join(dir, 'nextcloud', 'version.php'), "<?php\n$OC_VersionString = '35.0.3';\n");
    if (installed) fs.writeFileSync(path.join(dir, 'nextcloud', 'config', 'config.php'), "<?php\n$CONFIG = array (\n  'installed' => true,\n);\n");
  }
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'site1', devDependencies: { 'webship-js': '^2.0.6' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  const plugin = path.join(scripts, 'plugins', 'nextcloud');
  fs.mkdirSync(plugin, { recursive: true });
  for (const f of ['testing/site.feature', 'scripts/nextcloud-site.sh']) fs.copyFileSync(path.join(PKG, f), path.join(plugin, path.basename(f)));
  return { root, dir, scripts };
}

/**
 * Run bash with the plugin's functions sourced and `ddev` replaced by a recorder of its calls and of what it reads
 * on stdin: the first line whole (`stdin1:`), then the start of the rest (`stdin:`).
 */
function bash(script: string, env: Record<string, string> = {}) {
  const fake = 'ddev() { echo "ddev $*" >> "${DDEV_LOG:-/dev/null}" ; if [ ! -t 0 ] ; then IFS= read -r first ; echo "  stdin1: ${first}" >> "${DDEV_LOG:-/dev/null}" ; head -c 120 | sed "s/^/  stdin: /" >> "${DDEV_LOG:-/dev/null}" ; echo >> "${DDEV_LOG:-/dev/null}" ; fi ; return 0 ; }';
  return spawnSync('bash', ['-c', `${fake}\nsource ${FUNCTIONS}\n${script}`], { encoding: 'utf8', env: { ...process.env, ...env } });
}

/** The payload a recorded call of nextcloud-site.sh carried: on the first line of its standard input, never on its command line. */
function payloadOf(recorded: string, verbs: string) {
  const lines = recorded.split('\n');
  const call = lines.findIndex((l) => l === `ddev exec SITE_VERBS='${verbs}' bash -s`);
  assert.ok(call >= 0, `a call of the site script with the verbs "${verbs}": ${recorded}`);
  const m = (lines[call + 1] || '').match(/^  stdin1: SITE_PAYLOAD='([A-Za-z0-9+/=]+)'$/);
  assert.ok(m, `the first line of its input carries the payload: ${lines[call + 1]}`);
  const out: Record<string, string> = {};
  for (const line of Buffer.from(m![1], 'base64').toString('utf8').split('\n').filter(Boolean)) {
    const at = line.indexOf('=');
    out[line.slice(0, at)] = Buffer.from(line.slice(at + 1), 'base64').toString('utf8');
  }
  return out;
}

const OWNER = { account_name: 'owner1', account_mail: 'owner1@example.com', account_pass: 'Owner-pass-1234' };

test('the default accounts are an administrator, an editor and a user, with example addresses', () => {
  const r = bash('set_nextcloud_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; d="user_${u}_display" ; g="user_${u}_role" ; echo "${!n}|${!m}|${!p}|${!d}|${!g}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['administrator', 'editor', 'user']);
  assert.deepStrictEqual(rows.map((x) => x[3]), ['Administrator', 'Editor', 'User']);
  assert.deepStrictEqual(rows.map((x) => x[4]), ['admin', '', '']);
  for (const [name, mail, password] of rows) {
    assert.strictEqual(mail, `${name}@example.com`);
    assert.ok(password.length >= 10, 'a password the password policy accepts');
  }
});

test('the accounts are written by the site script with occ, in the web container, never on a command line or in a file', () => {
  const p = project('nextcloud');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_nextcloud_users ; add_nextcloud_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const recorded = fs.readFileSync(log, 'utf8');
  assert.match(recorded, /stdin: # The site script of the file server/, 'the script goes in on stdin');
  assert.doesNotMatch(recorded.split('\n').filter((l) => l.startsWith('ddev ')).join('\n'), /Owner-pass|dD\./, 'no password on a command line');
  const payload = payloadOf(recorded, 'accounts');
  assert.deepStrictEqual(payload.ACCOUNTS.trim().split('\n').map((l) => l.split('|').filter((_, i) => i !== 2)), [
    ['administrator', 'administrator@example.com', 'Administrator', 'admin'],
    ['editor', 'editor@example.com', 'Editor', ''],
    ['user', 'user@example.com', 'User', ''],
  ]);
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => !['.ddev', 'cucumber.js', 'package.json', 'nextcloud'].includes(f)), [], 'no file with a password is left in the project');
});

test('the accounts are not written to a site that is not installed', () => {
  const p = project('nextcloud', false);
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_nextcloud_users ; add_nextcloud_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not installed: build it with --install first/);
  assert.ok(!fs.existsSync(log), 'the container tool was never called');
});

test('cancelling the accounts deletes the default ones through the site script, never the workspace account', () => {
  const p = project('nextcloud');
  const log = path.join(p.root, 'ddev.log');
  const r = bash('set_nextcloud_users ; users+=(owner1) ; user_owner1_name=owner1 ; cancel_nextcloud_users', { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const payload = payloadOf(fs.readFileSync(log, 'utf8'), 'cancel');
  assert.deepStrictEqual(payload.USERNAMES.trim().split('\n'), ['administrator', 'editor', 'user']);
});

test('the builder refuses a release it does not know, a PHP the release does not take, a bad name, and the options that need --install, before it changes anything', () => {
  const p = project('nextcloud');
  const log = path.join(p.root, 'ddev.log');
  const base = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', DDEV_LOG: log, ...OWNER };
  const stub = 'trim_project_name() { :; } ; drop_database() { echo dropped ; } ;';
  const cases: Array<[string, RegExp]> = [
    [`PROJECT_NAME=site1 ; NEXTCLOUD_VERSION="beta" ;`, /--nextcloud-version takes a release \(35\.0\.3\) or a major line \(35\), not beta\. Nothing was changed\./],
    [`PROJECT_NAME=site1 ; PHP_VERSION="8.1" ;`, /--php-version takes 8\.3, 8\.4 or 8\.5/],
    [`PROJECT_NAME=site1 ; ADD_USERS=yes ; INSTALL=no ;`, /--add-users needs --install/],
    [`PROJECT_NAME=Site_1 ;`, /must be small letters, digits and dashes/],
    [`PROJECT_NAME=site1 ; INSTALL=yes ; account_pass="" ;`, /The workspace account's password is not set/],
  ];
  for (const [vars, message] of cases) {
    const r = bash(`${vars} ${stub} nextcloud_build`, base);
    assert.strictEqual(r.status, 1, `${vars}: ${r.stdout}`);
    assert.match(r.stdout, message);
    assert.doesNotMatch(r.stdout, /dropped/, 'nothing was deleted');
  }
  for (const ok of ['35.0.3', '34', '33.0.11']) {
    const r = bash(`PROJECT_NAME=site1 ; NEXTCLOUD_VERSION="${ok}" ; ADD_USERS=yes ; INSTALL=no ; ${stub} nextcloud_build`, base);
    assert.doesNotMatch(r.stdout, /--nextcloud-version takes/, `${ok} is a release the builder knows`);
  }
  assert.ok(!fs.existsSync(log), 'the container tool was never called');
});

test('the builder writes the PHP settings, the background jobs and the site\'s own settings file', () => {
  const p = project('nextcloud');
  const r = bash(`nextcloud_write_config ${p.dir} 35.0.3`);
  assert.strictEqual(r.status, 0, r.stderr);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'php', 'nextcloud.ini'), 'utf8'), /^apc\.enable_cli = 1$/m);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'nextcloud-cron.sh'), 'utf8'), /php -f \/var\/www\/html\/nextcloud\/cron\.php/);
  const settings = fs.readFileSync(path.join(p.dir, '.ddev', 'config.nextcloud.yaml'), 'utf8');
  assert.match(settings, /NEXTCLOUD_VERSION=35\.0\.3/);
  assert.match(settings, /web_extra_daemons:\n  - name: "nextcloud-cron"\n    command: "bash \/var\/www\/html\/\.ddev\/nextcloud-cron\.sh"/);
});

test('the testing hook adds the step pack, the mail catcher, the users registry, the data admin, the tags and a first feature, once', () => {
  const p = project('nextcloud');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_nextcloud ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1', DDEV_LOG: log, ...OWNER });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/nextcloud-steps'], '^2.0.0');
  assert.strictEqual(pkg.devDependencies['webship-js'], '^2.0.6', 'what was there stays');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/nextcloud-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /editor: \{ username: process\.env\.NEXTCLOUD_EDITOR_USERNAME \|\| 'editor', email: 'editor@example\.com', displayName: 'Editor', password: process\.env\.NEXTCLOUD_EDITOR_PASSWORD \|\| '[^']+' \},/);
  assert.match(cucumber, /dataAdmin: process\.env\.DATA_ADMIN \|\| 'administrator',/);
  assert.match(cucumber, /tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',/);
  assert.match(cucumber, /launchUrl: process\.env\.LAUNCH_URL \|\| 'https:\/\/site1\.ddev\.site',/);
  // Still a module node can load, with the registry and the mail catcher where the pack reads them.
  const load = (env: Record<string, string>) => spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; const w = c.worldParameters; console.log(JSON.stringify([c.require.length, Object.keys(w.users), c.tags, w.dataAdmin, w.mailUrl, w.javascript.mode]))`], { encoding: 'utf8', env: { ...process.env, CUCUMBER_TAGS: '', LAUNCH_URL: '', IS_DDEV_PROJECT: '', ...env } });
  const loaded = load({});
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, tags, admin, mail, mode] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires, 3);
  assert.deepStrictEqual(handles, ['administrator', 'editor', 'user']);
  assert.match(tags, /not @must-fail/);
  assert.strictEqual(admin, 'administrator');
  assert.strictEqual(mail, 'https://site1.ddev.site:8026', 'the mail catcher through the router, from the host');
  assert.strictEqual(mode, 'warn');
  assert.strictEqual(JSON.parse(load({ IS_DDEV_PROJECT: 'true' }).stdout)[4], 'http://127.0.0.1:8025', 'the mail catcher on its own port, in the web container');
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'site.feature')));
  assert.match(fs.readFileSync(log, 'utf8'), /SITE_VERBS='accounts' bash -s$/m, 'an installed site gets the default accounts');
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'site.feature'), 'utf8'), 'Feature: mine\n');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('drupal');
  const r = bash(`cd ${p.dir} && testing_configure_nextcloud ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'site1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
  assert.ok(!fs.existsSync(path.join(p.dir, 'tests')));
});

test('the occ tool refuses a project that is not a site of the plugin', () => {
  const p = project('drupal');
  const r = bash('PROJECT_NAME=site1 ; OCC="status" ; trim_project_name() { :; } ; nextcloud_occ_tool', { WORKSPACE_ROOT: p.root, doc_name: 'dev' });
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /is not a Nextcloud project of this plugin/);
});

test('the occ tool runs an occ command in the web container, its arguments in the payload', () => {
  const p = project('nextcloud');
  const log = path.join(p.root, 'ddev.log');
  const fake = `ddev() { case "$*" in describe*) echo '{"raw":{"status":"running"}}' ;; *) echo "ddev $*" >> "${log}" ; if [ ! -t 0 ] ; then IFS= read -r first ; echo "  stdin1: \${first}" >> "${log}" ; cat > /dev/null ; fi ;; esac ; return 0 ; }`;
  const r = spawnSync('bash', ['-c', `source ${FUNCTIONS}\n${fake}\nPROJECT_NAME=site1 ; OCC="user:info editor" ; trim_project_name() { :; } ; nextcloud_occ_tool`], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', ...OWNER } });
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
  const payload = payloadOf(fs.readFileSync(log, 'utf8'), 'occ');
  assert.strictEqual(payload.OCC_ARGS, 'user:info editor');
});

test('the first feature names no platform in a step, and no password', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'site.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /nextcloud/i, s);
  assert.doesNotMatch(feature, /dD\.123123ddd/);
  assert.doesNotMatch(feature, /try to create the account|Add new account/i, 'a first feature makes no account');
});
