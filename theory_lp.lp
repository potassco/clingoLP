#theory lp { 
    lin_term {
    - : 2, unary;
    * : 1, binary, left;
    + : 0, binary, left;
    - : 0, binary, left
    };
    bounds{
    - : 4, unary;
    * : 3, binary, left;
    / : 2, binary, left;
    + : 1, binary, left;
    - : 1, binary, left;   
    .. : 0, binary, left 
    };

    &lp/0   : lin_term, {<=,>=,>,<,=,!=}, bounds, any;
    &sum/0   : lin_term, {<=,>=,>,<,=,!=}, bounds, any;
    &objective/1 : lin_term, head;
    &minimize/0 : lin_term, head;
    &maximize/0 : lin_term, head;
    &dom/0 : bounds, {=}, lin_term, head
}.


