## Configuration Diffs

### Installation & Setup

#### Requirements

##### Local Environment
- The [global requirements](./README.md).
- A local directory with all of your local Git clones of any Webspark projects.
    - The project directories must start with "webspark-(theme|profile|module)?-" or the script will not see them to be checked.

##### Required script files
- config_diffs.bash
- etc
    - config_diffs.default.vars
- lib
    - _global.bash
    - config_diffs.settings
    - config_diffs.functions

###### Optional
- user_settings
    - config_diffs.my.vars (copy of the default.vars file with your own settings)

#### Setup

1. Clone this repo down to a directory that is accessible by your local site's Drush install. (Ex. ~/Desktop/webspark-config-tools, etc.)
2. Create a new directory that is SEPARATE FROM YOUR WS2 SITE'S current export config directory (defaults to ../config). This is where this script will export your local site's active configurations. (Ex. ~/Desktop/active_configs). It must be reachable by Drush with a relative directory path.
3. Create a new "user_settings" directory (in the script's root dir) and copy the config_diffs.default.vars file over as config_diffs.my.vars.
4. Set the five config_diffs.my.vars variables (see the file's notes for help).

### Usage

1. Open this project's directory in a terminal (CLI).
2. Run the main script - _*bash config_diffs.bash*_. When prompted, select which project's config files to check (enter 1..N), and a diff file will be opened for review in your choice of text editor (see settings file).
3. Close the file when done reviewing.

#### Options (flags)

Run the script with the -h option to get the list.

The options can be combined (i.e. -kgV, -cr, etc.).

#### Usage notes

- By default, when the diff file text editor is closed, the generated diff file - and the "commands" file that made it - are deleted. Use -m to keep the files availble for further review.
- Cleaning up after the script: Running the script without the manual review option (-m) will automatically delete all of the script's generated files (except patches).
- Run -P to delete all .patch files in the ./config directory.

### NOTES

- This script currently only checks all three project config directories (install, optional, schema). It does not check any other YML files (in the root directory, other /config directories, etc.)
