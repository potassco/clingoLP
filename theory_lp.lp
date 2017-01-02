#theory lp {
    lin_term {
    - : 2, unary;
    * : 1, binary, left;
    + : 0, binary, left;
    - : 0, binary, left
    };
    bounds{
    - : 2, unary;
    * : 1, binary, left;
    / : 1, binary, left;
    + : 0, binary, left;
    - : 0, binary, left    
    };

    &lp/0   : lin_term, {<=,>=,>,<,=,!=}, bounds, any;
    &objective/1 : lin_term, head;
    &dom/0 : bounds, head
}.


