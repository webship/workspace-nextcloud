#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The Nextcloud project in this workspace.')
parser.add_argument('-o', '--occ',
                    default="_none_",
                    help='A command of the server\'s command-line tool (occ), with its arguments, run in the web container. Example: --occ "user:list"')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts. An account that is already there gets its password, email, display name and groups back.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts (never the workspace account, the administrator the installer made).')
parser.add_argument('-e', '--empty-files',
                    action='store_true',
                    default=False,
                    help='Take away every file and folder of the default accounts, with their deleted files and versions (what an interrupted test run left).')
ARGEOF
