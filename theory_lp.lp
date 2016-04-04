#theory lp {
    lin_term {
    - : 2, unary;
    * : 1, binary, left;
    + : 0, binary, left;
    - : 0, binary, left
    };
    bounds{
    - : 0, unary    
    };
    show_term {
    / : 0, binary, left
    };

    &lp/0   : lin_term, {<=,>=,>,<,!=,=}, lin_term, any;
    &objective/1 : lin_term, directive;
    &dom/0 : bounds, head;
    &show/0 : show_term, directive
}.


