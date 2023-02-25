## Elastic.co engine deletion

A new fac/staff and students engine are generated daily in the evening (currently 8PM local time), following the naming convention of _**web-dir-[faculty-staff|students]-YYYYMMDD\d{6}**_. The engine-generating script never had any cleanup measures built into it, so the number of engines grows daily unchecked. 

This Bash script deletes all but the last six engines (three for each of the fac/staff and student engine types).

### Installation & Setup

#### Requirements

##### Local Environment
- The [global requirements](./README.md).
- The "dev-key" AppSearch API keys from cloud.elastic.co for both ENVs below, saved as local shell ENV variables ($AS_API_KEY and $QA_AS_API_KEY, respectively) in ~/.bashrc:
  - [asuis](https://asuis.kb.us-west-2.aws.found.io:9243/app/enterprise_search/app_search/credentials)
  - [asuis-qa-2](https://asuis-qa-2.kb.us-west-2.aws.found.io:9243/app/enterprise_search/app_search/credentials)
  Without those keys set up (and properly 'export'ed for Bash shell usage), this script will not be able to connect.

##### Required script files
- engine_deletion.bash
- etc
    - engine_deletion.default.vars
- lib
    - _global.bash
    - engine_deletion.settings
    - engine_deletion.functions

#### Setup

1. Make sure that Bash 4.3+ is installed and working locally.
2. Clone this repo down locally.

### Usage

1. Open this project's directory in a terminal (CLI).
2. Run the main script - _*bash config_diffs.bash*_ and follow the prompts.

#### Options (flags)

Run the script with the -h option to get the list.

$ bash ./engine_generation -h