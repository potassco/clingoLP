import time

# lpsolve wrapper
import lp_solve
from lp_solve import lpsolve


class lps:

    def __init__(self, mapping, doms, ilp):
        self.__var_mapping = {}         # {varname : position}
        self.__doms = doms              # {varname : [(lb,ub)]}
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__stime = 0.0
        self.__scalls = 0
        self.__addtime = 0.0
        self.__addcalls = 0
        self.__resettime = 0.0
        self.__resetcalls = 0
        self.__mode = ''
        self.set_mapping(mapping)
        nvar = len(self.__var_mapping)
        self.__solver_obj = lpsolve('make_lp', 0, nvar)
        lpsolve('set_verbose', self.__solver_obj, lp_solve.IMPORTANT)
        self.set_doms()
        if ilp:
            self.set_ilp()

    def set_mapping(self, mapping):
        self.__var_mapping = mapping

    def set_ilp(self):
        for i in range(len(self.__var_mapping)):
            lpsolve('set_int', self.__solver_obj, i+1, 1)

    def solve_lp(self):
        self.__scalls = self.__scalls + 1
        start = time.process_time()
        lpsolve('solve', self.__solver_obj)
        self.__stime = self.__stime + time.process_time() - start

    def reset(self):
        self.__resetcalls = self.__resetcalls + 1
        start = time.process_time()
        n = len(self.__clist)
        if n > 0:
            while n != 0:
                lpsolve('del_constraint', self.__solver_obj, 1)
                n -= 1
        self.__clist = []               # [({varname : weight}, rel, b)]
        self.__obj = {}                 # {varname : weight}
        self.__resettime = self.__resettime + time.process_time() - start

    def add_constr(self, clist):
        ''' expects clist = [({varname : weight}, rel, b)]
        '''
        self.__addcalls = self.__addcalls + 1
        start = time.process_time()
        self.__clist.extend(clist)
        nvar = len(self.__var_mapping)
        for constr in clist:
            tmp = [0]*nvar
            for varname in constr[0]:
                tmp[self.__var_mapping[varname]-1] = constr[0][varname]
            lpsolve('add_constraint', self.__solver_obj,
                    tmp, constr[1], constr[2])
        self.__addtime = self.__addtime + time.process_time() - start

    def set_obj(self, wopt, mode):
        ''' expects wopt = {varname : weights}; mode = max/min
        '''
        self.__obj = dict(wopt)
        self.__mode = mode
        if mode == 'max':
            lpsolve('set_maxim', self.__solver_obj)
        else:
            if mode != 'min':
                self.__mode = 'default min'
            lpsolve('set_minim', self.__solver_obj)
        tmp = [0]*len(self.__var_mapping)
        for varname in wopt:
            tmp[self.__var_mapping[varname]-1] = wopt[varname]
        lpsolve('set_obj_fn', self.__solver_obj, tmp)

    def set_doms(self):
        ''' expects doms = {varname : [(lb,ub)]}
        '''
        for varname in self.__doms:
            if varname in self.__var_mapping:
                for dom in self.__doms[varname]:
                    lb = dom[0]
                    ub = dom[1]
                    if lb != 'none':
                        lpsolve('set_lowbo', self.__solver_obj,
                                self.__var_mapping[varname], lb)
                    if ub != 'none':
                        lpsolve('set_upbo', self.__solver_obj,
                                self.__var_mapping[varname], ub)

    def is_sat(self):
        status = lpsolve('get_status', self.__solver_obj)
        if status in [0, 1, 3]:
            return True
        elif status == 2:
            return False

    def is_valid(self):
        if self.__clist == []:
            return False
        status = lpsolve('get_status', self.__solver_obj)
        if status in [0, 1, 2, 3, 4]:
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

    def get_stats(self):
        stats = ''
        stats = stats + 'constraints\n'
        for constr in self.__clist:
            stats = stats + str(constr) + '\n'
        stats = stats + 'objective ' + self.__mode + '\n'
        stats = stats + str(self.__obj)
        return stats

    def get_solution(self, accuracy):
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
                    sdict[var] = round(
                        slist[self.__var_mapping[var]-1], accuracy)
            else:
                for var in self.__var_mapping:
                    sdict[var] = round(
                        round(slist[self.__var_mapping[var]-1], 1), 0)
            slist = (obj, sdict)
        elif self.is_sat() is None:
            slist = 'Error'
        else:
            slist = 'Unsat'
        return slist
