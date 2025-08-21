import os
from glob import glob

import importlib_resources
from tutor import hooks

config = {
    'defaults': {
        'UNIBOT_FRONTEND_PLATFORM_NPM_DEPENDENCY_URL': (
            'git+https://github.com/intela-bot/unibot-fe-platform.git#release/teak'
        ),
        'EDX_UNIBOT_PIP_DEPENDENCY_URL': (
            'git+https://github.com/intela-bot/edx-unibot.git@release/teak#egg=uni_bot'
        ),
        'EDX_UNIBOT_BRANCH': 'release/teak',
        'EDX_UNIBOT_VCS_URL': 'https://github.com/intela-bot/edx-unibot',
        'EDX_UNIBOT_PATH_INSIDE_CONTAINER': '/openedx/requirements/edx-unibot/',
        'EDX_UNIBOT_SETTING_UNIBOT_BASE_URL': 'https://example.com',
        'EDX_UNIBOT_SETTING_UNIBOT_API_KEY': 'extremely_strong_key',
        'EDX_UNIBOT_SETTING_UNIBOT_JWT_SECRET_KEY': '<JWT_TOKEN>',
        'EDX_UNIBOT_SETTING_INCLUDE_FILE_CONTENT_DURING_DATA_COLLECTION': True,
        'EDX_UNIBOT_SETTING_UNIBOT_INSTRUCTOR_WIDGET_SCRIPT': '<script>console.log("Unibot script example");</script>',
        'EDX_UNIBOT_SETTING_UNIBOT_INSTRUCTOR_WIDGET_DISPLAYING_MODE': 'custom_widget_in_separate_tab',
        'UNIBOT_MFE_CONFIG_EXTERNAL_SCRIPTS': [
            {
                'body': {
                    'bottom': '<script src="https://example.com/widget/loader.js"></script>',
                    'top': '',
                },
                'head': '',
                'isAuthnRequired': False,
            },
        ],
    },
}

# Add configuration entries
hooks.Filters.CONFIG_DEFAULTS.add_items([(key, value) for key, value in config.get('defaults', {}).items()])

# For each file in tutor_unibot/patches,
# apply a patch based on the file's name and contents.
for path in glob(str(importlib_resources.files('tutor_unibot') / 'patches' / '*')):
    with open(path, encoding='utf-8') as patch_file:
        hooks.Filters.ENV_PATCHES.add_item((os.path.basename(path), patch_file.read()))
