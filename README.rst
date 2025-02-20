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


UniBot Plugin Installation Script for Open edX
=============================================

This script automates the installation and configuration of UniBot on an Open edX instance. It handles all necessary setup steps including plugin installation, OAuth configuration, and tenant registration.

Prerequisites
-------------

The script requires the following tools to be installed and properly configured:

- git
- tutor
- docker
- pip
- openssl

Docker must be running, and the current user must have proper permissions (be in the docker group).

Installation
------------

1. Download the installation script:

   .. code-block:: bash

      wget https://raw.githubusercontent.com/your-repo/unibot_install.sh && chmod +x unibot_install.sh

2. Run the script with your UniBot API key:

   .. code-block:: bash

      ./unibot_install.sh -unibotapikey YOUR_API_KEY

