
% possible example facts to define a linear constraint
% 2x + y <= 5
lp(1).
coef(1,1,"2.0").
var(1,1,x).
coef(1,2,1).
var(1,2,y).
rel(1,le).
bound(1,5).

% -4x + 4y <= 5
lp(2).
coef(2,1,-4).
var(2,1,x).
coef(2,2,4).
var(2,2,y).
rel(2,le).
bound(2,5).


% possible example fact to define a domain [0,1]
dom(x,0,1).


% possible example facts to define an objective function
obj(-1,x).
obj(2,y).
obj(max).

