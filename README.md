# @webship.co/workspace-nextcloud

Nextcloud for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a real
Nextcloud file and collaboration server in containers (the release tarball, its SHA-256 sum checked, installed with
its own installer on the project's database, with only the apps the release bundles), a tool for the server's own
command-line tool (occ), the default accounts, the [Nextcloud step pack](https://github.com/webship/nextcloud-steps)
wired into the workspace's testing setup, and its AI items — two agents, a skill, a command and two prompts — each
listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a Nextcloud site is a row like any other, so the row menus the
core draws (start, stop, launch, clone, remove, tests) work on it unchanged, but for its accounts: its row has no
Users menu, and the test users items of its Tests menu are not for it. See [The default accounts](#the-default-accounts).

It is made from the reference platform plugin, `@webship.co/workspace-wordpress`, and runs its server the way the
Moodle plugin runs its learning site: a project of DDEV type `php`, the release package unpacked by the build and
installed with the platform's own command-line installer.

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-nextcloud --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate nextcloud --with-needs                         # plugins.nextcloud in settings.yml
bash core/scripts/plugins.sh --install nextcloud                                       # commands, functions, args, AI items
bash core/scripts/plugins.sh --configure nextcloud                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is idempotent.
`--uninstall` removes what it placed; an AI item you edited stays. `--remove nextcloud` then takes the package out of
the dashboard.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-nextcloud-project.sh`, `cmd-tools-nextcloud-occ.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The agents `nextcloud-site-builder`, `nextcloud-tester` | `ai-agents/` |
| The skill `nextcloud-scenarios` | `ai-skills/` |
| The command `/nextcloud-test` | `ai-commands/` |
| The prompts `nextcloud-build-and-test`, `nextcloud-scenarios-for-an-area` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder and the tool: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate nextcloud --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install nextcloud
```

Everything the builder runs for a server runs in containers, through the container tool the workspace already
needs, and Python 3, which writes the testing setup's `cucumber.js` on the machine: the release tarball is fetched
and checked, unpacked and installed in the web container. The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-nextcloud-project.sh` | The builder, in the Build list as **Nextcloud (a file and collaboration server)**, installed into every sites folder |
| `commands/cmd-tools-nextcloud-occ.sh` | The server's command-line tool for one site: what the server is, an `occ` command, the default accounts, the files a test run left |
| `scripts/functions/fun-nextcloud.sh` | The bash functions behind both, sourced by bootstrap once installed; the names the core's tools look for (`set_nextcloud_users`, `add_nextcloud_users`, `cancel_nextcloud_users`, `testing_configure_nextcloud`) |
| `scripts/args/arg-nextcloud.sh`, `arg-nextcloud-occ.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/nextcloud-site.sh` | Run by bash in the web container with the server's own `occ`: the release fetched and checked, the installer, the settings for testing, the default accounts, their files, their listing (the same script the step pack's test site is built with) |
| `testing/site.feature` | The first feature a site gets when testing is set up |
| `ai/agents/nextcloud-site-builder.md` | The agent that builds and maintains file servers with these commands |
| `ai/agents/nextcloud-tester.md` | The agent that writes and runs scenarios with the Nextcloud step pack |
| `ai/skills/nextcloud-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real server, three example features |
| `ai/commands/nextcloud-test.md` | The slash command `/nextcloud-test <site>`: set up, match every step, run, report |
| `ai/prompts/nextcloud-build-and-test.md`, `nextcloud-scenarios-for-an-area.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Nextcloud here |
| `features/nextcloud.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## What is different from the reference

DDEV has no project type for Nextcloud, and its official way to install is the release tarball and its own
command-line installer. The plugin keeps the shape of the reference and changes only this:

| | WordPress (the reference) | Nextcloud |
| --- | --- | --- |
| Project | `--project-type=wordpress`, nginx and PHP | `--project-type=php --docroot=nextcloud --webserver-type=apache-fpm`: Apache, so the release's own `.htaccess` rules give short addresses (`/apps/files`, not `/index.php/apps/files`); PHP 8.4 (the release takes 8.3 to 8.5) with APCu on the command line too |
| Recognised by | The DDEV project type | The file `.ddev/config.nextcloud.yaml` (with the release, and the daemon that runs the background jobs) |
| Getting the code | `wp core download` | The release tarball from download.nextcloud.com at `--nextcloud-version` (35.0.3 by default, or a major line for its newest release), its SHA-256 sum checked against the one the server publishes, unpacked in `nextcloud/`; the data folder `data/` sits beside it, outside the docroot |
| Install | `wp core install` | `--install`: `occ maintenance:install` on the project's database with the workspace account as the administrator, then the settings for testing (below) |
| Database | The container tool's | The same (MariaDB) |
| Mail | The container tool's mail catcher | The same: the site sends to the web container's Mailpit (`127.0.0.1:1025`), read at `https://<name>.ddev.site:8026` |
| Background jobs | WordPress's own | `occ background:cron`, and a daemon of the web container that runs `cron.php` every five minutes |
| Accounts | WP-CLI | `scripts/nextcloud-site.sh`, with the server's own `occ` (`user:add` with the password in its environment) and the server's API for the display name and the email |
| Removing it | `ddev delete` | The same |
| Users menu of the row | Reads the project type | None (the type is `php`; the Tests menu's test users items hand it the Webship list): the occ tool's `--add-users`, or `cmd-tools-add-users.sh <name> nextcloud` |

The settings for testing that `--install` writes: the site's address behind the router (`trusted_domains`,
`overwrite.cli.url`, `overwriteprotocol` https), short addresses, a local memory cache (APCu), no app store (only the
apps the release bundles), no first-run wizard, new accounts start with no files and no templates, no connection to
the internet (no update check, no news, no lookup server), the mail to the mail catcher, background jobs by cron,
and the throttling of failed logins and the rate limits off (every request reaches the server from the router's
address, so the failed logins of a test run would slow down every later login, and the server sends an account at most
five password reset mails in thirty minutes).

No public domain, no hosted service and no account anywhere: the site answers at `https://<name>.ddev.site` through
the container tool's router.

## The commands

Run them from a sites folder. `--help` is safe on both.

### Build a site

```bash
cd ~/workspace/dev
bash cmd-nextcloud-project.sh myfiles --install --add-users
```

| Flag | What it does |
| --- | --- |
| `--install` | Install the server with its own installer, the workspace account as its administrator, and set it up for testing |
| `--add-users` | With `--install`: add the default accounts |
| `--nextcloud-version <v>` | The release: `35.0.3` by default, or a major line (`34`) for its newest release |
| `--php-version <v>` | The PHP of the web container: `8.4` by default (`8.3` and `8.5` too) |
| `--launch` | Open the site when it is ready |

The site answers at `https://myfiles.ddev.site` and the mail catcher at `https://myfiles.ddev.site:8026`. Without
`--install` the release is unpacked but not installed: the site shows its installer. A project of the same name is
deleted first, with its database.

A build takes a few minutes (the release tarball is about 240 MB, the site about 1 GB on disk). Check the free
memory and disk first (`free -g`, `df -h`), and build one site at a time on a machine others use.

### Work on a site

```bash
bash cmd-tools-nextcloud-occ.sh myfiles                              # version, addresses, accounts
bash cmd-tools-nextcloud-occ.sh myfiles --occ "status"
bash cmd-tools-nextcloud-occ.sh myfiles --occ "app:list"
bash cmd-tools-nextcloud-occ.sh myfiles --occ "user:info editor"
bash cmd-tools-nextcloud-occ.sh myfiles --add-users                  # the default accounts
bash cmd-tools-nextcloud-occ.sh myfiles --cancel-users               # delete them
bash cmd-tools-nextcloud-occ.sh myfiles --empty-files                # take away their files (an interrupted test run's)
```

The occ commands run in the project's web container, as the web server's user; a password never goes on a command
line of the host.

### The default accounts

| Account | Address | Group | Handle in the tests |
| --- | --- | --- | --- |
| `administrator` | `administrator@example.com` | `admin` | `administrator` |
| `editor` | `editor@example.com` | none | `editor` |
| `user` | `user@example.com` | none | `user` |

The server logs in with the username or the email. Each account has the password of the workspace's other default
lists, and a display name (Administrator, Editor, User). They are for local sites and for tests; the administrator
from `--install` is the workspace account and is never written into a test.

**Manage them with the occ tool, not the dashboard's menus.** The dashboard picks a project's account list by its
type, and a Nextcloud site's type is `php`: its row has no Users menu, and the "Add the test users" and "Cancel the
test users" items of its Tests menu hand it the list of the Webship distribution, which starts by adding Drush to
the project with Composer. Leave those two items alone on a Nextcloud site until the base asks the plugins which
list a project takes (webship/workspace#490). Use:

```bash
bash cmd-tools-nextcloud-occ.sh myfiles --add-users      # add them, or give them back their password, email, display name and groups
bash cmd-tools-nextcloud-occ.sh myfiles --cancel-users   # delete them
bash cmd-tools-add-users.sh myfiles nextcloud            # the core's tool: the same list
bash cmd-tools-cancel-users.sh myfiles nextcloud
```

### Test a site

```bash
bash cmd-tools-testing.sh myfiles                 # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh myfiles --run           # run the suite in the container
bash cmd-tools-testing.sh myfiles --run --path tests/features/site.feature
```

`cmd-tools-testing.sh` is the workspace's own. For a Nextcloud site it also adds `@webship-js/nextcloud-steps` to
`package.json`, lists its step definitions in `cucumber.js` after webship-js's own, writes the mail catcher (the
project's own port in the web container, where the suite runs; `:8026` from the host), `dataAdmin` (the handle the
step pack uses for what only an administrator may do), the browser messages that are no error of a step, the users
registry (the handles above, by their usernames, with their display names, overridable with
`NEXTCLOUD_<HANDLE>_USERNAME` and `NEXTCLOUD_<HANDLE>_PASSWORD`), the tags that keep the pack's assertions that must
fail out of a normal run, and the site's address in place of the starter's `http://localhost:8080`. It places
`tests/features/site.feature` when the project has none, and makes sure an installed site has the default accounts.
Run it again and it adds what is missing and keeps what you changed.

Until `@webship-js/nextcloud-steps` is on npm, give the testing setup its tarball (`npm pack` of the pack) with
`bash cmd-tools-testing.sh myfiles --add-steps <path to the tarball>`, then run the setup again.

The suite runs in the project's container, where the network changes of the host (another container starting) do
not cut the browser's requests.

A scenario of your own reads like this one, from the step pack's phrases (the skill `nextcloud-scenarios` lists them
by area); the file it makes is taken away after it:

```gherkin
Feature: A deleted file comes back
  Scenario: The deleted files give it back
    Given "user" has the file "budget.txt"
    And I am a logged in user with the "user" user
    When I go to the files
    And I delete "budget.txt"
    And I go to the deleted files
    Then the deleted files should list "budget.txt"
    When I restore "budget.txt" from the deleted files
    And I go to the files
    Then the file list should show "budget.txt"
```

`tests/features/site.feature` passes on a site built with `--install --add-users`, and so do the features of the
step pack.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and `--install` places
it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `nextcloud-site-builder` | Build, maintain or remove a file server with the commands above, in containers only |
| Agent | `nextcloud-tester` | Set the testing stack up, look at the apps in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `nextcloud-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the test-data steps, the traps found on a real server, and three features that pass on a site with the default accounts |
| Command | `/nextcloud-test <site> [feature or @tag]` | Run the suite of a site from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `nextcloud-build-and-test` | Start a session that builds a site, says what it is, sets the testing stack up and runs the first feature |
| Prompt | `nextcloud-scenarios-for-an-area` | Start a session that writes and runs the scenarios of one area of the server |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill or a command into
Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh nextcloud-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh nextcloud-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh nextcloud-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the dashboard's **New
screen** form lists it as a template. By hand, fill the placeholders in and run the command of the file from the
folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and the file layout are
Claude Code's, the body of each item is plain Markdown that names no tool or feature of one CLI, a command says in
words what its arguments are, and the text between the triple quotes of a prompt can be given to another AI CLI as it
is.

Every step phrase the items show is checked against the definitions of the step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the commands, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 20 and 24, parses every shell script, and runs the plugin's `features/nextcloud.feature`
against a dashboard with this plugin installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).
