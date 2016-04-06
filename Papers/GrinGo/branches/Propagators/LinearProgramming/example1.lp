#include "lp-prop.lp".
#include "theory_lp.lp".

{a;b}.

&lp{"2.0"*x; "1"*y : not a} <= "5".
&lp{-"4"*x; "4"*y} <= "5".
&lp{"1"*x} >= "4000" :- a.

&dom{x;"0";"1"}.

&objective(max){-"1"*x:b; "2"*y : b; "1"*x: not b; -"2"*y: not b}.
