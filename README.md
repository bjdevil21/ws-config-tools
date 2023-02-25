# ET Web Team - Helper scripts

This set of Bash scripts help automate different steps of the development process. See the list below.

## config_diffs.bash - Webspark 2.x configuration file (.yml) diff checker
This identifies which YML files need to be added to Git commits by generating a diff (patch) file between a project's ./config YML files and your local D9 dev site's exported active configuration files.

See [README_config_diffs.md](./README_config_diffs.md) for more information.

## engine_deletion.bash - Elastic.co engine cleanup for fac/staff, student engines

This script deletes the older, daily-generated faculty/staff and student engines from Elastic environments.

See [README_engine_deletion.md](./README_engine_deletion.md) for more information.

# Global instructions

## Installation & Setup

### Requirements

#### Local Environment
- macOS or Linux (no Windows support)
- Bash >= v4.3+ from the CLI (macOS needs Bash to be updated - an online search will return multiple resources on doing this)
- A working web dev environment that works with Webspark 2 (MAMP, LAMP, etc.)
