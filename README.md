# Uni Bot plugin for [Tutor](https://docs.tutor.edly.io)

## Installation

- Clone this repo into the `plugins` folder in the project root.
- Switch to the virtual environment where Tutor==18.1.3 is installed.
- Set `TUTOR_PLUGINS_ROOT` environment variable:
  ```bash
  export TUTOR_PLUGINS_ROOT=${PROJECT_ROOT}/plugins
  ```
- Install the plugin as follows:
  ```bash
  pip install -e ${PROJECT_ROOT}/plugins/${PLUGIN_FOLDER_NAME}/
  ```
- Run:
  ```bash
  tutor plugins enable unibot
  tutor config save
  tutor images build openedx
  tutor images build mfe
  ```
- Start Edx using Tutor.

## Configuration

The plugin takes values from the Tutor-related `config.yml` file for remote configuration, Django settings overriding, etc. If a specific value is missing in the config file, the default values are used from the `config` dictionary inside `tutor_unibot.plugin`.

# UniBot Plugin Installation Script for Open edX

This script automates the installation and configuration of UniBot on an Open edX instance. It handles all necessary setup steps, including plugin installation, OAuth configuration, and tenant registration.

## Prerequisites

The script requires the following tools to be installed and properly configured:

- git
- tutor==18.1.3
- docker
- pip
- openssl

Docker must be running, and the current user must have proper permissions (be in the docker group).

## Installation

1. Download the installation script:
   ```bash
   wget https://raw.githubusercontent.com/intela-bot/tutor-unibot/main/unibot_install.sh && chmod +x unibot_install.sh
   ```

2. Run the script with your UniBot API key:
   ```bash
   ./unibot_install.sh -unibotapikey YOUR_API_KEY
   ```

