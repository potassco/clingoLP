from setuptools import setup

setup(
    name='clingolp',
    version='0.1.0',
    url='http://github.com/potassco/clingoLP/',
    license='MIT',
    description='',
    long_description=open('README.md').read(),
    long_description_content_type="text/markdown",
    author='Sebastian Schellhorn',
    packages=['clingolp'],
    package_dir={'clingolp': 'src'},
    entry_points={'console_scripts': ['clingoLP = clingolp.app:main_clingo']}
)
