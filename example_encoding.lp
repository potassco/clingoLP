
{a;b}.

&lp{W*X:coef(ID,I,W),var(ID,I,X)} <= K :- lp(ID), rel(ID,le), bound(ID,K).

&lp{"1"*x} >= "4000" :- a.

&dom{(X,L,U)} :- dom(X,L,U).

&objective(M){W*X:b, obj(W,X); "1"*x: not b; -"2"*y: not b} :- obj(M).

#show a/0.
#show b/0.
