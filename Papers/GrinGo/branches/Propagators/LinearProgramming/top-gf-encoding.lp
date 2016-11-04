#include "theory_lp.lp".
#include "lp-prop.lp".

% option data defaults
#const unreachable=1.
#const reachability=1.
#const fluxbalance=1.
#const export=3.
#const show=0.
#const accuracy=0.
#const epsilon=5.
#const nstrict=0.

%%%%%%%%%% REACHABILITY ENCODING %%%%%%%%%%%

% nodes
s_node(N) :- s_compound(N,_,_).
t_node(N) :- d_compound(N,_,_), t_reactant(N,_,R).


% draft information
reaction(R) :- d_reaction(R).
reaction(R) :- t_reaction(R).

reactant(N,R) :- d_reactant(N,_,R).
reactant(N,R) :- t_reactant(N,_,R).

product(N,R) :- d_product(N,_,R).
product(N,R) :- t_product(N,_,R).

d_edge(R,N,M) :- reaction(R), reactant(N,R), product(M,R). 
d_edge(R,N,M) :- reaction(R), reactant(M,R), product(N,R), reversible(R). 


% repair information
r_reaction(R) :- reaction(R).

r_reactant(N,R) :- r_reactant(N,_,R).

r_product(N,R) :- r_product(N,_,R).

r_edge(R,N,M) :- r_reaction(R), r_reactant(N,R), r_product(M,R).
r_edge(R,N,M) :- r_reaction(R), r_reactant(M,R), r_product(N,R), reversible(R). 


edge(R,N,M) :- r_edge(R,N,M).
edge(R,N,M) :- d_edge(R,N,M).


% choose edges
{add_edge(R):r_edge(R,N,M), a_scope(N), a_scope(M)}.


% draft scope
d_scope(N) :- s_node(N).
d_scope(M) :- d_edge(R,_,M), d_scope(N):d_edge(R,N,_), N!=M.


% draft and choosen repair scope
r_scope(N) :- d_scope(N).
r_scope(M) :- d_edge(R,_,M), r_scope(N):d_edge(R,N,_), N!=M.
r_scope(M) :- add_edge(R), r_edge(R,_,M), r_scope(N):r_edge(R,N,_), N!=M.


% all scope
a_scope(N) :- d_scope(N).
a_scope(M) :- edge(R,_,M), a_scope(N):edge(R,N,_), N!=M. 


% each target of scope need to be reached
:- t_node(N), a_scope(N), not r_scope(N), reachability=1.
unreachable(N) :- t_node(N), not a_scope(N), unreachable=1, reachability=1.
#show unreachable/1.



%%%%%%%%%% FLUX BALANCED ENCODING %%%%%%%%%%%

compound(ID) :- d_product(ID,_,_).
compound(ID) :- d_reactant(ID,_,_), not d_compound(ID,_,"true").
compound(ID) :- t_reactant(ID,_,_).
compound(ID) :- r_reactant(ID,_,R), add_edge(R).
compound(ID) :- r_product(ID,_,R), add_edge(R).


% for nodes N holds: sum(w*N_in)+sum(-w*N_out)=0 
% export=0: consider no exports 
&lp{IW*Rin : d_product(N,IW,Rin); 
    -OW*Rout : d_reactant(N,OW,Rout);
    RIW*RRin : r_product(N,RIW,RRin), add_edge(RRin); 
    -ROW*RRout : r_reactant(N,ROW,RRout), add_edge(RRout); 
    -TOW*TRout : t_reactant(N,TOW,TRout)} = "0"  
           :- compound(N), not t_compound(N,_,_), not s_compound(N,_,_), fluxbalance=1, export=0.
% export=1 and 2: greedy exports for each node
&lp{IW*Rin : d_product(N,IW,Rin); 
    -OW*Rout : d_reactant(N,OW,Rout);
    RIW*RRin : r_product(N,RIW,RRin), add_edge(RRin); 
    -ROW*RRout : r_reactant(N,ROW,RRout), add_edge(RRout); 
    -TOW*TRout : t_reactant(N,TOW,TRout);
    -"1"*N} = "0"  
           :- compound(N), not t_compound(N,_,_), not s_compound(N,_,_), fluxbalance=1, export!=3, export!=0.
% export=3: exports via conditionals (not greedy)
&lp{IW*Rin : d_product(N,IW,Rin); 
    -OW*Rout : d_reactant(N,OW,Rout);
    RIW*RRin : r_product(N,RIW,RRin), add_edge(RRin); 
    -ROW*RRout : r_reactant(N,ROW,RRout), add_edge(RRout); 
    -TOW*TRout : t_reactant(N,TOW,TRout);
    -"1"*N : exp(N) } = "0"
           :- compound(N), not t_compound(N,_,_), not s_compound(N,_,_), fluxbalance=1, export=3.


% export=2 and 3: derive exp for be conditional
% derive exports
exp(N) :- &lp{"1"*N} > "0", compound(N), fluxbalance=1, export!=1, export!=0.
#show exp/1.


% export=2 and 3: minimizing exports in ASP (not in objective)
% priorize less exports (less than gaps) 
#minimize{1@2,exp(N):exp(N),fluxbalance=1}.


% maximizing biomass obj(max){W*ID : t_objective(ID,W)}
% export=1: minimized via objective funktion
&objective(max){Wt*IDt : t_objective(IDt,Wt); 
                Wr*IDr : r_objective(IDr,Wr), add_edge(IDr); 
                Wd*IDd : d_objective(IDd,Wd);
                -"1"*ID : compound(ID)} :- fluxbalance=1, export=1.
% export=2 and 3: not minimized via objective funktion
&objective(max){Wt*IDt : t_objective(IDt,Wt); 
                Wr*IDr : r_objective(IDr,Wr), add_edge(IDr); 
                Wd*IDd : d_objective(IDd,Wd)} :- fluxbalance=1, export!=1, export!=0.


% goal condition: target > 0 
&lp{W*ID} > "0" :- t_reaction(ID), t_product(_,W,ID), fluxbalance=1.


% domain definition; default dom{(x,0,inf)} via dom{(x,"none","none")}
&dom{(N,L,U)} :- d_bounds(N,L,U), fluxbalance=1.
&dom{(N,L,U)} :- r_bounds(N,L,U), fluxbalance=1.
&dom{(N,L,U)} :- t_bounds(N,L,U), fluxbalance=1. 


% minimize number of gaps
#minimize{1@3,add_edge(ID):add_edge(ID),fluxbalance=1}.

#show add_edge/1.
