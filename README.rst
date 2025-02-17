Uni Bot plugin for `Tutor <https://docs.tutor.edly.io>`__
========================================================

Installation
############

- Clone this repo into `plugins` folder in the project root.
- Switch to virtual environment where Tutor is installed.
- Set `TUTOR_PLUGINS_ROOT` environment variable: `export TUTOR_PLUGINS_ROOT=${PROJECT_ROOT}/plugins`.
- Install the plugin as follows: `pip install -e ${PROJECT_ROOT}/plugins/${PLUGIN_FOLDER_NAME}/`.
- Run `tutor plugins enable unibot`.
- Run `tutor config save`.
- Run `tutor images build openedx`.
- Run `tutor images build mfe`.
- Start Edx using Tutor.

Configuration
#############

The plugin takes values from the Tutor-related *config.yml* file for remotes configuration, Django
settings overriding etc. If the specific value is missed in the config file, the default values are used
that are defined in `config` dictionary inside `tutor_unibot.plugin`.
