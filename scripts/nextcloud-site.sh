# The site script of the file server: run by bash in the project's web container, with the server's own
# command-line tool (occ), never on the host. The build of the test site and the Webship Workspace's builder
# both run it the same way:
#
#   { printf "SITE_PAYLOAD='%s'\n" "<base64 of the payload>"; cat nextcloud-site.sh; } \
#     | ddev exec "SITE_VERBS='<verbs>' bash -s"
#
# The payload travels on the first line of the input, as base64 of lines of KEY=base64(value): no password is
# ever on the command line of the host, in a file of the project, or in the output of a failed run.
#   VERSION                      (download) the release to fetch: 35.0.3, or a line (35) for its newest release
#   ADMIN_USER, ADMIN_PASSWORD   (install) the administrator the installer makes
#   ADMIN_EMAIL                  (install) its email address
#   HOST                         (configure) the host name of the site: <project>.ddev.site
#   ACCOUNTS                     (accounts) the accounts, one per line: username|email|password|display name|groups
#                                (groups: names separated by commas, or nothing)
#   USERNAMES                    (cancel, empty, list) the usernames of the accounts, one per line
#   OCC_ARGS                     (occ) the arguments of one occ command, quoted as in a shell
#
# Verbs, in the order given (SITE_VERBS):
#   download   fetch the release tarball from download.nextcloud.com, check its SHA-256 sum, and unpack it in
#              nextcloud/ (the docroot); the data folder is data/, beside it, outside the docroot
#   install    run the installer (occ maintenance:install) on the project's database, with ADMIN_USER
#   configure  set the site up for its address and for testing: its host name, https behind the router, short
#              addresses, a local memory cache, no app store, no first-run wizard, new accounts start with
#              empty files, no connection to the internet, the mail to the project's mail catcher, background
#              jobs by cron
#   accounts   create the accounts of ACCOUNTS, or give an existing one back its password, email, display
#              name and groups (and enable it)
#   cancel     delete the accounts of USERNAMES (never an administrator the installer made)
#   empty      delete every file and folder of the accounts of USERNAMES, with their trash bin and their versions
#   list       print the accounts of USERNAMES: their email, display name, groups and whether they are enabled
#   version    print the release the site runs
#   occ        run one occ command (OCC_ARGS) and print what it prints
set -uo pipefail

ROOT=/var/www/html
SERVER="$ROOT/nextcloud"
DATA="$ROOT/data"

# One KEY=base64 line per value; the line is split by hand (read would drop a single trailing "=").
declare -A P
while IFS= read -r line; do
  [ -z "$line" ] && continue
  P["${line%%=*}"]="$(printf '%s' "${line#*=}" | base64 -d)"
done < <(printf '%s' "${SITE_PAYLOAD:-}" | base64 -d)
value() { printf '%s' "${P[$1]:-}"; }

occ() { php "$SERVER/occ" --no-interaction --no-ansi "$@"; }

# Whether an account exists.
exists() { occ user:info "$1" > /dev/null 2>&1; }

for verb in ${SITE_VERBS:-}; do
  case "$verb" in
    download)
      version="$(value VERSION)"
      case "$version" in
        *.*.*) file="nextcloud-$version.tar.bz2" ;;
        *) file="latest-$version.tar.bz2" ;;
      esac
      url="https://download.nextcloud.com/server/releases/$file"
      tmp="$(mktemp -d)"
      echo "Fetching $url"
      # A transfer that stays under 10 KB/s for a minute, or a connection that does not open in 30 seconds, is given
      # up and tried again (three times): a stalled connection would otherwise keep curl waiting forever.
      fetch() { curl -fsSL --connect-timeout 30 --speed-limit 10240 --speed-time 60 --retry 3 --retry-delay 5 "$1" -o "$2"; }
      if ! fetch "$url" "$tmp/$file" || ! fetch "$url.sha256" "$tmp/$file.sha256"; then
        echo "The release $version could not be fetched from $url." >&2
        rm -rf "$tmp"
        exit 1
      fi
      # The sum file lists the tarball and its metadata file: the tarball's line is checked.
      if ! (cd "$tmp" && awk -v f="$file" '$2 == f' "$file.sha256" | grep -q . && awk -v f="$file" '$2 == f' "$file.sha256" | sha256sum -c --quiet -); then
        echo "The SHA-256 sum of $file does not match the one the server publishes." >&2
        rm -rf "$tmp"
        exit 1
      fi
      rm -rf "$SERVER" && mkdir -p "$SERVER" "$DATA" || exit 1
      tar -xjf "$tmp/$file" -C "$ROOT" || { rm -rf "$tmp"; exit 1; }
      rm -rf "$tmp"
      echo "Unpacked $(sed -n "s/^\$OC_VersionString = '\(.*\)';/\1/p" "$SERVER/version.php") in nextcloud/."
      ;;
    install)
      if [ -f "$SERVER/config/config.php" ] && grep -q "'installed' => true" "$SERVER/config/config.php"; then
        echo "The site is installed already." >&2
        exit 1
      fi
      if ! occ maintenance:install --database=mysql --database-host=db --database-name=db --database-user=db \
        --database-pass=db --admin-user="$(value ADMIN_USER)" --admin-pass="$(value ADMIN_PASSWORD)" \
        --admin-email="$(value ADMIN_EMAIL)" --data-dir="$DATA"; then
        echo "The installer did not finish." >&2
        exit 1
      fi
      ;;
    configure)
      host="$(value HOST)"
      set_system() { occ config:system:set "$@" > /dev/null || { echo "occ config:system:set $1 failed." >&2; exit 1; }; }
      # The address of the site, behind the router of the container tool, which serves it over https.
      set_system trusted_domains 1 --value="$host"
      set_system overwrite.cli.url --value="https://$host"
      set_system overwriteprotocol --value=https
      # Short addresses (/apps/files, not /index.php/apps/files): the web server's rewrite rules.
      set_system htaccess.RewriteBase --value=/
      occ maintenance:update:htaccess > /dev/null
      # A local memory cache (APCu), on the command line too.
      set_system memcache.local --value='\OC\Memcache\APCu'
      # No app store and no connection to the internet: only the apps the release bundles, no call to any
      # outside service (updates, news, the lookup server).
      set_system appstoreenabled --value=false --type=boolean
      set_system has_internet_connection --value=false --type=boolean
      # New accounts start with no files and no templates: a suite brings its own files.
      set_system skeletondirectory --value=''
      set_system templatedirectory --value=''
      # Every request reaches the server from the router's address: the failed logins of one test run would
      # slow down the logins of every later one, so the throttling of failed logins is off on a test site.
      set_system auth.bruteforce.protection.enabled --value=false --type=boolean
      # The rate limits are off for the same reason: the server sends an account at most five password reset
      # mails in thirty minutes, and a suite run twice asks for more than that.
      set_system ratelimit.protection.enabled --value=false --type=boolean
      # The mail of the site goes to the project's mail catcher.
      set_system mail_smtpmode --value=smtp
      set_system mail_smtphost --value=127.0.0.1
      set_system mail_smtpport --value=1025 --type=integer
      set_system mail_from_address --value=noreply
      set_system mail_domain --value=example.com
      set_system default_phone_region --value=US
      set_system maintenance_window_start --value=1 --type=integer
      # Background jobs by cron (the project runs cron.php every five minutes).
      occ background:cron > /dev/null
      # No first-run wizard.
      occ app:disable firstrunwizard > /dev/null 2>&1 || true
      echo "Configured for https://$host."
      ;;
    accounts)
      while IFS='|' read -r name email password display groups; do
        [ -z "$name" ] && continue
        if exists "$name"; then
          OC_PASS="$password" occ user:resetpassword --password-from-env "$name" > /dev/null || { echo "The password of $name could not be set." >&2; exit 1; }
          occ user:enable "$name" > /dev/null
        else
          OC_PASS="$password" occ user:add --password-from-env --display-name="$display" "$name" > /dev/null || { echo "The account $name could not be made." >&2; exit 1; }
        fi
        # The display name and the email through the server's own API: occ has no command that changes the display name of an
        # existing account, and `occ user:profile <name> email` sets only the profile's copy of the address.
        if ! NAME="$name" DISPLAY_NAME="$display" EMAIL="$email" php -r '
          require "/var/www/html/nextcloud/lib/base.php";
          $user = \OCP\Server::get(\OCP\IUserManager::class)->get(getenv("NAME"));
          if ($user === null) { exit(1); }
          $user->setDisplayName(getenv("DISPLAY_NAME"));
          $user->setSystemEMailAddress(getenv("EMAIL"));'; then
          echo "The display name and email of $name could not be set." >&2
          exit 1
        fi
        if [ -n "$groups" ]; then
          IFS=',' read -ra wanted <<< "$groups"
          for group in "${wanted[@]}"; do
            occ group:add "$group" > /dev/null 2>&1 || true
            occ group:adduser "$group" "$name" > /dev/null 2>&1 || true
          done
        fi
        echo "The account $name ($email) is ready${groups:+, in $groups}."
      done <<< "$(value ACCOUNTS)"
      ;;
    cancel)
      while read -r name; do
        [ -z "$name" ] && continue
        if exists "$name"; then
          occ user:delete "$name" > /dev/null && echo "The account $name is deleted."
        else
          echo "There is no account $name."
        fi
      done <<< "$(value USERNAMES)"
      ;;
    empty)
      # Every file and folder of the accounts (their shares go with them), then their trash bin and their versions:
      # an account as the build left it, with no files.
      while read -r name; do
        [ -z "$name" ] && continue
        exists "$name" || continue
        NAME="$name" php -r '
          require "/var/www/html/nextcloud/lib/base.php";
          $folder = \OCP\Server::get(\OCP\Files\IRootFolder::class)->getUserFolder(getenv("NAME"));
          foreach ($folder->getDirectoryListing() as $node) { $node->delete(); }' || { echo "The files of $name could not be deleted." >&2; exit 1; }
        occ trashbin:cleanup "$name" > /dev/null 2>&1
        occ versions:cleanup "$name" > /dev/null 2>&1
        echo "The files of $name are deleted."
      done <<< "$(value USERNAMES)"
      ;;
    list)
      while read -r name; do
        [ -z "$name" ] && continue
        if exists "$name"; then
          occ user:info "$name" --output=json | php -r '$u = json_decode(stream_get_contents(STDIN), true); printf("  %-14s %-28s %-16s groups: %-12s %s\n", $u["user_id"], $u["email"] ?? "", $u["display_name"] ?? "", implode(",", $u["groups"] ?? []) ?: "none", ($u["enabled"] ?? true) ? "enabled" : "disabled");'
        else
          printf "  %-14s (missing)\n" "$name"
        fi
      done <<< "$(value USERNAMES)"
      ;;
    version)
      occ status --output=json | php -r '$s = json_decode(stream_get_contents(STDIN), true); echo $s["versionstring"] ?? "", "\n";'
      ;;
    occ)
      eval "args=($(value OCC_ARGS))"
      occ "${args[@]}"
      exit $?
      ;;
    *)
      echo "Unknown verb: $verb" >&2
      exit 1
      ;;
  esac
done
