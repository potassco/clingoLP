# clingo[LP]  

`clingo[LP]` extends the ASP solver `clingo` with linear constraints as dealt with in Linear Programming (LP).

## Install

Install via conda:

+ `conda install -c potassco -c conda-forge clingolp`

## CPLEX

The clingolp propagator requires an LP solver. The default is [lpsolve](https://sourceforge.net/projects/lpsolve/) but [cplex](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/GettingStarted/topics/set_up/Python_setup.html) can be used optionally.

IBM also provides a promotional version of `cplex` that is sufficient to solve small problems limited to 1000 variables and 1000 constraints.

+ `conda install -c ibmdecisionoptimization cplex`

To solve larger problems, you need to use the full version of CPLEX Studio.

## Syntax

LP constraints can be expressed as follows:

|LP constraints | ClingoLP Syntax|
|:--------------|:---------------|
|w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub> >= k | `&sum{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>n</sub>`} >=` k |
| domain(x)={l,...,u} | `&dom{`l`..`u`} =` x
| maximize: w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub> | `&maximize{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>1</sub>`}` (minimize analogous)

To avoid syntax clashes you must quote `"` real numbers. Instead of `1.5` write `"1.5"`.

## General usage of clingo[LP]

Basic call:
`clingoLP <encoding> <instance> <options>`

Example:
`clingoLP example_encoding.lp example_instance.lp -c show=1`

+ Options
  + -c show=1
    + Show lp solution and value of objective function (default show=0)
  + -c accuracy=n
    + Prints n decimal positions (default accuracy=1)
  + -c epsilon='(n,m)'
    + Set epsilon to convert lhs > k into lhs >= k+n*10<sup>-m</sup> (default epsilon=(1,3))
  + -c nstrict=1
    + Enables non-strict semantics (default nstrict=1)
  + -c solver=cplx
    + Selects a LP solver (default solver=lps)
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
  
## Publication

+ [Clingo goes linear constraints over reals and integers, Janhunen, T., Kaminski, R., Ostrowski, M., Schellhorn, S., Wanko, P., Schaub, T. (2017),  TPLP, 17(5-6), 872–888.](https://www.cs.uni-potsdam.de/wv/publications/DBLP_journals/tplp/JanhunenKOSWS17.pdf)
