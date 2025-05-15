from tutor import hooks

config = {
    'defaults': {
        'UNIBOT_FRONTEND_PLATFORM_NPM_DEPENDENCY_URL': (
            'git+https://github.com/intela-bot/unibot-fe-platform.git'
        ),
        'EDX_UNIBOT_PIP_DEPENDENCY_URL': (
            'git+https://github.com/intela-bot/edx-unibot.git@{{ EDX_UNIBOT_BRANCH }}#egg=uni_bot'
        ),
        'EDX_UNIBOT_BRANCH': 'embedded_widget_in_instructor_tab',
        'EDX_UNIBOT_VCS_URL': 'https://github.com/intela-bot/edx-unibot',
        'EDX_UNIBOT_PATH_INSIDE_CONTAINER': '/openedx/requirements/edx-unibot/',
        'EDX_UNIBOT_SETTING_UNIBOT_BASE_URL': 'https://example.com',
        'EDX_UNIBOT_SETTING_UNIBOT_JWT_SECRET_KEY': '<JWT_TOKEN>',
        'EDX_UNIBOT_SETTING_INCLUDE_FILE_CONTENT_DURING_DATA_COLLECTION': True,
    },
}

# Add configuration entries
hooks.Filters.CONFIG_DEFAULTS.add_items([(key, value) for key, value in config.get('defaults', {}).items()])

# Installs uni-bot-plugin
hooks.Filters.ENV_PATCHES.add_items(
    [
        (
            'openedx-dockerfile-post-python-requirements',
            'RUN pip install {{ EDX_UNIBOT_PIP_DEPENDENCY_URL }}',
        ),
        (
            'openedx-dev-dockerfile-post-python-requirements',
            '''
RUN git clone -b {{ EDX_UNIBOT_BRANCH }} {{ EDX_UNIBOT_VCS_URL }} {{ EDX_UNIBOT_PATH_INSIDE_CONTAINER }}
RUN pip install -e {{ EDX_UNIBOT_PATH_INSIDE_CONTAINER }}
'''
        ),
    ],
)

# Overrides Django settings
hooks.Filters.ENV_PATCHES.add_item(
    (
        'openedx-lms-common-settings',
        '''
UNIBOT_BASE_URL = '{{ EDX_UNIBOT_SETTING_UNIBOT_BASE_URL }}'
UNIBOT_JWT_SECRET_KEY = '{{ EDX_UNIBOT_SETTING_UNIBOT_JWT_SECRET_KEY }}'
FEATURES['INCLUDE_FILE_CONTENT_DURING_DATA_COLLECTION'] = {{ EDX_UNIBOT_SETTING_INCLUDE_FILE_CONTENT_DURING_DATA_COLLECTION }}
''',
    )
)

# Installs custom frontend-platform for learning MFE
hooks.Filters.ENV_PATCHES.add_item(
    (
        'mfe-dockerfile-post-npm-install-learning',
        'RUN npm install {{ UNIBOT_FRONTEND_PLATFORM_NPM_DEPENDENCY_URL }}',
    )
)
