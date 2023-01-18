# webspark-config-tools - Webspark 2.x configuration file (.yml) diff checker

This Bash script helps identify which YML files need to be added to Git commits by generating a diff (patch) file between a project's ./config/install YML files and your local D9 dev site's exported active configuration files.

## INSTALLATION & SETUP

### Requirements
#### Local Environment
- macOS or Linux (no Windows support)
- Bash >= v4.3 from the CLI
- A working web dev environment that works with Webspark 2 (MAMP, LAMP, etc.)
- A local directory with all of your local Git clones of any Webspark projects.
  - The project directories must start with "webspark-(theme|profile|module)?-" or the script will not see them to be checked.
#### Required script files
   - d9_config_diff_gen.bash - the Bash script to execute
   - etc/d9_config_diff_gen.settings - configuration file (requires setup by the script user)
   - lib/global.bash - No interactive usage required. Don't touch.

### Setup

1. Clone this repo down to a directory that is accessible by your local site's Drush install. (Ex. ~/Desktop/webspark-config-tools, etc.)
2. Create a new directory that is SEPARATE FROM YOUR WS2 SITE'S current export config directory (defaults to ../config). This is where this script will export your local site's active configurations. (~/Desktop/active_configs is recommended to easily find the YML files, but YMMV.)
3. Open the d9_config_diff_gen.settings file in a text editor and set the script configurations following Bash syntax rules (see the settings file for assistance).

## USAGE

1. In a terminal (CLI), go to this directory.
2. Type *bash d9_config_diff_gen.bash* to run.
3. When prompted, select which project to check (enter 1..N), and a diff file will be opened for review in either nano or vi (CLI text editors).
4. When done, close the file. By default, when the diff file text editor is closed, both the _configs.diff file (and _ws2_diff_commands.bash - a corresponding list of diff commands that generate the _configs.diff file) are deleted (use -m to override - see below).

### Options (flags)
- -m - Keep diff and command files for manual review in the /config/install directory of the project directory.
- -b - "Blab" mode (verbose output)
- -h - Returns this help message
- -v - Returns script version

## NOTES
This script currently only checks a project's /config/install directories. It does not check any other YML files (in the root directory, other /config directories, etc.) Future versions may check other YML files as well.
