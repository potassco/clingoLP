from setuptools import setup

setup(
    name='clingo-lp',
    version='0.1.1',
    url='http://github.com/potassco/clingoLP/',
    license='MIT',
    description='clingo[LP] extends the ASP solver clingo with linear constraints as dealt with in Linear Programming (LP).',
    long_description=open('README.md').read(),
    long_description_content_type="text/markdown",
    author='Sebastian Schellhorn',
    packages=['clingolp'],
    package_dir={'clingolp': 'src'},
    entry_points={'console_scripts': ['clingoLP = clingolp.app:main_clingo']}
)
