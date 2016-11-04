Installing lp_solve_driver
--------------------------
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



Install python module
---------------------
get lp_solve_5.5.2.0_Python2.5_exe_ux64.tar.gz
from http://sourceforge.net/projects/lpsolve/files/lpsolve/

extract to ~/.local/lib/python2.7/site-packages/



Set python path with clingo python module
-----------------------------------------
for example
export PYTHONPATH=/home/wv/bin/linux/64/lib/pyclingo-banane



General usage of ASPmLP
-----------------------
Now you can use lp-prop.lp and theory_lp.lp for your encoding.

Your encoding has to follow the structure given in example1.lp 

Examples:

clingo-banane example1.lp --const show=1 --const accuracy=3




Usage to solve biological networks
----------------------------------
1.) 
To generate ASP facts from *.smbl and *.xml files use flux_converter.py as follows:

python flux_converter.py -d <draft_inputfile> -r <repair_inputfile> -o <outputfile>

The output would be a '<outputfile>_draft.lp' and '<outputfile>_repair.lp'.

Note: 
Encoding based on facts with tags s_*, t_*, d_* and r_*.

Example:

python flux_converter.py -d draft.xml -r repair.xml -o facts


2.)
Solve instances:

clingo-banane top-gf-encoding.lp seeds.lp targets.lp draft.lp repair.lp 

The following option constants can be modified to configure output and solving.
For example via: 
clingo-banane top-gf-encoding.lp seeds.lp targets.lp draft.lp repair.lp  --const show=1

Constants and their default values:
#const unreachable=1.  % show unreachable targets; parameters: 0 or 1
#const reachability=1. % solve reachability; parameters: 0 or 1
#const fluxbalance=1.  % solve flux balance; parameters: 0 or 1
#const export=3.       % set how to handle exports; parameters: 0 (no exports), 1 (greedy;obj), 2 (greedy;ASP) or 3 (lazy;ASP)
#const show=0.         % show lp system and objective function; parameters
#const accuracy=0.     % set the accuracy (number of decimal positions); paramters: 0 to n
#const epsilon=5.      % set epsilon: 10^-epsilon; parameters: 0 to n
#const nstrict=0.      % set strict or non-strict semantics; parameters: 0 or 1


