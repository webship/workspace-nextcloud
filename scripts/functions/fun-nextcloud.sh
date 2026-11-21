#!/usr/bin/env bash

# Nextcloud for the Webship Workspace: build a file and collaboration server from its release tarball, run its
# command-line tool (occ), add its default accounts, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install nextcloud` in core/scripts/plugins/nextcloud/functions/, where bootstrap sources
# it after the core's own functions. Everything runs in containers (DDEV by default), never on the host: the
# release tarball is fetched and checked in the web container, unpacked in nextcloud/ (the docroot of a PHP project
# served by Apache, with the release's own rewrite rules) with its data folder data/ beside it, outside the docroot,
# and installed with its own installer on the project's database; the project's mail catcher takes its mail, and a
# daemon of the web container runs its background jobs (cron.php every five minutes). Only the apps the release
# bundles: no app store, no account anywhere.
#
# DDEV has no project type for Nextcloud, so a site of this plugin is recognised by a file
# (.ddev/config.nextcloud.yaml, written by the builder), and four names are the ones the core's tools look for:
#   set_nextcloud_users          the default accounts                (cmd-tools-add-users.sh <project> nextcloud)
#   add_nextcloud_users          create them with occ                (the same tool, and --add-users of the builder)
#   cancel_nextcloud_users       delete them                         (cmd-tools-cancel-users.sh <project> nextcloud)
#   testing_configure_nextcloud  the step pack in the testing stack  (cmd-tools-testing.sh <project>)

# The step pack a Nextcloud site is tested with, and the release line it is required at.
readonly NEXTCLOUD_STEPS_PACKAGE='@webship-js/nextcloud-steps';
readonly NEXTCLOUD_STEPS_VERSION='^2.0.0';

# The release the builder installs when none is asked for, and the PHP of the web container (the release takes 8.3
# to 8.5; DDEV offers 8.4).
readonly NEXTCLOUD_DEFAULT_VERSION='35.0.3';
readonly NEXTCLOUD_DEFAULT_PHP='8.4';

# The default accounts, the ones a scenario logs in as: an administrator (in the admin group), an editor and a user,
# each an account of its own. Accounts are configuration, created once on the site; a test suite never creates or
# deletes one. The administrator the installer makes with --install is the workspace account and is not in this list.
function set_nextcloud_users() {
  users=(administrator editor user);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
  done
  user_administrator_display='Administrator' ;
  user_editor_display='Editor' ;
  user_user_display='User' ;
  user_administrator_role='admin' ;
  user_editor_role='' ;
  user_user_role='' ;
}

# Is this folder a Nextcloud site of this plugin? The builder leaves .ddev/config.nextcloud.yaml in it.
function nextcloud_is_project() {
  [ -f "$1/.ddev/config.nextcloud.yaml" ] ;
}

# Is the site of a folder installed? Its installer writes nextcloud/config/config.php with 'installed' => true.
function nextcloud_is_installed() {
  grep -qs "'installed' => true" "${1:-.}/nextcloud/config/config.php" ;
}

# Go to the project a tool was asked about, or say why not.
function nextcloud_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! nextcloud_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Nextcloud project of this plugin (it has no .ddev/config.nextcloud.yaml)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The payload of nextcloud-site.sh: lines of KEY=base64(value), all of it in base64 again, from variables.
function nextcloud_payload() {
  local line="" key ;
  for key in "$@" ; do
    line="${line}${key}=$(printf '%s' "${!key}" | base64 -w0)"$'\n' ;
  done
  printf '%s' "${line}" | base64 -w0 ;
}

# Run verbs of nextcloud-site.sh with bash in the web container, with the payload on its first line: no password on
# the host's command line, in a file of the project, or in what a failed run prints.
function nextcloud_site() {
  local verbs="$1" ; shift ;
  local script="${WORKSPACE_SCRIPTS}/plugins/nextcloud/nextcloud-site.sh" ;
  if [ ! -f "${script}" ] ; then
    echo "nextcloud-site.sh is not in ${WORKSPACE_SCRIPTS}/plugins/nextcloud: install the plugin (plugins.sh --install nextcloud)." ;
    return 1 ;
  fi
  { printf "SITE_PAYLOAD='%s'\n" "$(nextcloud_payload "$@")"; cat "${script}"; } \
    | ddev exec "SITE_VERBS='${verbs}' bash -s" ;
}

# The default accounts (the list set_nextcloud_users loads) as the site script takes them: one line each,
# username|email|password|display name|groups.
function nextcloud_accounts_rows() {
  local user name mail password display role ;
  for user in "${users[@]}" ; do
    name="user_${user}_name"; mail="user_${user}_mail"; password="user_${user}_password";
    display="user_${user}_display"; role="user_${user}_role";
    printf '%s|%s|%s|%s|%s\n' "${!name}" "${!mail}" "${!password}" "${!display:-${!name}}" "${!role}" ;
  done
}

# The usernames of the default accounts, one per line.
function nextcloud_usernames() {
  local user name ;
  for user in "${users[@]}" ; do name="user_${user}_name" ; printf '%s\n' "${!name}" ; done
}

# Write the project's files for the server: its PHP settings, its background jobs, the site's own settings file.
function nextcloud_write_config() {
  local project_path="$1" version="$2" ;
  mkdir -p "${project_path}/.ddev/php" || return 1 ;
  cat > "${project_path}/.ddev/php/nextcloud.ini" <<'INIEOF'
; The PHP settings of the file server (written by the Nextcloud builder of the workspace).
apc.enable_cli = 1
memory_limit = 1024M
upload_max_filesize = 512M
post_max_size = 512M
INIEOF
  cat > "${project_path}/.ddev/nextcloud-cron.sh" <<'CRONEOF'
#!/usr/bin/env bash
# The background jobs of the file server: cron.php every five minutes, once the site is installed. Written by the
# Nextcloud builder of the workspace.
while true; do
  if grep -qs "'installed' => true" /var/www/html/nextcloud/config/config.php; then
    php -f /var/www/html/nextcloud/cron.php >> /tmp/nextcloud-cron.log 2>&1
  fi
  sleep 300
done
CRONEOF
  cat > "${project_path}/.ddev/config.nextcloud.yaml" <<YAMLEOF
# Nextcloud in this project: its release, and its background jobs. Written by the Nextcloud builder of the
# workspace; build again rather than editing by hand.
web_environment:
  - NEXTCLOUD_VERSION=${version}
web_extra_daemons:
  - name: "nextcloud-cron"
    command: "bash /var/www/html/.ddev/nextcloud-cron.sh"
    directory: /var/www/html
YAMLEOF
}

# The release the site runs, as its own version.php says it.
function nextcloud_version() {
  sed -n "s/^\$OC_VersionString = '\(.*\)';/\1/p" "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}/nextcloud/version.php" 2>/dev/null | head -n 1 ;
}

# Build a Nextcloud site from nothing: the project and the release; with --install the installer, the workspace
# account as the administrator and the settings for testing; with --add-users the default accounts.
function nextcloud_build() {
  trim_project_name ;
  local base_url="https://${PROJECT_NAME}.ddev.site" ;
  local version="${NEXTCLOUD_VERSION:-${site_nextcloud_version:-${NEXTCLOUD_DEFAULT_VERSION}}}" ;
  local php_version="${PHP_VERSION:-${site_php_version:-${NEXTCLOUD_DEFAULT_PHP}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;

  if ! [[ "${version}" =~ ^[0-9]+(\.[0-9]+\.[0-9]+)?$ ]] ; then
    echo "--nextcloud-version takes a release (35.0.3) or a major line (35), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if ! [[ "${php_version}" =~ ^8\.[3-5]$ ]] ; then
    echo "--php-version takes 8.3, 8.4 or 8.5 (what the release accepts), not ${php_version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go into the site --install makes." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its container take it). Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${INSTALL}" == 'yes' ] && [ ${#account_pass} -lt 8 ] ; then
    echo "The workspace account's password is not set (core/config/settings.yml): --install makes it the server's administrator. Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its database.
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A PHP project served by Apache (the release's .htaccess rules) from nextcloud/, with the project's database and
  # the Node.js of the workspace for a test suite run in the web container.
  ddev config --project-type=php --docroot=nextcloud --webserver-type=apache-fpm --php-version="${php_version}" \
    --project-name=${PROJECT_NAME} --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  nextcloud_write_config "${project_path}" "${version}" || exit 1 ;

  echo "Starting the project." ;
  ddev_up start -y < /dev/null || exit 1 ;
  echo "Fetching Nextcloud ${version} (about 240 MB) and checking its SHA-256 sum." ;
  local VERSION="${version}" ;
  nextcloud_site download VERSION || exit 1 ;

  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Installing it, with the workspace account ${account_name} as its administrator." ;
    local ADMIN_USER="${account_name}" ADMIN_PASSWORD="${account_pass}" ADMIN_EMAIL="${account_mail:-${account_name}@example.com}" HOST="${PROJECT_NAME}.ddev.site" ;
    nextcloud_site "install configure" ADMIN_USER ADMIN_PASSWORD ADMIN_EMAIL HOST || { echo "The installer did not finish." ; exit 1 ; } ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_nextcloud_users ;
      add_nextcloud_users || exit 1 ;
      users=() ;
    fi
    echo "${doc_name} ${PROJECT_NAME} has been installed: Nextcloud $(nextcloud_version)." ;
    echo "The site: ${base_url} · its mail: ${base_url}:8026 · its administrator: ${account_name}" ;
  else
    echo "${doc_name} ${PROJECT_NAME} is ready, not installed: Nextcloud $(nextcloud_version) at ${base_url} shows its installer." ;
    echo "Build it again with --install (and --add-users) to install it with the workspace account as its administrator." ;
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch "${base_url}" ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Create the default accounts with the server's own tool (occ): an account that is already there gets its password,
# email, display name and groups back. The list is loaded by the caller (set_nextcloud_users): the core's add_users,
# the builder, the tool.
function add_nextcloud_users() {
  nextcloud_enter_project || return 1 ;
  if ! nextcloud_is_installed . ; then
    echo "${doc_name}/${PROJECT_NAME} is not installed: build it with --install first." ;
    return 1 ;
  fi
  local user user_name user_mail user_password user_role ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role:-(no group)}";
    echo " ================================================================= ";
  done
  local ACCOUNTS ;
  ACCOUNTS="$(nextcloud_accounts_rows)" ;
  nextcloud_site accounts ACCOUNTS ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts (never the workspace account, the administrator the installer made).
function cancel_nextcloud_users() {
  nextcloud_enter_project || return 1 ;
  local user user_name ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
  done
  local USERNAMES ;
  USERNAMES="$(nextcloud_usernames | grep -vx "${account_name}")" ;
  nextcloud_site cancel USERNAMES ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# What cmd-tools-nextcloud-occ.sh does: the first of --occ, --add-users, --cancel-users, --empty-files that was
# asked for; with none of them, what the server is.
function nextcloud_occ_tool() {
  trim_project_name ;
  nextcloud_enter_project || exit 1 ;

  if ! ddev describe -j 2>/dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi

  if [ ! "${OCC}" == '_none_' ] ; then
    local OCC_ARGS="${OCC}" ;
    nextcloud_site occ OCC_ARGS ;
    exit $? ;
  fi

  if ! nextcloud_is_installed . ; then
    echo "${doc_name}/${PROJECT_NAME}: Nextcloud $(nextcloud_version), not installed (build it again with --install)." ;
    exit 0 ;
  fi
  set_nextcloud_users ;
  if [ "${ADD_USERS}" == 'yes' ] ; then
    add_nextcloud_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_nextcloud_users ;
  elif [ "${EMPTY_FILES}" == 'yes' ] ; then
    local USERNAMES ;
    USERNAMES="$(nextcloud_usernames)" ;
    nextcloud_site empty USERNAMES ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Nextcloud $(nextcloud_version)" ;
    echo "  the site:  https://${PROJECT_NAME}.ddev.site" ;
    echo "  its mail:  https://${PROJECT_NAME}.ddev.site:8026" ;
    echo "  its administrator: ${account_name}" ;
    echo "" ;
    local USERNAMES ;
    USERNAMES="$(nextcloud_usernames)" ;
    echo "Accounts:" ;
    nextcloud_site list USERNAMES ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Nextcloud site. The core's testing_configure calls this in the project
# folder once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of
# this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives
# cucumber.js the tags that keep the pack's assertions that must fail out of a normal run, the mail catcher (the
# project's own, from inside the web container where the suite runs), the handle the test-data steps work as
# (dataAdmin), the browser messages that are no error of a step, and the users registry of the default accounts (a
# handle a scenario reads, mapped to an account; never the workspace account), and writes a first feature when the
# project has none of its own. Every part is skipped when it is already there, so a second run adds what the first
# missed and never resets a suite.
function testing_configure_nextcloud() {
  local project_path="$1";
  nextcloud_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Nextcloud: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Nextcloud step pack (${NEXTCLOUD_STEPS_PACKAGE} ${NEXTCLOUD_STEPS_VERSION}).";
  set_nextcloud_users ;
  local registry="" user user_name user_mail user_password user_display ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password"; user_display="user_${user}_display";
    registry="${registry}${user}|${!user_name}|${!user_mail}|${!user_password}|${!user_display:-${!user_name}}"$'\n' ;
  done

  local site_name ;
  site_name="$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' "${project_path}/.ddev/config.yaml" | head -n 1)" ;

  python3 - "${project_path}" "${NEXTCLOUD_STEPS_PACKAGE}" "${NEXTCLOUD_STEPS_VERSION}" 'NEXTCLOUD' "${registry}" "https://${site_name:-${PROJECT_NAME}}.ddev.site" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address = sys.argv[1:7]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
base = "(process.env.LAUNCH_URL || '%s').replace(/\\/+$/, '')" % address
if not re.search(r"^[ \t]*mailUrl:", src, re.M):
    additions += [
        pad + "// The project's mail catcher: in the web container (where the testing setup runs the suite) on its own port, else through the router.",
        pad + "mailUrl: process.env.MAIL_URL || (process.env.IS_DDEV_PROJECT ? 'http://127.0.0.1:8025' : `${%s}:8026`)," % base,
    ]
if not re.search(r"^[ \t]*dataAdmin:", src, re.M):
    additions += [
        pad + "// The account the test-data steps and the clean-up use for what only an administrator may do: a handle of `users` in the admin group.",
        pad + "dataAdmin: process.env.DATA_ADMIN || 'administrator',",
    ]
if not re.search(r"^[ \t]*javascript:", src, re.M):
    additions += [
        pad + "// Browser messages that are no error of a step: a request lost when the network changed, a listing the Files app",
        pad + "// cancels, the sharing tab's list of actions, requests the apps make that answer 404 by design, the preview worker",
        pad + "// a public link's page refuses.",
        pad + "javascript: { mode: process.env.WEBSHIP_JS_ERROR_MODE || 'warn', levels: ['error'], ignore: 'net::ERR_NETWORK_CHANGED|signal is aborted without reason|external legacy actions|status of 404|preview-service-worker|SW registration failed', beforeScenario: false, afterScenario: true },",
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the site (the default accounts:",
        pad + "// cmd-tools-nextcloud-occ.sh --add-users). Override one with %s_<HANDLE>_USERNAME and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, username, email, password, display in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USERNAME || '%s', email: '%s', displayName: '%s', password: process.env.%s_PASSWORD || '%s' }," % (handle, env, username, email, display, env, password))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]
    print('  cucumber.js: the mail catcher, the data administrator and the browser messages to leave out')

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the site's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the site (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/nextcloud/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the site" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed site has them.
  if nextcloud_is_installed "${project_path}" && ( cd "${project_path}" && add_nextcloud_users > /dev/null 2>&1 ) ; then
    echo "  the default accounts are on the site (${users[*]})" ;
  elif nextcloud_is_installed "${project_path}" ; then
    echo "  The default accounts could not be written: is the project running (ddev start in ${project_path})?" ;
  fi
}
