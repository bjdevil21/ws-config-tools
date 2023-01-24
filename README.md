# webspark-config-tools - Webspark 2.x configuration file (.yml) diff checker

This Bash script helps identify which YML files need to be added to Git commits by generating a diff (patch) file between a project's ./config YML files and your local D9 dev site's exported active configuration files.

## Installation & Setup

### Requirements

#### Local Environment
- macOS or Linux (no Windows support)
- Bash >= v4.3 from the CLI
- A working web dev environment that works with Webspark 2 (MAMP, LAMP, etc.)
- A local directory with all of your local Git clones of any Webspark projects.
  - The project directories must start with "webspark-(theme|profile|module)?-" or the script will not see them to be checked.

#### Required script files
- d9_config_diff_gen.bash
- etc
  - d9_config_diff_gen.default.vars
- lib
  - global.bash
  - d9_config_diff_gen.settings
  - d9_config_diff_gen.functions

##### Optional
- user_settings
  - d9_config_diff_gen.my.vars (copy of the default.vars file with your own settings)

### Setup

1. Clone this repo down to a directory that is accessible by your local site's Drush install. (Ex. ~/Desktop/webspark-config-tools, etc.)
2. Create a new directory that is SEPARATE FROM YOUR WS2 SITE'S current export config directory (defaults to ../config). This is where this script will export your local site's active configurations. (Ex. ~/Desktop/active_configs). It must be reachable by Drush with a relative directory path.
3. Create a new "user_settings" directory (in the script's root dir) and copy the d9_config_diff_gen.default.vars file over as d9_config_diff_gen.vars.
4. Set the five d9_config_diff_gen.vars variables (see the file's notes for help).

## Usage

1. Open this project's directory in a terminal (CLI).
2. Run the main script - _*bash d9_config_diff_gen.bash*_. When prompted, select which project's config files to check (enter 1..N), and a diff file will be opened for review in your choice of text editor (see settings file).
3. Close the file when done reviewing. By default, when the diff file text editor is closed, the generated diff file (and command file that made it) are deleted.

### Options (flags)

These flags can be combined (i.e. -kgV, -cr, etc.), with -z and -Z combining most of the options.

- -m Keep diff and command files for manual review
- -g Interactively verify Git branch status for each project
- -r Re-run Drush export of active configs into $CONF_EXPORT_DIR
- -R - Same as -r, but with an additional 'start point' config export
  - This output will be used to find new YML files. Use this when starting a new ticket/task.
  - If you skip this step, plan on looking for new YML files your dev work may generate in the site's active config directory.
- -p - Create an appliable .patch file in ./config for single projects (or the script root for ALL). USE WITH EXTREME CAUTION!
- -c Skips Drush check if project is enabled (disabled projects bloat the config diff output)
- -V Verbose output
- -z Extra careful mode - same as -kgr
- -Z Extra careful mode (verbose) - same as -kgrV
- -v Script version
- -h Returns this help message

## NOTES
- This script currently checks all three project config directories (install, optional, schema). It does not check any other YML files (in the root directory, other /config directories, etc.) Future versions may check other YML files as well.
- Cleaning up after the script: Running the script without the manual review option (-m) will automatically delete all of the script's generated files. One exception: patch files (-p). These files must be deleted manually.
