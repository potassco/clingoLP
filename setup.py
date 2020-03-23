# Copyright (c) 2020, Sven Thiele <sthiele78@gmail.com>
#
# This file is part of clingoLP.
#
# meneco is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# meneco is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with clingoLP.  If not, see <http://www.gnu.org/licenses/>.
# -*- coding: utf-8 -*-
from setuptools import setup

setup(
    name='clingolp',
    version='0.1.0',
    url='http://github.com/sthiele/clingoLP/',
    license='GPLv3+',
    description='',
    long_description=open('README.md').read(),
    long_description_content_type="text/markdown",
    author='Sven Thiele',
    author_email='sthiele78@gmail.com',
    packages=['clingolp'],
    package_dir={'clingolp': 'src'},
    scripts          = ['clingoLP.py']
)
