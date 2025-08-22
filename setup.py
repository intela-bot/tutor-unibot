import io
import os
from setuptools import setup

from utils import get_version, load_requirements

HERE = os.path.abspath(os.path.dirname(__file__))


def load_readme():
    """
    Provides README file content.
    """
    with io.open(os.path.join(HERE, 'README.rst'), 'rt', encoding='utf8') as f:
        return f.read()


setup(
    name='tutor-unibot',
    version=get_version('tutor_unibot', '__init__.py'),
    license='AGPL',
    author='Intela',
    author_email='info@intela.io',
    description='Tutor plugin for Uni Bot setup',
    long_description=load_readme(),
    include_package_data=True,
    install_requires=load_requirements('requirements/base.in'),
    extras_require={'dev': load_requirements('requirements/development.in')},
    entry_points={'tutor.plugin.v1': ['unibot = tutor_unibot.plugin']},
)
