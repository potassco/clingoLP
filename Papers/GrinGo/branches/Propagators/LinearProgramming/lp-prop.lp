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
            self.solution = None        # (state, opt, {varname : value})



    def __state(self, sid):
        while len(self.__states) <= sid:
            self.__states.append(Propagator.State())
        return self.__states[sid]



    def __init__(self, trace):
        self.__structure = {}           # {literal:[(weights,guard,const)]}
        self.__states = []              # [state]
        self.__objective = []           # [weights]
        self.__optim = ''               # min or max
        self.__bounds = {}              # {varname : (lower bound, upper bound)}
        self.__varpos = {}              # {varname : var_pos}
        self.s_out = []                 # [(state, opt, {varname : value})]
        self.__trace = trace
        self.__epsilon = sys.float_info.epsilon*10
        self.models = []



    def init(self, init):
        for atom in init.theory_atoms:
            term = atom.term
            if term.name == 'lp':
                self.__lp_structure(atom, init)
            if term.name == 'objective':
                self.__lp_objective(atom)
            if term.name == 'dom':
                self.__lp_domain(atom)



    def __lp_structure(self, atom, init): 
        lit=init.solver_literal(atom.literal)
        init.add_watch(lit)
        weights = {}                    # {varname:weights or dict of conditions with weights} 
        lhs = atom.elements
        rhs = atom.guard[1]
        rel = atom.guard[0]
        for elem in lhs:
            pol = 1
            if elem.terms[0].name == '-':
                pol = -1
            varname = elem.terms[0].args[1].name
            koef = elem.terms[0].args[0]
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_literal)
                init.add_watch(clit)
                if koef.args != []:
                    weights.setdefault(varname,{})[clit] = -float(str(koef.args[0])[1:-1])
                else:
                    weights.setdefault(varname,{})[clit] = float(str(koef)[1:-1])
            else:
                if koef.args != []:
                    weights[varname] = -float(str(koef.args[0])[1:-1])
                else:
                    weights[varname] = float(str(koef)[1:-1])
        if rhs.args != []:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,-float(str(rhs.args[0])[1:-1])))
        else:
            self.__structure.setdefault(lit,[]).append((dict(weights),rel,float(str(rhs)[1:-1])))



    def __lp_objective(self, atom):
        obj = atom.elements
        col_pos = 0
        self.__optim = str(atom.term.args[0])
        for elem in obj:
            pol = 1
            if elem.terms[0].name == '-':
                pol = -1
            varname = elem.terms[0].args[1].name
            koef = elem.terms[0].args[0]
            if koef.args != []:
                self.__objective.append(-float(str(koef.args[0])[1:-1]))
            else:
                self.__objective.append(float(str(koef)[1:-1]))
            if varname not in self.__varpos: 
                col_pos = col_pos+1
                self.__varpos[varname] = col_pos



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



    def __set_lpsolve(self,state):
        clist = []                      # [(trow, rel, b)]
        varpos = dict(self.__varpos)    # {varname : col_pos}
        col_pos = len(varpos)           # len of opt vars
        fopt = self.__objective[:]      # copy static wopt
        nconstr = 0
        for lit in state.lp_trail:
            for constr in self.__structure[lit]:
                nconstr = nconstr +1
                trow = {}               # { varname : weights}
                rel = constr[1]
                b = constr[2] 
                for varname in constr[0]:
                    weight = 0
                    if not isinstance(constr[0][varname], dict):
                        weight = constr[0][varname]
                    else:
                        for clit in constr[0][varname]:
                            if clit in state.cond_trail:
                                weight = weight + constr[0][varname][clit]
                    if weight != 0:
                        if varname not in varpos: 
                            col_pos = col_pos+1
                            varpos[varname] = col_pos
                            fopt.append(0)
                        trow[varname] = weight
                if rel == '<':
                    rel = '<='
                    b = b - self.__epsilon
                elif rel == '>':
                    rel = '>='
                    b = b + self.__epsilon
                clist.append((trow, rel, b))
        nvar = len(varpos)
        lp = lpsolve('make_lp', nconstr, nvar)
        lpsolve('set_verbose', lp, IMPORTANT)
        for constr in clist:
            tmp = [0]*nvar
            for varname in varpos:
                if varname in constr[0]:
                    tmp[varpos[varname]-1] = constr[0][varname]
            lpsolve('add_constraint', lp, tmp, constr[1], constr[2])
        for varname in varpos:
            if varname in self.__bounds:
                lb = self.__bounds[varname][0]
                ub = self.__bounds[varname][1]
                if lb != 'none':
                    lpsolve('set_lowbo', lp, varpos[varname], lb)
                if ub != 'none':
                    lpsolve('set_upbo', lp, varpos[varname], ub)
        if self.__optim == 'max':
            lpsolve('set_maxim', lp)
        else: 
            lpsolve('set_minim', lp)
        lpsolve('set_obj_fn', lp, fopt) 
        lpsolve('solve', lp)
        status = lpsolve('get_status', lp)
        if status == 2 or status > 3:  
            lpsolve('delete_lp', lp) 
            return False
        sdict = {}
        slist = lpsolve('get_variables', lp)[0]
        for var in varpos:
            sdict[var] = slist[varpos[var]-1]
        state.solution = (lpsolve('get_objective', lp), sdict)
        lpsolve('delete_lp', lp)
        return True



    def propagate(self, control, assign, changes):
        state = self.__state(control.id)
        if len(state.stack) == 0 or state.stack[-1][0] < assign.decision_level:
            state.stack.append((assign.decision_level, len(state.lp_trail), len(state.cond_trail)))
        for lit in changes:
            if lit in self.__structure:
                state.lp_trail.append(lit)
            else:
                state.cond_trail.append(lit)
        if not self.__set_lpsolve(state):
            clause = map(lambda x : -x, state.lp_trail)
            clause.extend(map(lambda x : -x, state.cond_trail))
            if not control.add_clause(clause) or not control.propagate():
                return False
        return True



    def undo(self, solver_id, undo): 
        state = self.__state(solver_id)
        lpid = state.stack[-1][1]
        del state.lp_trail[lpid:]
        cid = state.stack[-1][2]
        del state.cond_trail[cid:]
        state.stack.pop()



    def check(self, control, assign):
        state = self.__state(control.id)
        self.s_out.append(state.solution)
        return True



    def onModel(self,model):
        tmp = []
        for i in xrange(len(model.atoms(shown=True))): 
            tmp.insert(i,str(model.atoms(shown=True)[i]))
        self.models.insert(0,tmp)



    def out(self):
        if len(self.models) >0:
            for i in range(len(self.models)):
                outstr = ''
                print ''
                print 'Answer: '+str(i+1)
                for a in self.models[i]:
                   outstr = outstr+', '+str(a)
                print outstr[2:], '\nlpsolve solution:\n'+str(self.s_out[-(i+1)])+'\n'
            print 'SATISFIABLE'
            print 
            print 'Models       : '+str(len(self.models))
          #  print 'Time         : '+'not known yet!!!'
        else:
            print 'UNSATISFIABLE'



def main(prg):
    prg.conf.solve.models = 0 
    prop = Propagator(bool(prg.get_const("trace")))
    prg.register_propagator(prop)
    prg.ground([("base", [])])
    prg.solve([],prop.onModel)
    prop.out()

#end.
