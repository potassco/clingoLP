#script (python)

from lp_solve import *
import gringo
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



    def __init__(self, show, accuracy):
        self.__structure = {}           # {literal : [(weights,guard,const)]}
        self.__states = []              # [state]
        self.__objective = {}           # {varname : [weight or {clit : weight}]}
        self.__mat_cond_lit = set()     # {matclit}
        self.__obj_cond_lit = set()     # {objclit}
        self.__optim = ''               # min or max
        self.__bounds = {}              # {varname : (lower bound, upper bound)}
        self.__varpos = {}              # {varname : var_pos}
        self.__varpos_old = {}
        self.s_out = []                 # [(state, opt, {varname : value})]
        self.__wopt = {}                # {varname : weight} 
        self.__fopt = []                # [fopt weights in varpos order]
        self.__clist = []               # [({varname : weights}, rel, brow)]
        self.lp = []
        self.__epsilon = sys.float_info.epsilon*10
        self.initial = False
        if 'None' == str(accuracy):   
            self.__accuracy = 0
        else:
            self.__accuracy = accuracy.number
        if 'None' == str(show) or show.number != 1:
            self.__show = False
        else:
            self.__show = True



    def init(self, init):
        for atom in init.theory_atoms:
            term = atom.term
            if term.name == 'lp':
                self.__lp_structure(atom, init)
            if term.name == 'objective':
                self.__lp_objective(atom, init)
            if term.name == 'dom':
                self.__lp_domain(atom)



    def __lp_structure(self, atom, init): 
        lit=init.solver_literal(atom.literal)
        init.add_watch(lit)
        weights = {}              
        lhs = atom.elements
        rhs = atom.guard[1]
        rel = atom.guard[0]
        for elem in lhs:
            varname = elem.terms[0].args[1].name
            koef = elem.terms[0].args[0]
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_literal)
                init.add_watch(clit)
                self.__mat_cond_lit.add(clit)
                tmp = {}
                if koef.args != []:
                    tmp[clit] = -float(str(koef.args[0])[1:-1])
                    weights.setdefault(varname,[]).append(tmp)
                else:
                    tmp[clit] = float(str(koef)[1:-1])
                    weights.setdefault(varname,[]).append(tmp)
            else:
                if koef.args != []:
                    weights.setdefault(varname,[]).append(-float(str(koef.args[0])[1:-1]))
                else:
                    weights.setdefault(varname,[]).append(float(str(koef)[1:-1]))
        if rhs.args != []:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,-float(str(rhs.args[0])[1:-1])))
        else:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,float(str(rhs)[1:-1])))



    def __lp_objective(self, atom, init):
        obj = atom.elements 
        col_pos = len(self.__varpos) 
        self.__optim = str(atom.term.args[0])
        for elem in obj:
            varname = elem.terms[0].args[1].name
            koef = elem.terms[0].args[0]
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_literal)
                init.add_watch(clit) 
                self.__obj_cond_lit.add(clit)
                tmp = {}
                if koef.args != []:
                    tmp[clit] = -float(str(koef.args[0])[1:-1])
                    self.__objective.setdefault(varname,[]).append(tmp)
                else:
                    tmp[clit] = float(str(koef)[1:-1])
                    self.__objective.setdefault(varname,[]).append(tmp)
            else:
                if koef.args != []:
                    self.__objective.setdefault(varname,[]).append(-float(str(koef.args[0])[1:-1]))
                else:
                    self.__objective.setdefault(varname,[]).append(float(str(koef)[1:-1]))
        for varname in self.__objective: 
            tmp = 0
            for weight in self.__objective[varname]:
                if not isinstance(weight, dict):
                    tmp = tmp + weight
            if tmp != 0: 
                col_pos = col_pos +1
                self.__varpos[varname] = col_pos 
                self.__wopt[varname] = tmp
        self.__varpos_old = dict(self.__varpos)



    def __lp_domain(self, atom):
        varname = atom.elements[0].terms[0].name
        if str(atom.elements[1].terms[0]) == 'none':
            lb = 'none'
        else:
            if atom.elements[1].terms[0].args != []:
                lb = -float(str(atom.elements[1].terms[0].args[0])[1:-1])
            else:
                lb = float(str(atom.elements[1].terms[0])[1:-1])
        if str(atom.elements[2].terms[0]) == 'none':
            ub = 'none'
        else:
            if atom.elements[2].terms[0].args != []:
                ub = -float(str(atom.elements[2].terms[0].args[0])[1:-1])
            else:
                ub = float(str(atom.elements[2].terms[0])[1:-1])
        self.__bounds[varname] = (lb,ub)



    def lp_removed(self, state):
        if len(state.lp_trail) < len(state.lp_trail_old):
            state.lp_trail_old = state.lp_trail[:]
            return True
        else:
            return False



    def lp_added(self, state):
        if len(state.lp_trail) > len(state.lp_trail_old):
            state.lp_trail_old = state.lp_trail[:]
            return True
        else:
            return False



    def clit_in_lp_trail_changed(self, state):
        changed = self.clit_change(state)
        if len(changed) > 0 and changed.issubset(self.__mat_cond_lit):
            return True
        else:
            return False



    def clit_in_obj_trail_changed(self, state):
        changed = self.clit_change(state)
        if len(changed) > 0 and changed.issubset(self.__obj_cond_lit):
            return True
        else:
            return False
        


    def clit_change(self, state):
        if len(state.cond_trail) > len(state.cond_trail_old):
            changed = set(state.cond_trail).difference(set(state.cond_trail_old))
        else: 
            changed = set(state.cond_trail_old).difference(set(state.cond_trail))
        return changed



    def varpos_changed(self):
        if set(self.__varpos).issubset(set(self.__varpos_old)) and set(self.__varpos).issuperset(set(self.__varpos_old)):
            return False
        else:
            self.__varpos_old = dict(self.__varpos)
            return True



    def __set_lpsolve(self,state):
        reset = False
        set_obj = False
        if self.clit_in_obj_trail_changed(state): 
            set_obj = self.__set_obj(state)
        varpos_obj = dict(self.__varpos)
        if self.lp_removed(state) or self.varpos_changed() or self.clit_in_lp_trail_changed(state): 
            reset = self.__reset_mat(state) 
        elif self.lp_added(state): 
            self.__add_row(state)
        nvar = len(self.__varpos)
        if reset or not self.initial: 
            if not self.initial:
                self.initial = True
                self.__reset_lpsolve(nvar)
                self.__set_fopt()
            else:
                lpsolve('delete_lp', self.lp)
                self.__reset_lpsolve(nvar)
        else:
            self.__add_lpsolve(self.__clist[-1], nvar)
        if set_obj:
            self.__set_fopt()
        self.__varpos_old = dict(self.__varpos)
        self.__varpos = dict(varpos_obj)
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
            for var in self.__varpos_old:
                sdict[var] = round(slist[self.__varpos_old[var]-1],self.__accuracy)
            state.solution = (round(lpsolve('get_objective', self.lp),self.__accuracy), sdict)
        else:
            for var in self.__varpos_old:
                sdict[var] = slist[self.__varpos_old[var]-1]
            state.solution = (lpsolve('get_objective', self.lp), sdict)
        return True



    def __set_fopt(self):
        self.__fopt = [0]*len(self.__varpos)
        for varname in self.__varpos:
            self.__fopt[self.__varpos[varname]-1] = self.__wopt[varname]
        lpsolve('set_obj_fn', self.lp, self.__fopt)



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



    def __add_lpsolve(self, constr, nvar):
        tmp = [0]*nvar
        for varname in self.__varpos:
            if varname in constr[0]:
                tmp[self.__varpos[varname]-1] = constr[0][varname]
        lpsolve('add_constraint', self.lp, tmp, constr[1], constr[2])    



    def __set_obj(self, state): 
        self.__wopt = {}
        col_pos = 0 
        self.__varpos = {}
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
                col_pos = col_pos +1
                self.__varpos[varname] = col_pos 
                self.__wopt[varname] = tmp
        return True



    def __reset_mat(self, state): 
        self.__clist = []              
        col_pos = len(self.__varpos)
        for lit in state.lp_trail: 
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
                    if tmp != 0:
                        if varname not in self.__varpos: 
                            col_pos = col_pos+1
                            self.__varpos[varname] = col_pos
                            self.__wopt[varname] = 0
                        trow[varname] = tmp
                if rel == '<':
                    rel = '<='
                    b = b - self.__epsilon
                elif rel == '>':
                    rel = '>='
                    b = b + self.__epsilon
                self.__clist.append((trow, rel, b))
        return True



    def __add_row(self, state):
        lit = state.lp_trail[state.stack[-1][1]]
        col_pos = len(self.__varpos)
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
                if tmp != 0:
                    if varname not in self.__varpos: 
                        col_pos = col_pos+1
                        self.__varpos[varname] = col_pos
                        self.__wopt[varname] = 0
                    trow[varname] = tmp
            if rel == '<':
                rel = '<='
                b = b - self.__epsilon
            elif rel == '>':
                rel = '>='
                b = b + self.__epsilon
            self.__clist.append((trow, rel, b))



    def propagate(self, control, changes):
        state = self.__state(control.thread_id)
        if len(state.stack) == 0 or state.stack[-1][0] < control.assignment.decision_level:
            state.stack.append((control.assignment.decision_level, len(state.lp_trail), len(state.cond_trail)))
        for lit in changes:
            if lit in self.__structure:
                state.lp_trail_old = state.lp_trail[:]
                state.lp_trail.append(lit)
            else:
                state.cond_trail_old = state.cond_trail[:]
                state.cond_trail.append(lit)
        if not self.__set_lpsolve(state):
            clause = map(lambda x : -x, state.lp_trail)
            clause.extend(map(lambda x : -x, state.cond_trail))
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



    def check(self, control):
        state = self.__state(control.thread_id)
        self.s_out.append(state.solution)
        print '---------------------------------' 
        if self.__show:
            print 'constraints'
            for constr in self.__clist:
                print constr 
            print 'objective'
            print self.__wopt
        print 'lpsolve solution'
        print self.s_out[-1] 
        return True



def main(prg):
    prg.conf.solve.models = 0 
    prop = Propagator(prg.get_const("show"), prg.get_const("accuracy"))
    prg.register_propagator(prop)
    prg.ground([("base", [])])
    prg.solve()

#end.
