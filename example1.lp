#include "lp-prop.lp".
#include "theory_lp.lp".

{a}.

&lp{2*x; 1*y : not a} <= 5.
&lp{-4*x; 4*y} <= 5.
&lp{1*x} >= 4000 :- a.

&dom{x;0;1}.

&objective(min){-1*x; 2*y}.
