import time

# cplex wrapper
import cplex
import cplex.callbacks
import signal
signal.signal(signal.SIGINT, signal.SIG_DFL)


class cplx:

    def __init__(self, mapping, doms, ilp):
        self.__var_mapping = {}         # {varname : position}
        self.__doms = doms              # {varname : [(lb,ub)]}
        self.__stime = 0.0
        self.__scalls = 0
        self.__addtime = 0.0
        self.__addcalls = 0
        self.__resettime = 0.0
        self.__resetcalls = 0
        self.__mode = ''
        self.set_mapping(mapping)
        self.__solver_obj = cplex.Cplex()
        self.__solver_obj.variables.add(names=list(self.__var_mapping.keys()))
        self.set_doms()
        self.__solver_obj.set_log_stream(None)
        self.__solver_obj.set_error_stream(None)
        self.__solver_obj.set_warning_stream(None)
        self.__solver_obj.set_results_stream(None)
        self.reset()
        if ilp:
            self.set_ilp()

    def set_mapping(self, mapping):
        self.__var_mapping = mapping

    def set_ilp(self):
        for i in range(len(self.__var_mapping)):
            self.__solver_obj.variables.set_types(
                i, self.__solver_obj.variables.type.integer)

    def solve_lp(self):
        self.__scalls = self.__scalls + 1
        start = time.process_time()
        self.__solver_obj.solve()
        self.__stime = self.__stime + time.process_time() - start

    def reset(self):
        self.__resetcalls = self.__resetcalls + 1
        start = time.process_time()
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__solver_obj.linear_constraints.delete()
        self.__resettime = self.__resettime + time.process_time() - start

    # expects clist = [({varname : weight}, rel, b)]
    def add_constr(self, clist):
        self.__addcalls = self.__addcalls + 1
        start = time.process_time()
        self.__clist.extend(clist)
        lin_expr = []
        rels = []
        rhs = []
        for constr in clist:
            items = list(constr[0].items())
            varnames = [x[0] for x in items]
            values = [x[1] for x in items]
            lin_expr.append(cplex.SparsePair(ind=varnames, val=values))
            rel = constr[1]
            b = constr[2]
            if rel == '<=':
                rels.append("L")
            elif rel == '>=':
                rels.append("G")
            elif rel == '=':
                rels.append("E")
            rhs.append(b)
        self.__solver_obj.linear_constraints.add(
            lin_expr=lin_expr, senses=rels, rhs=rhs)
        self.__addtime = self.__addtime + time.process_time() - start

    def set_obj(self, wopt, mode):
        ''' expects wopt = {varname : weights}; mode = max/min
        '''
        self.__obj = dict(wopt)
        self.__mode = mode
        if mode == 'max':
            self.__solver_obj.objective.set_sense(
                self.__solver_obj.objective.sense.maximize)
        else:
            if mode != 'min':
                self.__mode = 'default min'
            self.__solver_obj.objective.set_sense(
                self.__solver_obj.objective.sense.minimize)
        self.__solver_obj.objective.set_linear(list(wopt.items()))

    def set_doms(self):
        ''' expects doms = {varname : [(lb,ub)]}
        '''
        if self.__doms != {}:
            lbs = []
            ubs = []
            for i, x in enumerate(self.__var_mapping.keys()):
                if x in self.__doms:
                    for dom in self.__doms[x]:
                        if dom[0] != 'none':
                            lbs.append((i, dom[0]))
                        if dom[1] != 'none':
                            ubs.append((i, dom[1]))
            if lbs != []:
                self.__solver_obj.variables.set_lower_bounds(lbs)
            if ubs != []:
                self.__solver_obj.variables.set_upper_bounds(ubs)

    def is_sat(self):  # 102 - int with tolerance could be moved up if set tolerance was accessed!
        status = self.__solver_obj.solution.get_status()
        if status in [1, 2, 4, 23, 101, 115, 118]:
            return True
        elif status in [3, 102, 103]:
            return False

    def is_valid(self):
        status = self.__solver_obj.solution.get_status()
        if status in [1, 2, 3, 4, 23, 101, 102, 103, 115, 118]:
            return True
        return False

    def get_time(self):
        if self.is_sat():
            time_return = (self.__scalls, self.__stime, self.__addcalls,
                           self.__addtime, self.__resetcalls, self.__resettime)
        elif self.is_sat() is None:
            time_return = 'Error'
        else:
            time_return = 'Unsat'
        return time_return

    def get_solution(self, accuracy):
        if self.is_sat():
            sdict = {}
            slist = []
            res = self.__solver_obj.solution.get_values(
                list(self.__var_mapping.keys()))
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
                    sdict[var] = round(round(slist[i], 1), 0)
            slist = (obj, sdict)
        elif self.is_sat() is None:
            slist = 'Error'
        else:
            slist = 'Unsat'
        return slist

    def get_stats(self):
        stats = ''
        stats = stats + 'constraints\n'
        for constr in self.__clist:
            stats = stats + str(constr) + '\n'
        stats = stats + 'objective ' + self.__mode + '\n'
        stats = stats + str(self.__obj)
        return stats
