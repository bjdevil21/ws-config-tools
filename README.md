# webspark-config-tools - Webspark 2.x configuration file (.yml) diff checker

This Bash script helps identify which YML files need to be added to Git commits by generating a diff (patch) file between a project's ./config/install YML files and your local D9 dev site's exported active configuration files.

## Installation & Setup

### Requirements
#### Local Environment
- macOS or Linux (no Windows support)
- Bash >= v4.3 from the CLI
- A working web dev environment that works with Webspark 2 (MAMP, LAMP, etc.)
- A local directory with all of your local Git clones of any Webspark projects.
  - The project directories must start with "webspark-(theme|profile|module)?-" or the script will not see them to be checked.
#### Required script files
   - d9_config_diff_gen.bash - the Bash script to execute
   - etc/d9_config_diff_gen.settings
   - lib/global.bash

### Setup

1. Clone this repo down to a directory that is accessible by your local site's Drush install. (Ex. ~/Desktop/webspark-config-tools, etc.)
2. Create a new directory that is SEPARATE FROM YOUR WS2 SITE'S current export config directory (defaults to ../config). This is where this script will export your local site's active configurations. (Ex. ~/Desktop/active_configs). It must be reachable by Drush with a relative directory path.
3. Open the d9_config_diff_gen.settings file in a text editor and set the five configurations, following Bash syntax rules. (See that file's comments for assistance).

## Usage

1. Open this directory in a terminal (CLI).
2. Type *bash d9_config_diff_gen.bash* to run. When prompted, select which project to check (enter 1..N), and a diff file will be opened for review in your choice of text editor (see settings file).
3. Close the file when done reviewing. By default, when the diff file text editor is closed, the generated diff file (and command file that made it) are deleted.

#### Options (flags)
- -m - Keep diff and command files for manual review in the /config/install directory of the project directory.
- -b - "Blab" mode (verbose output)
- -h - Returns this help message
- -v - Returns script version

## NOTES
- This script currently only checks a project's /config/install directories. It does not check any other YML files (in the root directory, other /config directories, etc.) Future versions may check other YML files as well.
