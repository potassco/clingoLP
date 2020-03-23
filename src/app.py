import sys
import clingo
from clingolp import lp_theory


class Application:
    def __init__(self):
        self.program_name = 'clingoLP'
        self.version = "1.0"
        self.prop = None
        self.lp_assignment = None

    def __on_model(self, m):
        pass

    def register_options(self, options):
        # self.__theory.register_options(options)
        pass

    def validate_options(self):
        # self.__theory.validate_options()
        return True

    def __on_statistics(self, step, accu):
        # self.__theory.on_statistics(step, accu)
        pass

    def main(self, ctrl, files):
        self.prop = lp_theory.Propagator(ctrl)

        # self.prop.register(ctrl)
        ctrl.register_propagator(self.prop)
        ctrl.add("base", [], lp_theory.theory)

        if not files:
            files.append("-")
        for f in files:
            ctrl.load(f)

        ctrl.ground([("base", [])])

        with ctrl.solve(on_model=self.__on_model, on_statistics=self.__on_statistics, yield_=True) as handle:
            for model in handle:
                sys.stdout.write("lp solution:")

                # for name, value in self.__theory.assignment(model.thread_id):
                (opt, values) = self.prop.assignment(
                    model.thread_id)
                sys.stdout.write(" optimum={}".format(opt))
                sys.stdout.write("\n")

                for name in values:
                    sys.stdout.write(" {}={}".format(name, values[name]))
                    sys.stdout.write("\n")


def main_clingo(args=None):
    sys.exit(int(clingo.clingo_main(Application(), sys.argv[1:])))

sys.exit(int(clingo.clingo_main(Application(), sys.argv[1:])))
