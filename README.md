# ASP modulo Linear Programming
Propagator and script that solves ASP modulo linear programs.

## Prerequisites
The propagators and scripts require [lpsolve](https://sourceforge.net/projects/lpsolve/) or [cplex](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/GettingStarted/topics/set_up/Python_setup.html).
Additionally, the corresponding Python bindings have to be installed, as described on their respective websites.

## General usage of ASPmLP
Basic call:
`clingo <script> <encoding> <instance> <options>`

Example:
`clingo lp-prop.lp example_encoding.lp example_instance.lp -c show=1`

Script:
* lp-prop.lp 
    * Includes teory_lp.lp to define the language for the propagator
        * w_1*x_1+...+w_nx_n >= k --> &lp{w_1*x_1;...;w_n*x_n} >= k
        * domain(x)={l,...,u} --> &dom{l..u}=x
        * objective maximize function f_max(w_1*x_1+...+w_nx_n) --> &maximize{w_1*x_1;...;w_n*x_n} (minimize analogous)
        * use "w_i" instead of w_i if w_i is a real number to avoid syntax clashed 
    * Options 
        * All clingo options
        * Number solutions controlled via clingo 
        * -c show=1
            * Enables lp system and objective function (default show=0)
        * -c accuracy=n 
            * Prints n decimal positions (default accuracy=1)
        * -c epsilon='(n,m)'
            * Set epsilon to convert lhs > k into lhs >= k+n*10^-m (default epsilon=(1,3))
        * -c nstrict=1
            * Enables non-strict semantics (default nstrict=1)
        * -c solver='lps'
            * Selects a lp solver (default solver=cplx) 
        * -c trace=1
            * Enables detailed output of theory propagation (default trace=0)
        * -c core_confl=n
            * Searches for core conflicts if at least n% of the theory atoms are decided (default core_confl=20)
        * -c prop_heur=n
            * Starts a solve call of the lp solver if at least n% of the theory atoms are decided (default prop_heur=0)

