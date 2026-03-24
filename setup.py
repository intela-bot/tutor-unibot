import os
from pathlib import Path
from setuptools import find_packages, setup

from utils import get_version, load_requirements

HERE = os.path.abspath(os.path.dirname(__file__))


def load_readme():
    """
    Provides README file content.
    """
    return Path('README.md').read_text()


setup(
    name='tutor-unibot',
    version=get_version('tutor_unibot', '__init__.py'),
    license='AGPL',
    author='Intela',
    author_email='info@intela.io',
    description='Tutor plugin for Uni Bot setup',
    long_description=load_readme(),
    packages=find_packages(exclude=['tests*']),
    include_package_data=True,
    package_data={'tutor_unibot': ['patches/*']},
    install_requires=['tutor>=17.0.0', 'importlib_resources'],
    extras_require={'dev': ['tutor[dev]>=17.0.0']},
    entry_points={'tutor.plugin.v1': ['unibot = tutor_unibot.plugin']},
)
