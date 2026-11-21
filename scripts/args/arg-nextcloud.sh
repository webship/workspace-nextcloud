#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its DDEV project and its host name.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the server with its own installer, the workspace account as its administrator, and set it up for testing.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (administrator, editor, user): the ones the test scenarios log in as.')
parser.add_argument('-v', '--nextcloud-version',
                    default="",
                    help='The release of the server: 35.0.3 by default, or a major line for its newest release. Example: --nextcloud-version 34')
parser.add_argument('-p', '--php-version',
                    default="",
                    help='The PHP of the web container: 8.4 by default (the release takes 8.3 to 8.5). Example: --php-version 8.3')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
ARGEOF
