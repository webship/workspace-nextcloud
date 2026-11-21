#!/usr/bin/env bash

# workspace-name: Nextcloud (a file and collaboration server)

# Installed by the Nextcloud plugin (plugins.sh --install nextcloud); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Nextcloud server in a container: the release tarball (its SHA-256 sum checked) unpacked in nextcloud/, the
# docroot of a PHP project served by Apache, with its data folder data/ beside it. With --install it is installed
# with its own installer on the project's database, the workspace account as its administrator, and set up for
# testing; with --add-users it also gets the default accounts.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="nextcloud";
distribution_title="Nextcloud";
distribution_webroot="nextcloud";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} project in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/nextcloud/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/nextcloud/args/arg-nextcloud.sh || exit 1 ;

shift $#;

nextcloud_build ;
