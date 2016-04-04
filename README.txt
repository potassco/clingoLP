Installing lp_solve_driver:

get lp_solve_5.5.2.0_dev_ux64.tar.gz
from http://sourceforge.net/projects/lpsolve/files/lpsolve/
extract and put the 
liblpsolve55.a
liblpsolve55.so
in the directory
~/.local/lib/python2.7/site-packages/

(you need to use your own python version number instead (first two digits of "python --version"))

extend your LD_LIBRARY_PATH with this directory

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:~/.local/lib/python2.7/site-packages



Install python module:

get lp_solve_5.5.2.0_Python2.5_exe_ux64.tar.gz
from http://sourceforge.net/projects/lpsolve/files/lpsolve/

extract to ~/.local/lib/python2.7/site-packages/





Now you can use lp-prop.lp and theory_lp.lp for your encoding.

Your encoding has to follow the structure given in example1.lp 

examples:

clingo-4-banane example1.lp --outf=3 

clingo-4-banane encoding.lp cycle1.lp --outf=3
