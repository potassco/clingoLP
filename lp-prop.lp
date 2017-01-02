#include "theory_lp.lp".

% option data defaults
#const show=0.
#const accuracy=1.
#const epsilon=(1,5).
#const nstrict=0.
#const solver=cplx.
#const trace=0.
#const core_confl=100.
#const prop_heur=0.
#const debug=0.

#script (python)

#TODO ilp: - lpsolve(lp, column,'must_be_int') (?) for variables !!!!!!! http://lpsolve.sourceforge.net/5.5/set_int.htm

import sys
import time


class Propagator:

    class State:

        def __init__(self):
            self.stack = []             # [(decision level, lp_trail index, cond_trail index, oclit_trail index)]
            self.lp_trail = []          # [lp literal]
            self.eq_trail = []          # [nlit]
            self.cond_trail = []        # [conditional literals]
            self.eqlit = {}             # {cnum : nlit}
            self.eqlit_inv = {}         # {nlit : cnum}
            self.clist = {}             # {cnum : ({varname : weights}, rel, brow)}
            self.active_cnum = {}       # {cnum : [clit_undec, truth_value]}
            self.recent_active = []     # [cnum]
            self.total_lits = 0
            self.oclit_trail = []       # [oclits]
            self.oclit_recent_active = 0
            self.active_oclit = 0       # number of undec oclits
            self.lits_current = 0       # number of decided watched literals
            self.lp = None              # lpsolve object  



    def __state(self, sid): 
        while len(self.__states) <= sid:
            self.__states.append(Propagator.State())
            state = self.__states[len(self.__states)-1]
            state.total_lits = self.__lits_total_num
            for cnum in self.__constr:
                if not cnum in self.__constr_clit:
                    state.active_cnum[cnum] = [0,0,0]
                else:
                    state.active_cnum[cnum] = [len(self.__constr_clit[cnum]),0,0]
            state.active_oclit = len(self.__obj_cond_lit)
            try:
                lp_solver_class = globals()[self.__solver] 
                state.lp = lp_solver_class(self.__varpos, self.__bounds)
            except:
                print 'No wrapper class of ', self.__solver, ' found!'
                exit()
        return self.__states[sid]



    def __init__(self, show, accuracy, nstrict, epsilon, solver, trace, core_confl, prop_heur, debug):
        self.__var_ta = {}              # {abs(lit) : [cnum]}
        self.__lit_ta = {}              # {lit : [cnum]}
        self.__constr = {}              # {cnum : (lit,constr)}
        self.__clit_constr = {}         # {clit : [cnum]}
        self.__constr_clit = {}         # {cnum : [clits]}
        self.__states = []              # [state]
        self.__objective = {}           # {varname : [weight or {clit : weight}]}
        self.__obj_cond_lit = set()     # {objclit}
        self.__optim = ''               # min or max
        self.__bounds = {}              # {varname : (lower bound, upper bound)}
        self.__varpos = {}              # {varname : var_pos}
        self.__vars = set()             # {vars} 
        self.__wopt = {}                # {varname : weight}
        self.__lits_total = set()       # set of all watched literals
        self.__lits_total_num = 0       # number of watched literals
        self.__time = 0.0               # get time of propagation
        self.__inittime = 0.0
        self.__initcalls = 0
        self.__proptime = 0.0
        self.__propcalls = 0
        self.__undotime = 0.0
        self.__undocalls = 0
        self.__checktime = 0.0
        self.__checkcalls = 0
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
        if 'None' == str(epsilon): # epsilon=(a,b) -> a*10^-b
            self.__epsilon = 0.00001 #sys.float_info.epsilon*10 is too low -> round problems
        else:
            tmp = str(epsilon)[1:-1].split(",")
            koef = float(tmp[0])
            exp = float(tmp[1])
            self.__epsilon = koef*10**-exp
        if 'None' == str(trace) or trace.number != 1:
            self.__trace = False
        else:
            self.__trace = True
        if 'None' == str(core_confl):
            self.__core_confl_heur = 100
        else:
            self.__core_confl_heur = core_confl.number
        if 'None' == str(prop_heur):
            self.__prop_heur = 100
        else:
            self.__prop_heur = prop_heur.number
        self.__solver = solver.name
        if 'None' == str(debug):
            self.__debug = 0
        else:
            self.__debug = debug.number



    def init(self, init):
        start = time.clock()
        for atom in init.theory_atoms:
            term = atom.term
            if term.name == 'lp':
                self.__lp_structure(atom, init)
            if term.name == 'objective':
                self.__lp_objective(atom, init)
            if term.name == 'dom':
                self.__lp_domain(atom)
        self.__lits_total_num = len(self.__lits_total)
        col_pos = 0
        for varname in self.__vars:
            col_pos = col_pos +1
            self.__varpos[varname] = col_pos
        end = time.clock()
        self.__inittime += end-start
        self.__initcalls += 1
        self.__time = self.__time + end-start



    # resolves structure of lp-statements and saves it
    def __lp_structure(self, atom, init): 
        lit=init.solver_literal(atom.literal)
        n = len(self.__constr)+1
        init.add_watch(lit)
        init.add_watch(-lit)
        var = abs(lit)
        self.__lits_total.add(var)
        weights = {}
        lhs = atom.elements
        rhs = atom.guard[1]
        rel = atom.guard[0]
        for elem in lhs:
            if elem.terms[0].arguments[1].arguments == []:
                varname = elem.terms[0].arguments[1].name
            else:
                varname = str(elem.terms[0].arguments[1])
            self.__vars.add(varname)
            koef = self.__calc_bound(elem.terms[0].arguments[0])
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_id) 
                init.add_watch(clit)
                init.add_watch(-clit)
                aclit = abs(clit)
                self.__lits_total.add(aclit)
                self.__clit_constr.setdefault(aclit,[])
                if not n in self.__clit_constr[aclit]:
                    self.__clit_constr[aclit].append(n)
                self.__constr_clit.setdefault(n,[])
                if not clit in self.__constr_clit[n]:
                    self.__constr_clit[n].append(aclit) 
                    self.__constr_clit[n] = list(set(self.__constr_clit[n]))
                tmp = {}
                tmp[clit] = self.__calc_bound(elem.terms[0].arguments[0])
                weights.setdefault(varname,[]).append(tmp)
            else:
                weights.setdefault(varname,[]).append(koef)
        self.__constr[n] = (lit, (dict(weights),rel,self.__calc_bound(rhs)))
        self.__var_ta.setdefault(var,[]).append(n)
        self.__lit_ta.setdefault(lit,[]).append(n)



    # resolves structure of objective-statements and saves it
    def __lp_objective(self, atom, init):
        obj = atom.elements
        self.__optim = str(atom.term.arguments[0])
        for elem in obj:
            varname = elem.terms[0].arguments[1].name
            self.__vars.add(varname)
            koef = self.__calc_bound(elem.terms[0].arguments[0])
            if elem.condition != []:
                clit = init.solver_literal(elem.condition_id)
                aclit = abs(clit)
                init.add_watch(clit)
                init.add_watch(-clit)
                self.__lits_total.add(aclit)
                self.__obj_cond_lit.add(aclit)
                tmp = {}
                tmp[clit] = self.__calc_bound(elem.terms[0].arguments[0])
                self.__objective.setdefault(varname,[]).append(tmp)
            else:
                self.__objective.setdefault(varname,[]).append(koef)
        if len(self.__obj_cond_lit) == 0:
            for varname in self.__objective:
                weight = sum(self.__objective[varname])
                if weight != 0:
                    self.__wopt[varname] = weight



    # resolves structure of domain-statements and saves it
    def __lp_domain(self, atom):
        if atom.elements[0].terms[0].arguments[0] == []:
            varname = atom.elements[0].terms[0].arguments[0].name
        else:
            varname = str(atom.elements[0].terms[0].arguments[0])
        if "none" in str(atom.elements[0].terms[0].arguments[1]):
            lb = 'none'
        else:
            lb = self.__calc_bound(atom.elements[0].terms[0].arguments[1])
        if "none" in str(atom.elements[0].terms[0].arguments[2]):
            ub = 'none'
        else:
            ub = self.__calc_bound(atom.elements[0].terms[0].arguments[2])
        self.__bounds[varname] = (lb,ub)



    # calculates bounds of input expressions
    def __calc_bound(self, expr):
        args = expr.arguments
        tmp = 0
        if len(args) == 2:
            if expr.name == '+':
                tmp = self.__calc_bound(args[0])+self.__calc_bound(args[1])
            elif expr.name == '-':
                tmp = self.__calc_bound(args[0])-self.__calc_bound(args[1])
            elif expr.name == '*':
                tmp = self.__calc_bound(args[0])*self.__calc_bound(args[1])
            elif expr.name == '/':
                tmp = self.__calc_bound(args[0])/self.__calc_bound(args[1])
        elif len(args) == 1:
            if args[0].arguments == []:
                tmp = -self.__get_number(args[0])
            else:
                tmp = -self.__calc_bound(args[0])
        else:
            tmp = self.__get_number(expr)
        return tmp



    # cast gringo number or string to float
    def __get_number(self, num):
        if str(num)[0] != '"':
            return float(num.number)
        else:
            return float(str(num)[1:-1])



    # solve call
    def __solve(self, state):
        if state.lp.is_valid():
            state.clist.update(self.__get_constrs(state, state.recent_active))
            cnums = state.recent_active
        else:
            state.clist = dict(self.__get_constrs(state, [cnum for cnum in state.active_cnum if state.active_cnum[cnum][0] == 0 and state.active_cnum[cnum][1] != 0]))
            cnums = state.clist.keys()
        if state.active_oclit == 0:
            if self.__wopt == {}:
                obj = self.__set_obj(state)
            else:
                obj = self.__wopt
            state.oclit_recent_active = 0 
            state.lp.set_obj(obj, self.__optim)
        clist = []
        for cnum in cnums:
            clist.append(state.clist[cnum])
        state.lp.add_constr(clist)
        state.lp.solve_lp()



    # get constraints wrt current assignment
    def __get_constrs(self, state, cnums):
        clist = {}
        for cnum in cnums:
            clist[cnum] = (self.__get_constr(state,cnum))
        return clist
        


    # evaluates constr wrt current assignment
    def __get_constr(self, state, cnum): 
        constr = self.__constr[cnum][1] 
        trow = {}
        rel = constr[1]
        b = constr[2]
        for varname in constr[0]: 
            weight = self.__get_weight(state.cond_trail, constr[0][varname])
            if varname in self.__varpos: 
                trow[varname] = weight
        if state.active_cnum[cnum][1] < 0 and not self.__nstrict:
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
            elif rel == '!=':
                rel = '='
            elif rel == '=':
                if state.eqlit[cnum] in state.eq_trail:
                    rel = '>='
                    b = b + self.__epsilon
                elif -state.eqlit[cnum] in state.eq_trail:
                    rel = '<='
                    b = b - self.__epsilon
        elif state.active_cnum[cnum][1] > 0:
            if rel == '<':
                rel = '<='
                b = b - self.__epsilon
            elif rel == '>':
                rel = '>='
                b = b + self.__epsilon
            elif rel == '!=':
                if state.eqlit[cnum] in state.eq_trail:
                    rel = '>='
                    b = b + self.__epsilon
                elif -state.eqlit[cnum] in state.eq_trail:
                    rel = '<='
                    b = b - self.__epsilon
        return (trow, rel, b)




    # sets objective dictionary {var: weight} wrt conditionals
    def __set_obj(self, state): 
        wopt = {} 
        for varname in self.__varpos:
            wopt.setdefault(varname,0)
        for varname in self.__objective:
            weight = self.__get_weight(state.oclit_trail, self.__objective[varname])
            wopt[varname] = weight
        return wopt



    # calculates weight of variable wrt a state
    def __get_weight(self, clits, w_list): 
        tmp = 0
        for weight in w_list:
            if not isinstance(weight, dict):
                tmp = tmp + weight
            else:
                for clit in weight:
                    if clit in clits:
                        tmp = tmp + weight[clit]
        return tmp
       


    def propagate(self, control, changes): 
        start = time.clock()
        self.__update_state(control, changes)
        state = self.__state(control.thread_id)
        if (state.recent_active != [] or state.oclit_recent_active == 1) and state.lits_current*100 / self.__lits_total_num >= self.__prop_heur:
            self.__solve(state) 
            if self.__trace:
                print ''
                print 'propagate with ', state.lits_current*100 / state.total_lits, '%', changes 
                for constr in state.clist:
                    print state.clist[constr]
                print ''
            if state.lp.is_valid() and not self.__check_consistency(control, state):
                end = time.clock()
                self.__proptime += end-start
                self.__propcalls += 1
                self.__time = self.__time + end-start
                return False
        end = time.clock()
        self.__proptime += end-start
        self.__propcalls += 1
        self.__time = self.__time + end-start
        return True



    def undo(self, thread_id, assign, changes):
        start = time.clock()
        state = self.__state(thread_id)
        lpid = state.stack[-1][1]
        cid = state.stack[-1][2]
        oid = state.stack[-1][3]
        nid = state.stack[-1][4]
        state.lits_current -= len(changes)
        for lit in state.lp_trail[lpid:]:
            var=abs(lit)
            for cnum in self.__var_ta[var]:
                state.active_cnum[cnum][1] = 0
        for lit in state.cond_trail[cid:]:
            var=abs(lit)
            for cnum in self.__clit_constr[var]:
                state.active_cnum[cnum][0] += 1
        for lit in state.oclit_trail[oid:]:
            state.active_oclit += 1 
            state.oclit_recent_active = 0
        for lit in state.eq_trail[nid:]:
            var=abs(lit)
            cnum = state.eqlit_inv[var]
            state.active_cnum[cnum][0] += 1
        del state.lp_trail[lpid:]
        del state.cond_trail[cid:]
        del state.oclit_trail[oid:]
        del state.eq_trail[nid:]
        state.lp.reset()
        state.stack.pop()
        end = time.clock()
        self.__undotime += end-start
        self.__undocalls += 1
        self.__time = self.__time + end-start



    def check(self, control):
        start = time.clock()
        state = self.__state(control.thread_id)
        state.lp.print_sol(self.__show, self.__accuracy)
        end = time.clock()
        self.__checktime += end-start
        self.__checkcalls += 1
        self.__time = self.__time + end-start
        times = state.lp.get_time()
        print ''
        if self.__debug > 0:
            print 'Calls init: ', self.__initcalls, '      Time init:  ', self.__inittime
            print 'Calls propagate: ', self.__propcalls, '      Time propagate:  ', self.__proptime
            print 'Calls undo: ', self.__undocalls, '      Time undo:  ', self.__undotime
            print 'Calls add: ', times[2], '      Time add:  ', times[3]
            print 'Calls reset: ', times[4], '      Time reset:  ', times[5]
            print 'Calls check: ', self.__checkcalls, '      Time check:  ', self.__checktime
        if self.__solver == 'lps':
            print 'LP solver calls: ', times[0], '   Time lp_solve :  ', times[1]
        elif self.__solver == 'cplx':
            print 'LP solver calls: ', times[0], '   Time cplex :  ', times[1]
        print 'Time propagator:  ', self.__time
        print ''
        return True



    # updates state wrt to changes
    def __update_state(self, control, changes):
        state = self.__state(control.thread_id)
        if len(state.stack) == 0 or state.stack[-1][0] < control.assignment.decision_level:
            state.stack.append((control.assignment.decision_level, len(state.lp_trail), len(state.cond_trail), len(state.oclit_trail), len(state.eq_trail)))
        state.recent_active = []
        state.lits_current += len(changes)
        for lit in changes:
            var=abs(lit)
            if lit in self.__lit_ta:
                state.lp_trail.append(lit)
                for cnum in self.__lit_ta[lit]:
                    state.active_cnum[cnum][1] = 1
                    rel = self.__constr[cnum][1][1]
                    if rel == '!=':
                        self.__add_aux(control, state, cnum, lit)
                    if state.active_cnum[cnum][0] == 0:
                        state.recent_active.append(cnum)
            if not self.__nstrict and -lit in self.__lit_ta:
                if lit not in state.lp_trail:
                    state.lp_trail.append(lit)
                for cnum in self.__lit_ta[-lit]:
                    state.active_cnum[cnum][1] = -1
                    rel = self.__constr[cnum][1][1]
                    if rel == '=':
                        self.__add_aux(control, state, cnum, lit)
                    if state.active_cnum[cnum][0] == 0:
                        state.recent_active.append(cnum)
            if var in self.__clit_constr:
                state.cond_trail.append(lit)
                for cnum in self.__clit_constr[var]:
                    state.active_cnum[cnum][0] -= 1
                    if state.active_cnum[cnum][0] == 0 and state.active_cnum[cnum][1] != 0:
                        state.recent_active.append(cnum)
            if var in state.eqlit_inv: 
                state.eq_trail.append(lit)
                cnum = state.eqlit_inv[var]
                state.active_cnum[cnum][0] -= 1
                if state.active_cnum[cnum][0] == 0 and state.active_cnum[cnum][1] != 0:
                    state.recent_active.append(cnum) 
            if var in self.__obj_cond_lit:
                state.oclit_trail.append(lit)
                state.active_oclit -= 1 
                if state.active_oclit == 0:
                    state.oclit_recent_active = 1


    # adds an literal l to choose on l or -l for disjunktion of '!='
    def __add_aux(self, control, state, cnum, lit):
        if state.active_cnum[cnum][2] == 0:
            state.active_cnum[cnum][2] = 1
            nlit = control.add_literal()
            control.add_watch(nlit)
            control.add_watch(-nlit)
            state.eqlit[cnum] = nlit
            state.eqlit_inv[nlit] = cnum
            state.active_cnum[cnum][0] += 1
            control.add_clause([lit, nlit])
            state.total_lits += 1


    # returns false if lp system inconsistent else true
    def __check_consistency(self, control, state):
        if not state.lp.is_sat() and state.lits_current*100 / state.total_lits >= self.__core_confl_heur: 
            active_cnums = [cnum for cnum in state.active_cnum if state.active_cnum[cnum][0] == 0 and state.active_cnum[cnum][1] != 0]
            core_confl = self.__core_confl(state, [], active_cnums)
            clause = self.__get_confl(state, core_confl)
            if self.__trace:
                print ''
                print 'core conflict constraints: '
                for confl_cnum in core_confl:
                    print state.clist[confl_cnum]
                print ''
            if not control.add_clause(clause) or not control.propagate():
                return False
            print 'If this was printed, then I did something really wrong!' 
        if not state.lp.is_sat():
            active_cnums = [cnum for cnum in state.active_cnum if state.active_cnum[cnum][0] == 0 and state.active_cnum[cnum][1] != 0]
            clause = self.__get_confl(state, active_cnums)
            if self.__trace:
                print ''
                print 'conflict constraints: '
                for confl_cnum in active_cnums:
                    print state.clist[confl_cnum]
                print ''
            if not control.add_clause(clause) or not control.propagate():
                return False
            print 'If this was printed, then I did something really wrong!'
        return True



    # search core conflict
    def __core_confl(self, state, confl_cnums, active_cnums): 
        constr_list = [] 
        state.lp.reset()
        if confl_cnums != []:
            for cnum in confl_cnums:
                constr_list.append(state.clist[cnum]) 
            state.lp.add_constr(constr_list) 
            state.lp.solve_lp()
            if not state.lp.is_sat():
                return confl_cnums
        for i, cnum in enumerate(active_cnums):
            constr = state.clist[cnum]
            constr_list.append(constr)
            state.lp.add_constr([constr])
            state.lp.solve_lp()
            if not state.lp.is_sat():
                confl_cnums.append(cnum)
                tmp = confl_cnums[:]
                confl_cnums = self.__core_confl(state, tmp, active_cnums[:i])
                break
        return confl_cnums



    # generates conflict clause from a conflict 
    def __get_confl(self, state, confl_cnums):
        clause=[]
        for cnum in confl_cnums:
            clause.append(-1*self.__constr[cnum][0]*state.active_cnum[cnum][1])
            if state.active_cnum[cnum][2] == 1:
                nlit = state.eqlit[cnum]
                if nlit in state.eq_trail:
                    clause.append(-nlit) 
                else:
                    clause.append(nlit)
            if cnum in self.__constr_clit:
                for clit in self.__constr_clit[cnum]:
                    if clit in state.cond_trail:
                        clause.append(-clit)
                    else:
                        clause.append(clit)
        clause = [x for x in clause if abs(x)>1]
        return clause



##### lpsolve wrapper
from lp_solve import *
class lps:


    def __init__(self, mapping, doms):
        self.__var_mapping = {}         # {varname : position}
        self.__doms = doms              # {varname : (lb,ub)}
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__stime = 0.0 
        self.__scalls = 0
        self.__addtime = 0.0
        self.__addcalls = 0
        self.__resettime = 0.0
        self.__resetcalls = 0
        self.set_mapping(mapping)
        nvar = len(self.__var_mapping)     
        self.__solver_obj = lpsolve('make_lp', 0, nvar)
        lpsolve('set_verbose', self.__solver_obj, IMPORTANT)
        self.set_doms()
        
    
    def set_mapping(self, mapping):
        self.__var_mapping = mapping

    
    def solve_lp(self):
        self.__scalls = self.__scalls +1 
        start = time.clock()
        lpsolve('solve', self.__solver_obj)
        self.__stime = self.__stime + time.clock() - start
        

    def reset(self):
        self.__resetcalls = self.__resetcalls +1 
        start = time.clock()
        n = len(self.__clist)
        if n>0:
            while n != 0:
                lpsolve('del_constraint', self.__solver_obj, 1)
                n -= 1
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__resettime = self.__resettime + time.clock() - start

    # expects clist = [({varname : weight}, rel, b)]
    def add_constr(self, clist): 
        self.__addcalls = self.__addcalls +1 
        start = time.clock()
        self.__clist.extend(clist)
        nvar = len(self.__var_mapping)
        for constr in clist:
            tmp = [0]*nvar
            for varname in constr[0]:
                tmp[self.__var_mapping[varname]-1] = constr[0][varname]
            lpsolve('add_constraint', self.__solver_obj, tmp, constr[1], constr[2])
        self.__addtime = self.__addtime + time.clock() - start


    # expects wopt = {varname : weights}; mode = max/min
    def set_obj(self, wopt, mode):
        self.__obj = dict(wopt)
        if mode == 'max':
            lpsolve('set_maxim', self.__solver_obj)
        else:
            lpsolve('set_minim', self.__solver_obj)
        tmp = [0]*len(self.__var_mapping)
        for varname in wopt:
            tmp[self.__var_mapping[varname]-1] = wopt[varname]
        lpsolve('set_obj_fn', self.__solver_obj, tmp)


    # expects doms = {varname : (lb,ub)}
    def set_doms(self):
        for varname in self.__doms:
            if varname in self.__var_mapping:
                lb = self.__doms[varname][0] 
                ub = self.__doms[varname][1]
                if lb != 'none':
                    lpsolve('set_lowbo', self.__solver_obj, self.__var_mapping[varname], lb)
                if ub != 'none':
                    lpsolve('set_upbo', self.__solver_obj, self.__var_mapping[varname], ub)


    def is_sat(self):
        status = lpsolve('get_status', self.__solver_obj)
        if status in [0,1,3]: 
            return True
        elif status == 2:
            return False


    def is_valid(self):
        if self.__clist == []:
            return False
        status = lpsolve('get_status', self.__solver_obj)
        if status in [0,1,2,3,4]:
            return True
        return False

    
    def get_time(self):
        return (self.__scalls, self.__stime, self.__addcalls, self.__addtime, self.__resetcalls, self.__resettime)


    def print_sol(self, show, accuracy): 
        if self.is_sat():
            sdict = {}
            slist = []
            res = lpsolve('get_variables', self.__solver_obj)[0]
            if isinstance(res, float):
                slist.append(res)
            else:
                slist.extend(res)
            obj = lpsolve('get_objective', self.__solver_obj)
            if accuracy > 0 and accuracy < 15:
                for var in self.__var_mapping:
                    sdict[var] = round(slist[self.__var_mapping[var]-1], accuracy)
            else:
                for var in self.__var_mapping:
                    sdict[var] = round(round(slist[self.__var_mapping[var]-1],1),0)
            slist = (obj, sdict)
            print ''
            print '-------------------------------'
            print 'LP Solver output'
            print ''
            if show:
                print 'constraints'
                for constr in self.__clist:
                    print constr
                print 'objective'
                print self.__obj
            print 'lp solution'
            print slist
        elif self.is_sat() == None:
            print ''
            print 'Unrecognized status'
        elif self.__clist == []:
            print ''
            print '-------------------------------'
            print 'EMPTY LP'
        else:
            print ''
            print '-------------------------------'
            print 'LP UNSATISFIABLE'
            print ''
            if show:
                print 'constraints'
                for constr in self.__clist:
                    print constr
                print 'objective'
                print self.__obj
    

##### cplex wrapper
import cplex 
import cplex.callbacks
class cplx:


    def __init__(self, mapping, doms):
        self.__var_mapping = {}         # {varname : position}
        self.__doms = doms              # {varname : (lb,ub)}
        self.__stime = 0.0 
        self.__scalls = 0
        self.__addtime = 0.0
        self.__addcalls = 0
        self.__resettime = 0.0
        self.__resetcalls = 0
        self.set_mapping(mapping)
        self.__solver_obj = cplex.Cplex()
        self.__solver_obj.variables.add(names = self.__var_mapping.keys())
        self.set_doms()
        self.__solver_obj.set_log_stream(None)
        self.__solver_obj.set_error_stream(None)
        self.__solver_obj.set_warning_stream(None)
        self.__solver_obj.set_results_stream(None)
        self.reset()
        
    
    def set_mapping(self, mapping):
        self.__var_mapping = mapping

    
    def solve_lp(self):
        #print '<<<<<', self.__clist ###!!!
        self.__scalls = self.__scalls +1 
        start = time.clock()
        self.__solver_obj.solve() 
        self.__stime = self.__stime + time.clock() - start
        

    def reset(self):
        self.__resetcalls = self.__resetcalls +1 
        start = time.clock()
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__solver_obj.linear_constraints.delete()
        self.__resettime = self.__resettime + time.clock() - start


    # expects clist = [({varname : weight}, rel, b)]
    def add_constr(self, clist): 
        self.__addcalls = self.__addcalls +1 
        start = time.clock()
        self.__clist.extend(clist)
        lin_expr = []
        rels = []
        rhs = []
        for constr in clist:
            items = constr[0].items()
            varnames = [x[0] for x in items] 
            values = [x[1] for x in items]
            lin_expr.append(cplex.SparsePair(ind = varnames, val = values))
            rel = constr[1]
            b = constr[2]
            if rel == '<=':
                rels.append("L")
            elif rel == '>=':
                rels.append("G")
            elif rel == '=':
                rels.append("E")
            rhs.append(b)
        self.__solver_obj.linear_constraints.add(lin_expr = lin_expr, senses = rels, rhs = rhs)
        self.__addtime = self.__addtime + time.clock() - start
        

    # expects wopt = {varname : weights}; mode = max/min
    def set_obj(self, wopt, mode):
        self.__obj = dict(wopt)
        if mode == 'max':
            self.__solver_obj.objective.set_sense(self.__solver_obj.objective.sense.maximize) 
        else:
            self.__solver_obj.objective.set_sense(self.__solver_obj.objective.sense.minimize) 
        self.__solver_obj.objective.set_linear(wopt.items())


    # expects doms = {varname : (lb,ub)}
    def set_doms(self):
        if self.__doms != {}:
            lbs = []
            ubs = []
            for i, x in enumerate(self.__var_mapping.keys()):
                if x in self.__doms:
                    if self.__doms[x][0] != 'none':
                        lbs.append((i,self.__doms[x][0]))
                    if self.__doms[x][1] != 'none':
                        ubs.append((i,self.__doms[x][1]))
            if lbs != []:
                self.__solver_obj.variables.set_lower_bounds(lbs)
            if ubs != []:
                self.__solver_obj.variables.set_upper_bounds(ubs)


    def is_sat(self):
        status = self.__solver_obj.solution.get_status()
        if status in [1,2,4,23]: 
            return True
        elif status == 3:
            return False


    def is_valid(self):
        status = self.__solver_obj.solution.get_status()
        if status in [1,2,3,4,23]:
            return True
        return False

    
    def get_time(self):
        return (self.__scalls, self.__stime, self.__addcalls, self.__addtime, self.__resetcalls, self.__resettime)


    def print_sol(self, show, accuracy): 
        if self.is_sat():
            sdict = {}
            slist = []
            res = self.__solver_obj.solution.get_values(self.__var_mapping.keys())
            if isinstance(res, float):
                slist.append(res)
            else:
                slist.extend(res)
            obj = self.__solver_obj.solution.get_objective_value()
            if accuracy > 0 and accuracy < 15:
                for i, var in enumerate(self.__var_mapping.keys()):
                    sdict[var] = round(slist[i], accuracy)
            else:
                for i, var in enumerate(self.__var_mapping.keys()):
                    sdict[var] = round(round(slist[i],1),0)
            slist = (obj, sdict)
            print ''
            print '-------------------------------'
            print 'LP Solver output'
            print ''
            if show:
                print 'constraints'
                for constr in self.__clist:
                    print constr
                print 'objective'
                print self.__obj
            print 'lp solution'
            print slist
        elif self.is_sat() == None:
            print ''
            print 'Unrecognized status'
        elif self.__clist == []:
            print ''
            print '-------------------------------'
            print 'EMPTY LP'
        else: 
            print ''
            print '-------------------------------'
            print 'LP UNSATISFIABLE'
            print ''
            if show:
                print 'constraints'
                for constr in self.__clist:
                    print constr
                print 'objective'
                print self.__obj
    





def main(prg):
    prop = Propagator(prg.get_const("show"), prg.get_const("accuracy"), prg.get_const("nstrict"), prg.get_const("epsilon"), prg.get_const("solver"), prg.get_const("trace"), prg.get_const("core_confl"), prg.get_const("prop_heur"), prg.get_const("debug"))
    prg.register_propagator(prop)
    prg.ground([("base", [])])
    prg.solve()

#end.
