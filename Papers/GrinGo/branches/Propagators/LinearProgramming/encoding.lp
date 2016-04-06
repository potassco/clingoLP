#include "theory_lp.lp".
#include "lp-prop.lp".

node(Node) :- compound(Node,_,_).

target(N) :- reaction(ID,1,_), reactant(N,_, ID,_).
source(N) :- compound(N,_,"true").

edge(ID,From,To,Weight) :- node(N), reaction(ID,0,_), 
          reactant(From,_,ID,_), product(To, Weight, ID,_).

&lp{W*In : edge(In,_,N,W); -"1"*Out : edge(Out,N,_,_)} = "0" :- node(N), not target(N), not source(N).
&lp{"1"*ID} > "0" :- reaction(ID,1,_).
&lp{"1"*ID} > "0" :- source(N), reaction(ID,_,_), reactant(N,_,ID,_).

ids(ID) :- source(N), reaction(ID,_,_), reactant(N,_,ID,_).

&objective(max){"1"*ID : reaction(ID,1,_); "1"*IDS : ids(IDS)}.

&dom{N;L;U} :- bounds(N,L,U).
