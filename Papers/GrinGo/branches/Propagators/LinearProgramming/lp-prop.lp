#script (python)

from lp_solve import *
import sys

class Propagator:

    class State:

        def __init__(self): 
            self.stack = []             # [(decision level, lp_trail index, cond_trail index)]
            self.lp_trail = []          # [lp literal]
            self.cond_trail = []        # [conditional literals]
            self.cond_trail_old = []
            self.lp_trail_old = []
            self.solution = None        # (state, opt, {varname : value})



    def __state(self, sid):
        while len(self.__states) <= sid:
            self.__states.append(Propagator.State())
        return self.__states[sid]



    def __init__(self, show, accuracy, nstrict, epsilon):
        self.__structure = {}           # {literal : [(weights,guard,const)]}
        self.__states = []              # [state]
        self.__objective = {}           # {varname : [weight or {clit : weight}]}
        self.__cond_trail_s = []        # [clits] conditional literals of last lpsolve try
        self.__lp_trail_s = []          # [lplits] lp literals of last lpsolve try
        self.__clist_clits = {}         # {literal : [conditional literals]}
        self.__mat_cond_lit = set()     # {matclit}
        self.__obj_cond_lit = set()     # {objclit}
        self.__optim = ''               # min or max
        self.__bounds = {}              # {varname : (lower bound, upper bound)}
        self.__varpos = {}              # {varname : var_pos}
        self.__varpos_obj = {}          # {varname : var_pos} fixed ones of obj
        self.s_out = []                 # [(state, opt, {varname : value})]
        self.__wopt = {}                # {varname : weight} 
        self.__fopt = []                # [fopt weights in varpos order]
        self.__clist = []               # [({varname : weights}, rel, brow)]
        self.lp = []
        self.initial = True             # initial done value
        self.reset = False              # lpsolve reset indicator
        self.result = []                # [results] result output
        if 'None' == str(accuracy):   
            self.__accuracy = 0
        else:
            self.__accuracy = accuracy.number
        if 'None' == str(show) or show.number != 1:
            self.__show = False
        else:
            self.__show = True
        if 'None' == str(nstrict) or nstrict.number != 1:
            self.__nstrict = False
        else: 
            self.__nstrict = True
        if 'None' == str(epsilon): # user sets positions after dot: 10^-epsilon
            self.__epsilon = 0.00001 #sys.float_info.epsilon*10 is too low -> round problems
        else:
            self.__epsilon = 10**-epsilon.number




    def init(self, init):
        for atom in init.theory_atoms:
            term = atom.term
            if term.name == 'lp':
                self.__lp_structure(atom, init)
            if term.name == 'objective':
                self.__lp_objective(atom, init)
            if term.name == 'dom':
                self.__lp_domain(atom)



    # resolves structure of lp-statements and saves it
    def __lp_structure(self, atom, init): 
        lit=init.solver_literal(atom.literal)
        init.add_watch(lit)
        if not self.__nstrict:
            init.add_watch(-lit)
        self.__clist_clits.setdefault(lit,[])
        weights = {}              
        lhs = atom.elements
        rhs = atom.guard[1]
        rel = atom.guard[0]
        for elem in lhs:
            if elem.terms[0].arguments[1].arguments == []:
                varname = elem.terms[0].arguments[1].name
            else: 
                varname = str(elem.terms[0].arguments[1])
            koef = elem.terms[0].arguments[0]
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_id)
                init.add_watch(clit)
                init.add_watch(-clit)
                self.__mat_cond_lit.add(clit)
                self.__clist_clits.setdefault(lit,[]).append(clit)
                tmp = {}
                if koef.arguments != []:
                    tmp[clit] = -float(str(koef.arguments[0])[1:-1])
                    weights.setdefault(varname,[]).append(tmp)
                else:
                    tmp[clit] = float(str(koef)[1:-1])
                    weights.setdefault(varname,[]).append(tmp)
            else:
                if koef.arguments != []:
                    weights.setdefault(varname,[]).append(-float(str(koef.arguments[0])[1:-1]))
                else:
                    weights.setdefault(varname,[]).append(float(str(koef)[1:-1]))
        if rhs.arguments != []:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,-float(str(rhs.arguments[0])[1:-1])))
        else:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,float(str(rhs)[1:-1])))



    # resolves structure of objective-statements and saves it
    def __lp_objective(self, atom, init):
        obj = atom.elements 
        col_pos = len(self.__varpos) 
        self.__optim = str(atom.term.arguments[0])
        for elem in obj:
            varname = elem.terms[0].arguments[1].name
            koef = elem.terms[0].arguments[0]
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_id)
                init.add_watch(clit) 
                init.add_watch(-clit) 
                self.__obj_cond_lit.add(clit)
                tmp = {}
                if koef.arguments != []:
                    tmp[clit] = -float(str(koef.arguments[0])[1:-1])
                    self.__objective.setdefault(varname,[]).append(tmp)
                else:
                    tmp[clit] = float(str(koef)[1:-1])
                    self.__objective.setdefault(varname,[]).append(tmp)
            else:
                if koef.arguments != []:
                    self.__objective.setdefault(varname,[]).append(-float(str(koef.arguments[0])[1:-1]))
                else:
                    self.__objective.setdefault(varname,[]).append(float(str(koef)[1:-1]))
        for varname in self.__objective: 
            tmp = 0
            for weight in self.__objective[varname]:
                if not isinstance(weight, dict):
                    tmp = tmp + weight
            if tmp != 0: 
                col_pos = col_pos +1
                self.__varpos_obj[varname] = col_pos 



    # resolves structure of domain-statements and saves it
    def __lp_domain(self, atom):
        if atom.elements[0].terms[0].arguments[0] == []:
            varname = atom.elements[0].terms[0].arguments[0].name
        else: 
            varname = str(atom.elements[0].terms[0].arguments[0])
        if "none" in str(atom.elements[0].terms[0].arguments[1].name):
            lb = 'none'
        else:
            if atom.elements[0].terms[0].arguments[1].arguments != []:
                lb = -float(str(atom.elements[0].terms[0].arguments[1].arguments[0])[1:-1])
            else:
                lb = float(str(atom.elements[0].terms[0].arguments[1])[1:-1])
        if "none" in str(atom.elements[0].terms[0].arguments[2].name):
            ub = 'none'
        else:
            if atom.elements[0].terms[0].arguments[2].arguments != []:
                ub = -float(str(atom.elements[0].terms[0].arguments[2].arguments[0])[1:-1])
            else:
                ub = float(str(atom.elements[0].terms[0].arguments[2])[1:-1])
        self.__bounds[varname] = (lb,ub)



    # true if lp_trail was narrowed
    def lp_removed(self, state): 
        if state.lp_trail <= self.__lp_trail_s: 
            state.lp_trail_old = state.lp_trail[:]
            return True
        else:
            return False



    # true if lp_trail was extended
    def lp_added(self, state): 
        if set(self.__lp_trail_s) <= set(state.lp_trail): 
            return True
        else:
            return False



    # true if conditional literal in lp changed
    def clit_in_lp_trail_changed(self, state): 
        for lit in state.lp_trail:
            for clit in self.__clist_clits[abs(lit)]: 
                if clit in state.cond_trail and -clit in self.__cond_trail_s:
                    return True
        return False 



    # checks if all conditionals of constraints in lp_trail
    def solve_lp(self,state):
        for lit in state.lp_trail: 
            for clit in self.__clist_clits[abs(lit)]: 
                if not clit in state.cond_trail and not -clit in state.cond_trail:
                    return False
        for clit in self.__obj_cond_lit: 
            if not clit in state.cond_trail and not -clit in state.cond_trail:
                return False 
        return True



    def __set_lpsolve(self,state): 
        if not self.solve_lp(state): 
            return True
        self.__set_obj(state)
        self.__cond_trail_s = state.cond_trail[:] 
        if self.lp_removed(state) or self.initial or self.clit_in_lp_trail_changed(state) or self.reset:
            self.reset = self.__reset_mat(state) 
        elif self.lp_added(state): 
            self.__add_rows(state) 
        self.__lp_trail_s = state.lp_trail[:]
        nvar = len(self.__varpos)
        if self.initial: 
            self.initial = False
            self.__reset_lpsolve(nvar)
        elif self.reset: 
            self.reset = False
            lpsolve('delete_lp', self.lp)
            self.__reset_lpsolve(nvar)
        else:
            self.__add_lpsolve(self.__clist[-1], nvar)
        self.__set_fopt()
        lpsolve('solve', self.lp) 
        status = lpsolve('get_status', self.lp)
        if status == 2 or status > 3: 
            return False
        sdict = {}
        slist = [] 
        res = lpsolve('get_variables', self.lp)[0]
        if isinstance(res, float):
            slist.append(res)
        else:
            slist.extend(res)
        if self.__accuracy > 0 and self.__accuracy < 15: 
            for var in self.__varpos:
                sdict[var] = round(slist[self.__varpos[var]-1],self.__accuracy)
            state.solution = (round(lpsolve('get_objective', self.lp),self.__accuracy), sdict)
        else:
            for var in self.__varpos:
                sdict[var] = round(round(slist[self.__varpos[var]-1],1),0)
            state.solution = (round(round(lpsolve('get_objective', self.lp),1),0), sdict)
        return True



    # set objective function in lp
    def __set_fopt(self):
        self.__fopt = [0]*len(self.__varpos)
        for varname in self.__varpos:
            self.__fopt[self.__varpos[varname]-1] = self.__wopt[varname]
        lpsolve('set_obj_fn', self.lp, self.__fopt)



    # reset lpsolve
    def __reset_lpsolve(self, nvar): 
        self.lp = lpsolve('make_lp', 0, nvar) 
        lpsolve('set_verbose', self.lp, IMPORTANT) 
        for varname in self.__varpos:
            if varname in self.__bounds:
                lb = self.__bounds[varname][0]
                ub = self.__bounds[varname][1]
                if lb != 'none':
                    lpsolve('set_lowbo', self.lp, self.__varpos[varname], lb)
                if ub != 'none':
                    lpsolve('set_upbo', self.lp, self.__varpos[varname], ub)
        if self.__optim == 'max':
            lpsolve('set_maxim', self.lp)
        else: 
            lpsolve('set_minim', self.lp)
        for constr in self.__clist: 
            self.__add_lpsolve(constr, nvar)



    # add lp constraint
    def __add_lpsolve(self, constr, nvar): 
        tmp = [0]*nvar
        for varname in self.__varpos:
            if varname in constr[0]:
                tmp[self.__varpos[varname]-1] = constr[0][varname]
        lpsolve('add_constraint', self.lp, tmp, constr[1], constr[2])    



    # sets objective vector
    def __set_obj(self, state): 
        self.__wopt = {}
        for varname in self.__varpos:
            self.__wopt.setdefault(varname,0)
        for varname in self.__objective: 
            tmp = 0
            for weight in self.__objective[varname]:
                if not isinstance(weight, dict):
                    tmp = tmp + weight
                else:
                    for clit in weight:
                        if clit in state.cond_trail:
                            tmp = tmp + weight[clit]
            if tmp != 0:
                self.__wopt[varname] = tmp 
        return True



    # reset matrix and return reset=True
    def __reset_mat(self, state): 
        self.__clist = []     
        for lit in state.lp_trail: 
            if lit in self.__structure:
                self.__add_row(state, lit, False)
            elif -lit in self.__structure and not self.__nstrict:
                self.__add_row(state, -lit, True)
        return True


    # add a row
    def __add_row(self, state, lit, neg): 
        for constr in self.__structure[lit]: 
            trow = {}               
            rel = constr[1]
            b = constr[2] 
            for varname in constr[0]:
                tmp = 0
                for weight in constr[0][varname]:
                    if not isinstance(weight, dict):
                        tmp = tmp + weight
                    else:
                        for clit in weight: 
                            if clit in state.cond_trail:
                                tmp = tmp + weight[clit]
                if varname in self.__varpos:
                    trow[varname] = tmp 
                elif tmp != 0:
                    trow[varname] = tmp
            if neg:
                if rel == '<': 
                    rel = '>='
                elif rel == '>': 
                    rel = '<='
                elif rel == '>=': 
                    rel = '<='
                    b = b - self.__epsilon
                elif rel == '<=': 
                    rel = '>='
                    b = b + self.__epsilon
            else:
                if rel == '<':
                    rel = '<='
                    b = b - self.__epsilon
                elif rel == '>':
                    rel = '>='
                    b = b + self.__epsilon
            self.__clist.append((trow, rel, b))


    # add severeal rows to clist
    def __add_rows(self, state): 
        for lit in list(set(state.lp_trail)-set(self.__lp_trail_s)):
            if lit in self.__structure:
                self.__add_row(state, lit, False)              
            elif -lit in self.__structure and not self.__nstrict:
                self.__add_row(state, -lit, True)



    # return a list of necessary vars 
    def __used_vars(self, state): 
        tset = set()
        for lit in state.lp_trail: 
            for constr in self.__structure[abs(lit)]:
                for varname in constr[0]:
                    tmp = 0
                    for weight in constr[0][varname]:
                        if not isinstance(weight, dict):
                            tmp = tmp + weight
                        else:
                            for clit in weight: 
                                if clit in state.cond_trail:
                                    tmp = tmp + weight[clit]
                    if tmp != 0:
                        tset.add(varname)
        for varname in self.__objective: 
            tmp = 0
            for weight in self.__objective[varname]:
                if not isinstance(weight, dict):
                    tmp = tmp + weight
                else:
                    for clit in weight:
                        if clit in state.cond_trail:
                            tmp = tmp + weight[clit]
            if tmp != 0: 
                tset.add(varname)
        return tset



    # updates varpos dict 
    def __update_pos(self, uv):
        for var in uv:
            if var not in self.__varpos:
                self.__varpos[var]=len(self.__varpos)+1



    def propagate(self, control, changes):
        state = self.__state(control.thread_id)
        state_old = self.State()
        state_old.lp_trail = state.lp_trail[:]
        state_old.cond_trail = state.cond_trail[:]
        if len(state.stack) == 0 or state.stack[-1][0] < control.assignment.decision_level:
            state.stack.append((control.assignment.decision_level, len(state.lp_trail), len(state.cond_trail)))
        for lit in changes: 
            if lit in self.__structure or -lit in self.__structure:
                state.lp_trail_old = state.lp_trail[:]
                state.lp_trail.append(lit)
            if lit in self.__mat_cond_lit or lit in self.__obj_cond_lit or -lit in self.__mat_cond_lit or -lit in self.__obj_cond_lit: 
                state.cond_trail_old = state.cond_trail[:]
                state.cond_trail.append(lit)
        uvo = self.__used_vars(state_old)
        uv = self.__used_vars(state)
        if len((uv|uvo)-(uv&uvo)) != 0: 
            self.reset = True
            self.__varpos = dict(self.__varpos_obj)
            self.__update_pos(uv)
        if not self.__set_lpsolve(state): 
            clause = map(lambda x : -x, list(set(state.cond_trail) | set(state.lp_trail)))
            if not control.add_clause(clause) or not control.propagate():
                return False
        return True



    def undo(self, thread_id, assign, changes): 
        state = self.__state(thread_id)
        lpid = state.stack[-1][1]
        del state.lp_trail[lpid:]
        cid = state.stack[-1][2]
        del state.cond_trail[cid:]
        state.stack.pop()
        self.reset = True 



    def check(self, control): 
        state = self.__state(control.thread_id)
        self.s_out.append(state.solution)
        self.reset = True 
        return True



    def __on_model(self, model):
        print ''
        print '-------------------------------'
        print 'Solution', len(self.s_out)
        print ''
        #print 'predicates'
        #print model
        if self.__show:
            print 'constraints'
            for constr in self.__clist:
                print constr 
            print 'objective'
            print self.__wopt
        print 'lpsolve solution'
        print self.s_out[-1] 
        print ''



    def run(self, prg):
        prg.configuration.solve.models = 0 
        prg.ground([("base", [])])
        prg.solve(self.__on_model) 
        


def main(prg):
    prop = Propagator(prg.get_const("show"), prg.get_const("accuracy"), prg.get_const("nstrict"), prg.get_const("epsilon"))
    prg.register_propagator(prop)
    prop.run(prg)

#end.
