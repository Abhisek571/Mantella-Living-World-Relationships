"""Compiles the M.A.R.A.S 2.x script into a built mod, after the Hub's tools/build.py --only relationships --no-pack.
It needs its own MARAS.psc on the import path, which the Hub's build cannot give one script alone.

usage: py -3 tools/compile_maras2x.py [scripts folder]   (default: the Hub's build/release stage of this mod)
"""
import os, shutil, sys

sys.dont_write_bytecode = True
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(ROOT), 'Mantella-Living-World-Hub', 'tools'))
import build as hub

SRC = os.path.join(ROOT, 'Source', 'Scripts2x')
NAME = 'MRB_MarasCalls2x'
out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(hub.OUT, hub.PROJECTS['relationships']['name'], 'Scripts')
imports = [SRC, os.path.join(ROOT, 'build', 'stubs', 'maras2x'), hub.VANILLA]
hub.run([hub.COMPILER, os.path.join(SRC, NAME + '.psc'), f'-f={hub.FLAGS}', '-i=' + ';'.join(imports), f'-o={out}', '-op'])
if os.path.isdir(os.path.join(out, 'Source')):
    shutil.copy2(os.path.join(SRC, NAME + '.psc'), os.path.join(out, 'Source'))
print(os.path.join(out, NAME + '.pex'))
