"""Offline tests for tools/check_papyrus.py: it passes on a copy of this repository and catches each planted mistake.

Each test copies the scripts, stubs, action files and the checker into a temporary folder with no other Living World
repository next to it, changes one thing and runs the checker there. A made-up MO2 folder stands in for M.A.R.A.S
0.11.1: it declares only the M.A.R.A.S natives the adapters care about, as 0.11.1 declares them.

usage: py -3 test/test_check_papyrus.py
"""
import json, os, shutil, subprocess, sys, tempfile, unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COPIED = ('Source', 'build', 'SKSE', 'tools', os.path.join('test', 'Scripts'))
MARAS = os.path.join('Source', 'Scripts', 'MRB_MARAS.psc')
LEDGER = os.path.join('Source', 'Scripts', 'MRB_Ledger.psc')
FAMILY = os.path.join('Source', 'Scripts', 'MRB_Family.psc')
ACTIONS = os.path.join('SKSE', 'Plugins', 'MantellaSoftware', 'data', 'actions')
MARAS011 = {
    'MARAS.psc': ['Scriptname MARAS Hidden',
                  'bool Function PromoteNPCToStatus(Actor npc, string statusType) global native',
                  'Function SetPermanentAffection(Actor npc, int amount) global native'],
    'TTM_ServiceAffection.psc': ['Scriptname TTM_ServiceAffection Hidden',
                                 'Function AddDialogueStartedAffection(Actor spouse) global', 'EndFunction'],
}


class CheckPapyrus(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = os.path.join(self.tmp.name, 'Mantella-Living-World-Relationships')
        for part in COPIED:
            shutil.copytree(os.path.join(REPO, part), os.path.join(self.root, part))
        self.mo2 = os.path.join(self.tmp.name, 'MO2')
        maras = os.path.join(self.mo2, 'mods', '[NoDelete] M.A.R.A.S - Marry Anyone Rule All Skyrim', 'Scripts', 'Source')
        os.makedirs(maras)
        for name, lines in MARAS011.items():
            with open(os.path.join(maras, name), 'w', encoding='utf-8') as f:
                f.writelines(line + '\n' for line in lines)

    def tearDown(self):
        self.tmp.cleanup()

    def run_check(self):
        env = dict(os.environ, MLW_MO2=self.mo2)
        result = subprocess.run([sys.executable, '-I', os.path.join(self.root, 'tools', 'check_papyrus.py'), '-v'],
                                capture_output=True, text=True, timeout=120, env=env)
        return result.returncode, result.stdout

    def edit(self, rel, old, new):
        path = os.path.join(self.root, rel)
        with open(path, encoding='utf-8', newline='') as f:
            text = f.read()
        self.assertIn(old, text, f'{rel} no longer has the text this test changes')
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write(text.replace(old, new, 1))

    def assert_error(self, message):
        code, out = self.run_check()
        self.assertEqual(code, 1, out)
        self.assertIn(message, out)

    def test_clean_copy_passes(self):
        code, out = self.run_check()
        self.assertEqual(code, 0, out)
        self.assertIn('RESULT: pass', out)
        self.assertIn('M.A.R.A.S 2.x-only: 2, changed: 2', out)

    def test_changed_native_outside_the_adapters(self):
        self.edit(LEDGER, 'Utility.Wait(1.0)', 'MARAS.SetPermanentAffection(None, 1)\n\t\tUtility.Wait(1.0)')
        self.assert_error('MARAS.SetPermanentAffection changed in M.A.R.A.S 2.x; call it through the adapters')

    def test_short_wait(self):
        self.edit(LEDGER, 'Utility.Wait(', 'Utility.Wait(0.05)\n\tUtility.Wait(')
        self.assert_error('waits 0.05 s; Papyrus waits under 0.1 s are not reliable')

    def test_missing_handler(self):
        self.edit(FAMILY, 'Event OnNpcAdded(', 'Event OnNpcAddedRenamed(')
        self.assert_error('handler OnNpcAdded for')

    def test_child_test_must_return(self):
        path = os.path.join(self.root, LEDGER)
        with open(path, encoding='utf-8', newline='') as f:
            lines = f.read().split('\n')
        minor = next(i for i, l in enumerate(lines) if 'If IsMinor(actors[i])' in l)
        for i in range(minor + 1, minor + 4):
            if lines[i].strip().startswith('Return'):
                lines[i] = lines[i].replace('Return', 'Debug.Trace("x")', 1)
        with open(path, 'w', encoding='utf-8', newline='') as f:
            f.write('\n'.join(lines))
        self.assert_error('the IsMinor(actors[i]) test does not return')

    def test_action_enum_must_hold_the_compared_words(self):
        path = os.path.join(self.root, ACTIONS, 'mantella_maras_resolve_crisis.json')
        with open(path, encoding='utf-8') as f:
            action = json.load(f)
        action['parameters']['decision']['enum'] = action['parameters']['decision']['enum'][:1]
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(action, f)
        self.assert_error('mantella_maras_resolve_crisis.decision: enum')

    def test_undeclared_parameter(self):
        path = os.path.join(self.root, ACTIONS, 'mantella_maras_affection.json')
        with open(path, encoding='utf-8') as f:
            action = json.load(f)
        action['parameters']['extra'] = {'type': 'string'}
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(action, f)
        self.assert_error('mantella_maras_affection: parameter extra is never read by')

    def test_identifier_must_match_file_name(self):
        src = os.path.join(self.root, ACTIONS, 'mantella_maras_divorce.json')
        os.rename(src, os.path.join(self.root, ACTIONS, 'mantella_maras_divorce_old.json'))
        self.assert_error('mantella_maras_divorce_old.json: identifier mantella_maras_divorce does not match the file name')

    def test_results_cap(self):
        self.edit(MARAS, 'If n < MAX_RESULTS', 'If n < 99999')
        self.assert_error('request_results.json is not trimmed to the newest MAX_RESULTS')


if __name__ == '__main__':
    unittest.main(verbosity=2)
