# clingo[LP]  

The `clingo` derivative `clingo[LP]` extends of ASP with linear constraints as dealt with in Linear Programming (LP).

## Prerequisites

Use the provided conda environment: 
+ `conda env create -f environment.yml`
+ `conda activate clingoLP`

The propagators and scripts require [lpsolve](https://sourceforge.net/projects/lpsolve/) or [cplex](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/GettingStarted/topics/set_up/Python_setup.html).
Additionally, the corresponding Python bindings have to be installed, as described on their respective websites.

### `lpsolve`

A python package for lpsolve is contained in this repository:
+ `cd lp_solve_5.5`
+ `python setup install`

### `cplex`

IBM provides a promotional version sufficient to solve toy examples:
+ `conda install -c ibmdecisionoptimization cplex`

## Syntax

lp constraints can be expressed as follows:
  + w_1*x_1+...+w_nx_n >= k --> &sum{w_1*x_1;...;w_n*x_n} >= k
  + domain(x)={l,...,u} --> &dom{l..u}=x
  + objective maximize function f_max(w_1*x_1+...+w_nx_n) --> &maximize{w_1*x_1;...;w_n*x_n} (minimize analogous)
  + use "w_i" instead of w_i if w_i is a real number to avoid syntax clashes

## General usage of clingo[LP]

Basic call:
`python clingoLP.py <encoding> <instance> <options>`

Example:
`python clingoLP.py example_encoding.lp example_instance.lp -c show=1`

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
