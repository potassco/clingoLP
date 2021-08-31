# clingo[LP]  

`clingo[LP]` extends the ASP solver `clingo` with linear constraints as dealt with in Linear Programming (LP).

## Install

Install via conda:

```sh
conda install -c potassco -c conda-forge clingo-lp
```

## CPLEX

The clingoLP propagator requires an LP solver.
The default is [lpsolve](https://sourceforge.net/projects/lpsolve/) but [cplex](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.7.0/ilog.odms.cplex.help/CPLEX/GettingStarted/topics/set_up/Python_setup.html) can be used optionally.

IBM also provides a promotional version of `cplex` that is sufficient to solve small problems limited to 1000 variables and 1000 constraints.

```sh
conda install -c ibmdecisionoptimization cplex`
```

To solve larger problems, you need to use the full version of CPLEX Studio.

## Syntax

LP constraints can be expressed as follows:

| LP constraints                                                      | ClingoLP Syntax                                                                                         |
| :------------------------------------------------------------------ | :------------------------------------------------------------------------------------------------------ |
| w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub> >= k      | `&sum{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>n</sub>`} >=` k                      |
| domain(x)={l,...,u}                                                 | `&dom{`l`..`u`} =` x                                                                                    |
| maximize: w<sub>1</sub>x<sub>1</sub>+...+w<sub>n</sub>x<sub>n</sub> | `&maximize{`w<sub>1</sub>`*`x<sub>1</sub>`;`...`;`w<sub>n</sub>`*`x<sub>1</sub>`}` (minimize analogous) |

To avoid syntax clashes, you must quote `"` real numbers. Instead of `1.5` write `"1.5"`.

## Usage

```txt
clingoLP [number] [options] [files]

Options:

  --lp-solver=<arg>       : Set LP solver
      <arg>: {lps,cplx} (default lp-solver=lps)
  --[no-]show-lp-solution : Show LP solution and value of objective function
  --accuracy=n            : Set decimal position of LP solver accuracy (default accuracy=3)
  --epsilon=n,m           : Set epsilon to convert lhs > k into lhs >= k+n*10^-m (default epsilon=1,3)
  --[no-]trace            : Enables detailed output of theory propagation
  --core-confl=n          : Searches for core conflicts if at least n% of the theory atoms are decided
                            (default core-confl=20)
  --prop-heur=n           : Starts a solve call of the LP solver if at least n% of the theory atoms are decided
                            (default prop-heur=0)
  --[no-]ilp              : Sets the LP solver to solve an Integer Linear Programming (ILP) problem
```

Example:

```sh
clingoLP 0 --show-lp-solution example_encoding.lp example_instance.lp
```

For more options you can ask for help as follows:

```sh
clingoLP --help
```
  
## Publication

[Clingo goes linear constraints over reals and integers, Janhunen, T., Kaminski, R., Ostrowski, M., Schellhorn, S., Wanko, P., Schaub, T. (2017),  TPLP, 17(5-6), 872–888.](https://www.cs.uni-potsdam.de/wv/publications/DBLP_journals/tplp/JanhunenKOSWS17.pdf)
