import subprocess
import json


def test_example():
    p = subprocess.run(['clingoLP', 'example_encoding.lp', 'example_instance.lp', '0',
                        '--outf=2', '--quiet=1,0,0'], capture_output=True)

    print(p.stdout)
    print(p.stderr)
    out = json.loads(p.stdout)

    assert (out['Call'][0]['Result'] == 'SATISFIABLE')


test_example()
