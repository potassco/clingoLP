import sys

import clingo
from clingo import Flag
from clingolp import lp_theory


class Application:
    def __init__(self):
        self.program_name = 'clingoLP'
        self.version = "0.1.1"
        self.prop = None
        self.lp_assignment = None
        self.show_flag = Flag(False)
        self.lp_solver = "lps"
        self.accuracy = 1
        self.epsilon = 1*10**-3
        self.strict_flag = Flag(False)
        self.trace_flag = Flag(False)
        self.core_confl = 20
        self.prop_heur = 0
        self.ilp_flag = Flag(False)

    def __on_model(self, m):
        pass

    def register_options(self, options):
        group = "Clingo.LP Options"
        options.add(group, "lp-solver",
                    "Set LP solver\n"
                    "      <arg>: {lps,cplx} (default lp-solver=lps)",
                    self.parse_solver_option)

        options.add_flag(group, "show-lp-solution",
                         "Show LP solution and value of objective function",
                         self.show_flag)

        options.add(group, "accuracy",
                    "Set decimal position of LP solver accuracy (default accuracy=1)",
                    self.parse_accuracy,  argument="n")

        options.add(group, "epsilon",
                    "Set epsilon to convert lhs > k into lhs >= k+n*10^-m (default epsilon=1,3)",
                    self.parse_epsilon, argument="n,m")

        options.add_flag(group, "strict",
                         "Enables strict semantics",
                         self.strict_flag)

        options.add_flag(group, "trace",
                         "Enables detailed output of theory propagation",
                         self.trace_flag)

        options.add(group, "core-confl",
                    "Searches for core conflicts if at least n%% of the theory atoms are decided\n"
                    "                            (default core-confl=20)",
                    self.parse_core_confl,  argument="n")

        options.add(group, "prop-heur",
                    "Starts a solve call of the LP solver if at least n%% of the theory atoms are decided\n"
                    "                            (default prop-heur=0)",
                    self.parse_prop_heur, argument="n")
        options.add_flag(group, "ilp",
                         "Sets the LP solver to solve an Integer Linear Programming (ILP) problem",
                         self.ilp_flag)
        pass

    def parse_solver_option(self, string):
        if string == 'lps' or string == 'cplx':
            self.lp_solver = string
            return True
        else:
            return False

    def parse_accuracy(self, string):
        try:
            self.accuracy = int(string)
            return True
        except:
            return False

    def parse_core_confl(self, string):
        try:
            self.core_confl = int(string)
            return True
        except:
            return False

    def parse_prop_heur(self, string):
        try:
            self.prop_heur = int(string)
            return True
        except:
            return False

    def parse_epsilon(self, string):
        try:
            tmp = str(string).split(",")
            koef = float(tmp[0])
            exp = float(tmp[1])
            self.epsilon = koef*10**-exp
            return True
        except:
            return False

    def validate_options(self):
        return True

    def print_model(self, model, printer):

        for sym in model.symbols(shown=True):
            sys.stdout.write("{} ".format(sym))

        sys.stdout.write("\n")

        if self.show_flag.value:
            ass = self.prop.assignment(
                model.thread_id)
            if ass is None:
                sys.stdout.write("LP solution: None\n")
            else:
                sys.stdout.write("LP solution: ")
                (opt, values) = ass
                sys.stdout.write("optimum={}\n".format(opt))

                for name in values:
                    sys.stdout.write(
                        "{}={} ".format(name, values[name]))
                sys.stdout.write("\n")

            self.prop.print_solve_stats(model.thread_id)

        return True

    def __on_model(self, model):
        ass = self.prop.assignment(model.thread_id)
        if ass != None:
            (opt, values) = ass
            model.extend(
                [clingo.Function('_lp_optimum', [clingo.String(str(opt))])])

            for name in values:
                model.extend([clingo.Function('_lp_solution', [
                             clingo.Function(name, []), clingo.String(str(values[name]))])])

    def __on_statistics(self, step, accu):
        pass

    def main(self, ctrl, files):
        self.prop = lp_theory.Propagator(
            ctrl, solver=self.lp_solver,
            show=self.show_flag.value,
            accuracy=self.accuracy, epsilon=self.epsilon,
            nstrict=not self.strict_flag.value,
            trace=self.trace_flag.value,
            core_confl=self.core_confl,
            prop_heur=self.prop_heur,
            ilp=self.ilp_flag.value,
            debug=0)

        ctrl.register_propagator(self.prop)
        ctrl.add("base", [], lp_theory.theory)

        if not files:
            files.append("-")
        for f in files:
            ctrl.load(f)

        ctrl.ground([("base", [])])

        with ctrl.solve(on_model=self.__on_model, on_statistics=self.__on_statistics, yield_=True) as handle:
            for _model in handle:
                pass


def main_clingo(args=None):
    sys.exit(int(clingo.clingo_main(Application(), sys.argv[1:])))


sys.exit(int(clingo.clingo_main(Application(), sys.argv[1:])))
