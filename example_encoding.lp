
{a;b}. 

&sum{W*X:coef(ID,I,W),var(ID,I,X)} <= K :- lp(ID), rel(ID,le), bound(ID,K).

&sum{x} >= 4000 :- a.

&dom{L..U}=X :- dom(X,L,U).

&maximize{W*X:b, obj(W,X); x: not b; -2*y: not b} :- obj(max).

#show a/0.
#show b/0.
