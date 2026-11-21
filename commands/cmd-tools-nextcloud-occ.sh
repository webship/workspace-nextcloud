#!/usr/bin/env bash

# Installed by the Nextcloud plugin (plugins.sh --install nextcloud); __WORKSPACE__ is the workspace it was installed into.
#
# The command-line tool (occ) of one Nextcloud site of this workspace, in the project's web container: say what the
# server is, run an occ command, add or cancel the default accounts, take away their files. Nothing here runs on the
# host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="nextcloud";

ARGPARSE_DESCRIPTION="Run the command-line tool (occ) of a Nextcloud site of __WORKSPACE__: status, an occ command, the default accounts"
# The args file comes with the plugin: core/scripts/plugins/nextcloud/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/nextcloud/args/arg-nextcloud-occ.sh || exit 1 ;

shift $#;

nextcloud_occ_tool ;
