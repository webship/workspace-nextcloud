/**
 * Nextcloud for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the server's command-line
 * tool (occ) in the sites folders, their functions and argparse under core/scripts/plugins/nextcloud/ (with
 * nextcloud-site.sh, which the builder and the tool run in the web container with the server's own occ), and its AI
 * items (ai/ in this package) in the folder of their kind: the agents in AI Agents, the skill in AI Skills, the
 * command in AI Commands, the prompts in AI Prompts. The dashboard needs nothing drawn for it: the builder is in the
 * Build list because it is a cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other.
 * What register() adds is what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/** The plugin's name. A Nextcloud site is a DDEV project of type php: the plugin knows it by .ddev/config.nextcloud.yaml. */
export const PLATFORM = 'nextcloud';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-nextcloud-project.sh', 'cmd-tools-nextcloud-occ.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['nextcloud-site-builder', 'nextcloud-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['nextcloud-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['nextcloud-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['nextcloud-build-and-test', 'nextcloud-scenarios-for-an-area'];

/** What the assistant is told about Nextcloud in this workspace. */
export function assistantContext(): string {
  return [
    'Nextcloud (a plugin, @webship.co/workspace-nextcloud): a file and collaboration server is built with',
    '`bash cmd-nextcloud-project.sh <name> --install --add-users` from a sites folder (dev, test, sandboxes, demos):',
    'a DDEV project of type php served by Apache, the release tarball from download.nextcloud.com (its SHA-256 sum checked) unpacked in nextcloud/ (the docroot) with its data folder data/ beside it,',
    'installed with its own installer (occ maintenance:install) on the project\'s database, at https://<name>.ddev.site, its mail to the project\'s mail catcher (https://<name>.ddev.site:8026), background jobs by cron;',
    '`--install` makes the workspace account the administrator and sets the site up for testing (only the apps the release bundles, no app store, no first-run wizard, new accounts with no files, no connection to the internet),',
    '`--add-users` adds the default accounts (administrator, in the admin group; editor; user), `--nextcloud-version` takes a release (35.0.3 by default, or a major line such as 34), `--php-version` the PHP of the container.',
    '`bash cmd-tools-nextcloud-occ.sh <name>` says what the server is; `--occ "<command>"` runs the server\'s own command-line tool (occ) in the web container,',
    '`--add-users` and `--cancel-users` manage the default accounts, `--empty-files` takes away the files of the default accounts.',
    'The row\'s Users menu does not apply to a Nextcloud site (its project type is php): use the occ tool for the accounts.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Nextcloud step pack; `--run` runs the suite.',
    `For Nextcloud work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run occ or PHP on the host for a project; removing the project removes its database and its files.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
