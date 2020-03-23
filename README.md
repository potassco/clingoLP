# clingo[LP]  

The `clingo` derivative `clingo[LP]` extends of ASP with linear constraints as dealt with in Linear Programming (LP).

## Prerequisites

Use the provided conda environment:

+ `conda env create -f environment.yml`
+ `conda activate clingoLP`

The propagators and scripts require [lpsolve](https://sourceforge.net/projects/lpsolve/) or [cplex](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/GettingStarted/topics/set_up/Python_setup.html).
Additionally, the corresponding Python bindings have to be installed, as described on their respective websites.

### `cplex`

IBM provides a promotional version sufficient to solve small problems limited to 1000 variables and 1000 constraints.

+ `conda install -c ibmdecisionoptimization cplex`

To solve larger problems, you need to use the full version of CPLEX Studio.

## Syntax

lp constraints can be expressed as follows:

+ w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub> >= k --> `&sum{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>n</sub>`} >= `k
+ domain(x)={l,...,u} --> `&dom{`l`..`u`}=`x
+ objective maximize function f_max(w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub>) --> `&maximize{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>1</sub>`}` (minimize analogous)
+ to avoid syntax clashes you must quote `"` real numbers. Instead of `1.5` write `"1.5"`.

## General usage of clingo[LP]

Basic call:
`clingoLP <encoding> <instance> <options>`

Example:
`clingoLP example_encoding.lp example_instance.lp -c show=1`

+ Options
  + -c show=1
    + Enables lp system and objective function (default show=0)
  + -c accuracy=n
    + Prints n decimal positions (default accuracy=1)
  + -c epsilon='(n,m)'
    + Set epsilon to convert lhs > k into lhs >= k+n*10^-m (default epsilon=(1,3))
  + -c nstrict=1
    + Enables non-strict semantics (default nstrict=1)
  + -c solver='lps'
    + Selects a LP solver (default solver=cplx)
  + -c trace=1
    + Enables detailed output of theory propagation (default trace=0)
  + -c core_confl=n
    + Searches for core conflicts if at least n% of the theory atoms are decided (default core_confl=20)
  + -c prop_heur=n
    + Starts a solve call of the LP solver if at least n% of the theory atoms are decided (default prop_heur=0)
  + -c ilp=1
    + Sets the LP solver to solve an Integer Linear Programming (ILP) problem (default ilp=0)
  
  + All clingo options
  + Number solutions controlled via clingo
