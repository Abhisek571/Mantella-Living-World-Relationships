"""Static checks for this repository's Papyrus scripts and Mantella action files.

usage: py -3 tools/check_papyrus.py [-v]

  1. every RegisterForModEvent names a handler that exists, as an Event, with the argument types the sender pushes
     (senders read from this repo, the other Living World repos, Mantella, M.A.R.A.S and Lover's Ledger sources)
  2. every StorageUtil and JsonUtil key is read with the type it is written with, no two keys differ only by a
     near-miss spelling, and no key is only read or only written across all Living World sources
  3. no Completed()/Mantella_ActionResponseCompleted for an action with requires_response false, and one for every
     action with requires_response true
  4. M.A.R.A.S 2.x natives that 0.11.1 lacks or declares differently are called only from MRB_MarasCalls2x (changed
     ones also from MRB_MarasCalls011)
  5. every action JSON parameter is read by its advanced handler, and the handler reads no undeclared parameter
  6-10. results cap, close-family words, action enums, short waits, no after-scene line for a scene with a child

Exit 1 on any error. Warnings are printed but do not fail.
"""
import glob, json, os, re, sys

sys.dont_write_bytecode = True
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CODING = os.path.dirname(ROOT)
OWN = [os.path.join(ROOT, 'Source', 'Scripts'), os.path.join(ROOT, 'Source', 'Scripts2x'), os.path.join(ROOT, 'test', 'Scripts')]
ACTIONS = os.path.join(ROOT, 'SKSE', 'Plugins', 'MantellaSoftware', 'data', 'actions')


def mo2_mods():
    f = os.path.join(CODING, 'Mantella-Living-World-Hub', 'tools', 'local-paths.json')
    mo2 = os.environ.get('MLW_MO2') or (json.loads(read_text(f)).get('mo2', '') if os.path.isfile(f) else '')
    return os.path.join(mo2, 'mods') if mo2 else ''


def read_text(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


MODS = mo2_mods()
MARAS011 = os.path.join(MODS, '[NoDelete] M.A.R.A.S - Marry Anyone Rule All Skyrim', 'Scripts', 'Source')
EXTERNAL = [os.path.join(MODS, '[NoDelete] Mantella - Bring NPCs to Life with AI', 'Scripts', 'Source'), MARAS011,
            os.path.join(MODS, "Lover's Ledger", 'scripts', 'source')]
SIBLINGS = [d for d in glob.glob(os.path.join(CODING, 'Mantella-Living-World-*', 'Source', 'Scripts'))
            if not d.startswith(ROOT)]
# Mantella builds the action event names at run time (MantellaConversation.psc RaiseActionEvent).
PREFIX_SIGS = {'MantellaConversation_Advanced_Action_': ['form', 'form', 'int'], 'MantellaConversation_Action_': ['form']}

errors, warnings = [], []


def err(msg):
    errors.append(msg)


def warn(msg):
    warnings.append(msg)


# ---- parsing --------------------------------------------------------------------------------------------------------

def strip_comment(line):
    out, q = [], False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ';' and not q:
            break
        out.append(ch)
    return ''.join(out)


class Script:
    def __init__(self, path):
        self.path = path
        self.name = os.path.splitext(os.path.basename(path))[0]
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        text = re.sub(r'\{[^}]*\}', lambda m: '\n' * m.group(0).count('\n'), text)  # doc comments
        text = re.sub(r';/.*?/;', lambda m: '\n' * m.group(0).count('\n'), text, flags=re.S)  # block comments
        raw = text.split('\n')
        self.lines = []  # (line number, joined logical line)
        buf, start = '', 0
        for i, l in enumerate(raw, 1):
            l = strip_comment(l).rstrip()
            if not buf:
                start = i
            if l.endswith('\\'):
                buf += l[:-1] + ' '
                continue
            self.lines.append((start, buf + l))
            buf = ''
        self.props = {}
        for _, l in self.lines:
            m = re.match(r'\s*string\s+Property\s+(\w+)\s*=\s*"([^"]*)"', l, re.I)
            if m:
                self.props[m.group(1).lower()] = m.group(2)
        self.funcs = {}  # name lower -> dict(kind, params, body lines)
        cur = None
        for n, l in self.lines:
            m = re.match(r'\s*(?:(\w+(?:\[\])?)\s+)?(Function|Event)\s+(\w+)\s*\((.*)\)', l, re.I)
            if m and not re.match(r'\s*End(Function|Event)', l, re.I):
                params = [p.strip() for p in m.group(4).split(',') if p.strip()]
                types = [p.split()[0].lower() for p in params]
                names = [p.split()[1] if len(p.split()) > 1 else '' for p in params]
                cur = dict(kind=m.group(2).lower(), name=m.group(3), types=types, names=names, line=n, body=[],
                           native='native' in l.lower().split(')')[-1])
                self.funcs[m.group(3).lower()] = cur
                if cur['native'] or re.search(r'\)\s*global\s+native', l, re.I):
                    cur = None
                continue
            if re.match(r'\s*End(Function|Event)\b', l, re.I):
                cur = None
                continue
            if cur is not None:
                cur['body'].append((n, l))

    def resolve(self, expr):
        """A string expression as text, with '*' for parts that are not literals or string properties."""
        parts = split_plus(expr.strip())
        out = ''
        for p in parts:
            p = p.strip()
            m = re.fullmatch(r'"([^"]*)"', p)
            if m:
                out += m.group(1)
            elif p.lower() in self.props:
                out += self.props[p.lower()]
            elif re.fullmatch(r'\w+\.(\w+)', p) and re.fullmatch(r'\w+\.(\w+)', p).group(1).lower() in GLOBAL_PROPS:
                out += GLOBAL_PROPS[re.fullmatch(r'\w+\.(\w+)', p).group(1).lower()]  # another script's property
            else:
                out += '*'
        return out


def split_plus(s):
    parts, depth, q, cur = [], 0, False, ''
    for ch in s:
        if ch == '"':
            q = not q
        if not q:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
            elif ch == '+' and depth == 0:
                parts.append(cur)
                cur = ''
                continue
        cur += ch
    parts.append(cur)
    return parts


def args_of(text, start):
    """Arguments of the call whose '(' is at text[start]."""
    depth, q, cur, out = 0, False, '', []
    for ch in text[start:]:
        if ch == '"':
            q = not q
        if not q:
            if ch == '(':
                depth += 1
                if depth == 1:
                    continue
            elif ch == ')':
                depth -= 1
                if depth == 0:
                    out.append(cur.strip())
                    return out
            elif ch == ',' and depth == 1:
                out.append(cur.strip())
                cur = ''
                continue
        cur += ch
    return out


def load(dirs):
    out = []
    for d in dirs:
        if d and os.path.isdir(d):
            out += [Script(os.path.join(d, f)) for f in sorted(os.listdir(d)) if f.lower().endswith('.psc')]  # no glob: '[NoDelete]'
    return out


# String properties of any loaded script, by name, when every script that declares one gives it the same value.
GLOBAL_PROPS = {}


def fill_global_props(scripts):
    seen = {}
    for s in scripts:
        for k, v in s.props.items():
            seen.setdefault(k, set()).add(v)
    GLOBAL_PROPS.update({k: next(iter(v)) for k, v in seen.items() if len(v) == 1})  # only names with one value


# ---- 1. mod event handlers ------------------------------------------------------------------------------------------

PUSH = {'pushform': 'form', 'pushstring': 'string', 'pushint': 'int', 'pushfloat': 'float', 'pushbool': 'bool'}


def find_senders(scripts, external):
    """event name -> list of (pushed types, where), from every ModEvent.Create ... Send, plus the events a native
    plugin sends (the signature of the sending mod's own handler for it)."""
    senders = {}
    for s in scripts:
        for f in s.funcs.values():
            body = f['body']
            for i, (n, l) in enumerate(body):
                m = re.search(r'ModEvent\.Create\(', l, re.I)
                if not m:
                    continue
                name = s.resolve(args_of(l, m.end() - 1)[0])
                if len(name.replace('*', '')) < 3:
                    continue  # built from variables (Mantella's action names): PREFIX_SIGS covers those
                types = []
                for _, l2 in body[i + 1:]:
                    p = re.search(r'ModEvent\.(Push\w+)\(', l2, re.I)
                    if p:
                        types.append(PUSH.get(p.group(1).lower(), p.group(1).lower()))
                    if re.search(r'ModEvent\.Send\(', l2, re.I):
                        break
                senders.setdefault(name, []).append((types, f'{s.name}:{n}'))
    for s in external:
        for f in s.funcs.values():
            for n, l in f['body']:
                m = re.search(r'RegisterForModEvent\(\s*("[^"]*")\s*,\s*"(\w+)"', l, re.I)
                if m and s.resolve(m.group(1)) not in senders and m.group(2).lower() in s.funcs:
                    senders.setdefault(s.resolve(m.group(1)), []).append(
                        (s.funcs[m.group(2).lower()]['types'], f'{s.name} handler {m.group(2)} (native sender)'))
    return senders


def sig_for(senders, event):
    if event in senders:
        return senders[event]
    for pre, sig in PREFIX_SIGS.items():
        if event.startswith(pre):
            return [(sig, 'Mantella RaiseActionEvent')]
    # a sender that builds the name from a prefix
    for name, v in senders.items():
        if '*' in name and re.fullmatch(re.escape(name).replace(r'\*', '.*'), event):
            return v
    return None


def check_mod_events(own, senders):
    """Check 1. Returns (script, handler lower) -> [event] for every RegisterForModEvent in own scripts."""
    registered = {}
    for s in own:
        for f in s.funcs.values():
            for n, l in f['body']:
                m = re.search(r'(?<!Un)RegisterForModEvent\(', l, re.I)
                if not m:
                    continue
                a = args_of(l, m.end() - 1)
                event, handler = s.resolve(a[0]), s.resolve(a[1])
                registered.setdefault((s.name, handler.lower()), []).append(event)
                h = s.funcs.get(handler.lower())
                where = f'{s.name}.psc:{n}'
                if not h:
                    err(f'{where}: handler {handler} for {event} does not exist')
                    continue
                if h['kind'] != 'event':
                    err(f'{where}: handler {handler} is a Function, mod events call Events only')
                sigs = sig_for(senders, event)
                if sigs is None:
                    warn(f'{where}: no sender found for {event}; handler {handler}({", ".join(h["types"])}) not checked')
                    continue
                for types, src in sigs:
                    if types != h['types']:
                        err(f'{where}: {handler}({", ".join(h["types"])}) but {src} sends {event} with ({", ".join(types)})')
    return registered


# ---- 2. StorageUtil / JsonUtil keys ---------------------------------------------------------------------------------

KEYCALL = re.compile(r'\b(StorageUtil|JsonUtil)\.(\w+?)\(', re.I)


def key_use(s, l):
    for m in KEYCALL.finditer(l):
        lib, fn = m.group(1), m.group(2)
        a = args_of(l, m.end() - 1)
        if len(a) < 2:
            continue
        low = fn.lower()
        t = re.search(r'(int|float|string|form)(value|list)', low)
        if not t:
            continue  # Save, Load, FileExists and the like
        typ = t.group(1) + ('list' if t.group(2) == 'list' else '')
        if re.match(r'(get|has|count|find|pluck)', low) or low.endswith(('get', 'count', 'find', 'toarray')):
            op = 'read'
        elif re.match(r'(unset|clear|remove)', low) or 'remove' in low or 'clear' in low:
            op = 'unset'
        else:
            op = 'write'
        yield lib.lower(), s.resolve(a[1]), typ, op


def collect_keys(own, others):
    """(lib, key lower) -> dict(spellings, types per op, used in own scripts, where)."""
    keys = {}
    for s in own + others:
        mine = s in own
        for n, l in s.lines:
            for lib, key, typ, op in key_use(s, l):
                k = keys.setdefault((lib, key.lower()), dict(spell=set(), ops={}, own=False, where=[]))
                k['spell'].add(key)
                k['ops'].setdefault(op, set()).add(typ)
                k['own'] |= mine
                k['where'].append(f'{s.name}:{n}')
    return keys


def close(a, b):
    if a == b or '*' in a or '*' in b or abs(len(a) - len(b)) > 2:
        return False
    # edit distance <= 2
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1] <= 2


# distinct keys that only look like a typo: wares is the World module's trade key, maras this module's gate
NEAR_MISS_OK = {frozenset(('maras', 'wares'))}


def check_keys(keys):
    """Check 2. Returns the keys this repository's own scripts use."""
    ownkeys = [(lib, k) for (lib, k), v in keys.items() if v['own']]
    for lib, k in ownkeys:
        v = keys[(lib, k)]
        reads, writes = v['ops'].get('read', set()), v['ops'].get('write', set())
        # Has/Unset calls name a type too, and StorageUtil keeps each type apart
        for op in ('read', 'unset'):
            for t in v['ops'].get(op, set()):
                if writes and t not in writes and not (t.endswith('list') and any(w.endswith('list') for w in writes)):
                    err(f'{lib} key {sorted(v["spell"])[0]}: {op} as {t} but written as {"/".join(sorted(writes))} ({", ".join(v["where"][:4])})')
        if '*' in k:
            continue
        if reads and not writes:
            warn(f'{lib} key {sorted(v["spell"])[0]} is read but never written in Living World sources (set by another mod?)')
        if writes and not reads:
            warn(f'{lib} key {sorted(v["spell"])[0]} is written but never read in Living World sources (the Hub reads JSON files as data)')
        for lib2, k2 in keys:
            if lib2 == lib and k2 > k and close(k, k2) and frozenset((k, k2)) not in NEAR_MISS_OK and (bool(reads) != bool(keys[(lib2, k2)]['ops'].get('read'))
                                                            or bool(writes) != bool(keys[(lib2, k2)]['ops'].get('write'))):
                err(f'{lib} keys {k} and {k2} differ by a letter or two and one is only read or only written')
    return ownkeys


# ---- 3. Completed vs requires_response -------------------------------------------------------------------------------

def load_actions(folder):
    """identifier -> the action file's JSON, for every action file in folder."""
    actions = {}
    for p in sorted(glob.glob(os.path.join(folder, '*.json'))):
        try:
            with open(p, encoding='utf-8') as f:
                a = json.load(f)
        except ValueError as e:
            err(f'{os.path.basename(p)}: not valid JSON: {e}')
            continue
        actions[a['identifier']] = a
        if a.get('identifier') + '.json' != os.path.basename(p):
            err(f'{os.path.basename(p)}: identifier {a.get("identifier")} does not match the file name')
    return actions


def calls_completed(s, fname, ident, seen=None):
    """Does this function, or a function of this script it calls, send the completed event for ident?"""
    seen = seen or set()
    if fname in seen or fname not in s.funcs:
        return False
    seen.add(fname)
    for n, l in s.funcs[fname]['body']:
        m = re.search(r'\bCompleted\(', l)
        if m and s.resolve(args_of(l, m.end() - 1)[0]) == ident:
            return True
        if re.search(r'Mantella_ActionResponseCompleted|MarkActionResponseCompleted', l):
            idx = s.funcs[fname]['body'].index((n, l))
            for _, l2 in s.funcs[fname]['body'][idx:idx + 4]:
                p = re.search(r'PushString\(\s*\w+\s*,\s*(.+)\)\s*$', l2)
                if p and s.resolve(p.group(1)) == ident:
                    return True
        for c in re.finditer(r'(?<![\w.])(\w+)\(', l):
            if c.group(1).lower() != fname and calls_completed(s, c.group(1).lower(), ident, seen):
                return True
    return False


def action_handlers(registered):
    """action id -> [(script, handler, advanced)] from the registered Mantella action events."""
    handlers = {}
    for (sname, h), events in registered.items():
        for e in events:
            for pre in PREFIX_SIGS:
                if e.startswith(pre):
                    handlers.setdefault(e[len(pre):], []).append((sname, h, pre.startswith('MantellaConversation_Adv')))
    return handlers


def check_completed(actions, handlers, byname):
    for ident, a in actions.items():
        hs = handlers.get(ident, [])
        if not hs:
            err(f'{ident}: no handler registered')
            continue
        for sname, h, adv in hs:
            s = byname[sname]
            done = calls_completed(s, h, ident)
            if not a.get('requires_response') and done:
                err(f'{ident}: requires_response is false but {sname}.{h} sends Completed (a stray one ends the next action\'s wait)')
            if a.get('requires_response') and not done:
                err(f'{ident}: requires_response is true but {sname}.{h} never sends Completed (Mantella waits 5 s)')
        if a.get('parameters') and not any(adv for _, _, adv in hs):
            err(f'{ident}: has parameters but no advanced handler')
    for ident in handlers:
        if ident not in actions:
            warn(f'handler registered for action {ident}, which has no action file in this repo')


# ---- 4. M.A.R.A.S 2.x-only natives -----------------------------------------------------------------------------------

def check_maras_versions(own):
    """Check 4. Returns (2.x-only functions, functions whose argument count changed) as (script, function) pairs."""
    old = {}
    for s in load([MARAS011]):
        for f in s.funcs.values():
            old[(s.name.lower(), f['name'].lower())] = len(f['types'])
    new = load([os.path.join(ROOT, 'build', 'stubs', 'maras2x')])
    only2x, changed = set(), set()
    for s in new:
        for f in s.funcs.values():
            k = (s.name.lower(), f['name'].lower())
            if k not in old:
                only2x.add(k)
            elif old[k] != len(f['types']):
                changed.add(k)
    if not old:
        warn('M.A.R.A.S 0.11.1 sources not found: 2.x-only list is every function in build/stubs/maras2x')
        only2x = {(s.name.lower(), f['name'].lower()) for s in new for f in s.funcs.values()}
    for s in own:
        if s.path.startswith(os.path.join(ROOT, 'test')):
            continue
        for n, l in s.lines:
            for m in re.finditer(r'\b(\w+)\.(\w+)\(', l):
                k = (m.group(1).lower(), m.group(2).lower())
                if k in only2x and s.name != 'MRB_MarasCalls2x':
                    err(f'{s.name}.psc:{n}: {m.group(1)}.{m.group(2)} exists only in M.A.R.A.S 2.x; call it through MRB_MarasCalls2x')
                if k in changed and s.name not in ('MRB_MarasCalls2x', 'MRB_MarasCalls011'):
                    err(f'{s.name}.psc:{n}: {m.group(1)}.{m.group(2)} changed in M.A.R.A.S 2.x; call it through the adapters')
                if k in changed and s.name == 'MRB_MarasCalls011' and len(args_of(l, m.end() - 1)) != old[k]:
                    err(f'{s.name}.psc:{n}: {m.group(1)}.{m.group(2)} needs {old[k]} arguments on 0.11.1')
    check_adapter_stub()
    return only2x, changed


def check_adapter_stub():
    """The main build compiles against the stub: it must declare every function the real 2.x adapter has."""
    real = {f['name'].lower(): f['types'] for s in load([os.path.join(ROOT, 'Source', 'Scripts2x')]) for f in s.funcs.values()}
    stub = {f['name'].lower(): f['types'] for s in load([os.path.join(ROOT, 'build', 'stubs')]) if s.name == 'MRB_MarasCalls2x'
            for f in s.funcs.values()}
    for name, types in real.items():
        if stub.get(name) != types:
            err(f'build/stubs/MRB_MarasCalls2x.psc: {name} missing or declared differently from Source/Scripts2x')
    for name in stub:
        if name not in real:
            err(f'build/stubs/MRB_MarasCalls2x.psc: {name} is not in Source/Scripts2x (the main build would call nothing)')


# ---- 5. action parameters ---------------------------------------------------------------------------------------------

def check_action_parameters(actions, handlers, byname):
    for ident, a in actions.items():
        params = set((a.get('parameters') or {}).keys())
        for r in a.get('required', []):
            if r not in params:
                err(f'{ident}: required {r} is not a parameter')
        for sname, h, adv in handlers.get(ident, []):
            if not adv or h not in byname[sname].funcs:
                continue  # a missing handler is reported in check 1
            f = byname[sname].funcs[h]
            argname = f['names'][-1] if f['types'] and f['types'][-1] == 'int' else 'aiArguments'
            read = set()
            for n, l in f['body']:
                for c in re.finditer(r'SKSE_HTTP\.get\w+\(\s*' + argname + r'\s*,\s*"([^"]+)"', l):
                    read.add(c.group(1))
            for p in params - read:
                err(f'{ident}: parameter {p} is never read by {sname}.{h}')
            for p in read - params:
                err(f'{ident}: {sname}.{h} reads {p}, which the action file does not declare')


# ---- 6. request_results.json stays bounded ---------------------------------------------------------------------------
# request_results.json was only ever appended to, and RequestDone reads it whole once per request row. RecordResult keeps
# the newest MAX_RESULTS (the Hub keeps its newest 50 requests, so every request it still lists keeps its result).

def check_results_cap():
    maras_src = read_text(os.path.join(ROOT, 'Source', 'Scripts', 'MRB_MARAS.psc'))
    record = re.search(r'^Function RecordResult\(.*?^EndFunction', maras_src, re.M | re.S)
    record = record.group(0) if record else ''
    cap = re.search(r'int Property MAX_RESULTS = (\d+) AutoReadOnly', maras_src)
    hub_contracts = os.path.join(CODING, 'Mantella-Living-World-Hub', 'server', 'living_world', 'contracts.py')
    hub_cap = re.search(r'^MAX_REQUESTS = (\d+)', read_text(hub_contracts), re.M) if os.path.isfile(hub_contracts) else None
    if not cap or not record:
        err('MRB_MARAS.psc: MAX_RESULTS or RecordResult not found')
        return
    if 'If n < MAX_RESULTS' not in record or 'int i = n - MAX_RESULTS + 1' not in record \
            or 'JsonUtil.SetRawPathValue(RESULTS_FILE, ".results", kept + row + "]")' not in record:
        err('MRB_MARAS.RecordResult: request_results.json is not trimmed to the newest MAX_RESULTS')
    mark = re.search(r'^Function MarkRequestDone\(.*?^EndFunction', maras_src, re.M | re.S)
    if '> MAX_RESULTS' not in record and not ('MarkRequestDone(asId)' in record and mark and '> MAX_RESULTS' in mark.group(0)):
        err('MRB_MARAS.RecordResult: the handled-request list is not capped at MAX_RESULTS')
    if hub_cap and int(hub_cap.group(1)) > int(cap.group(1)):
        err(f"MRB_MARAS.MAX_RESULTS {cap.group(1)} is below the Hub's MAX_REQUESTS {hub_cap.group(1)}: a listed request could lose its result")


# ---- 7. every word a family tie is named by is known to IsCloseKind -------------------------------------------------
# SpouseWord names the spouse "husband" or "wife", but IsCloseKind only knew "spouse": a widow was never told she grieves.

def check_family_words(own):
    family = next((s for s in own if s.name == 'MRB_Family'), None)
    if not (family and 'spouseword' in family.funcs and 'isclosekind' in family.funcs):
        err('MRB_Family.psc: SpouseWord or IsCloseKind not found')
        return
    close_words = {w for _, l in family.funcs['isclosekind']['body'] for w in re.findall(r'asKind\s*==\s*"([^"]+)"', l)}
    for n, l in family.funcs['spouseword']['body']:
        for word in re.findall(r'Return\s+"([^"]+)"', l):
            if word not in close_words:
                err(f'MRB_Family.psc:{n}: SpouseWord returns "{word}", which IsCloseKind does not treat as close family')


# ---- 8. words a handler acts on only by exact match come from the action file's enum ---------------------------------
# ChangeAffection and ResolveMarriageCrisis took free text: "slightly warmer" or "reconciled" silently did nothing.

# (action, parameter, MRB_MARAS function lower, the variable it compares)
EXACT_WORD_PARAMS = (('mantella_maras_affection', 'change', 'changeaffection', 'asChange'),
                     ('mantella_maras_affection', 'amount', 'changeaffection', 'asAmount'),
                     ('mantella_maras_resolve_crisis', 'decision', 'resolvecrisis', 'decision'))


def check_action_enums(own, actions):
    maras = next((s for s in own if s.name == 'MRB_MARAS'), None)
    for ident, param, fname, var in EXACT_WORD_PARAMS:
        spec = ((actions.get(ident) or {}).get('parameters') or {}).get(param) or {}
        words = {w for _, l in (maras.funcs.get(fname, {}).get('body', []) if maras else [])
                 for w in re.findall(var + r'\s*[!=]=\s*"([^"]+)"', l)}
        if not words:
            err(f'{ident}.{param}: MRB_MARAS.{fname} compares no words (check needs updating)')
        elif not isinstance(spec.get('enum'), list):
            err(f'{ident}.{param}: no enum, but MRB_MARAS acts only on {sorted(words)}')
        elif not words <= set(spec['enum']):
            err(f'{ident}.{param}: enum {spec["enum"]} lacks {sorted(words - set(spec["enum"]))}, which MRB_MARAS acts on')


# ---- 9. no lock or retry loop waits under 0.1 s (a shorter wait is one frame at best, and 40 tries end far too soon) ---

def check_short_waits(own):
    for s in own:
        for n, l in s.lines:
            m = re.search(r'Utility\.Wait(?:MenuMode)?\(\s*(\d*\.?\d+)\s*\)', l)
            if m and float(m.group(1)) < 0.1:
                err(f'{s.name}.psc:{n}: waits {m.group(1)} s; Papyrus waits under 0.1 s are not reliable')


# ---- 10. a scene thread with a child gets no after-scene line or talk ------------------------------------------------
# OnLedgerThreadData built "just finished having sex" for every partner: it must return on a child before the scene
# counts (sceneToken), the running-talk line or StartTalk.

def check_child_scene_line(own):
    ledger = next((s for s in own if s.name == 'MRB_Ledger'), None)
    body = ledger.funcs.get('onledgerthreaddata', {}).get('body', []) if ledger else []
    minor = next((i for i, (_, l) in enumerate(body) if re.search(r'\bIf\s+IsMinor\(actors\[i\]\)', l)), None)
    after = [i for i, (_, l) in enumerate(body) if re.search(r'sceneToken\s*\+=|AddMantellaEvent\(|StartTalk\(', l)]
    if minor is None:
        err('MRB_Ledger.OnLedgerThreadData: no IsMinor(actors[i]) test on the scene\'s actors')
    elif not any(re.match(r'\s*Return\b', l) for _, l in body[minor + 1:minor + 4]):
        err('MRB_Ledger.OnLedgerThreadData: the IsMinor(actors[i]) test does not return')
    elif not after or min(after) < minor:
        err('MRB_Ledger.OnLedgerThreadData: the child test must come before sceneToken, AddMantellaEvent and StartTalk')


# ---------------------------------------------------------------------------------------------------------------------

def report(summary, verbose):
    """Prints the summary lines, the warnings (or their count) and the errors, then the result."""
    for line in summary:
        print(line)
    for w in warnings if verbose else []:
        print('  warn:', w)
    if not verbose and warnings:
        print(f'  {len(warnings)} warnings (-v to list)')
    for e in errors:
        print('  ERROR:', e)
    print('RESULT:', 'pass' if not errors else f'{len(errors)} errors')


def main():
    own, others, external = load(OWN), load(SIBLINGS), load(EXTERNAL)
    fill_global_props(own + others + external)
    if not external:
        warn('Mantella / M.A.R.A.S / Lover\'s Ledger sources not found: sender and 0.11.1 checks are partial')
    registered = check_mod_events(own, find_senders(own + others + external, external))
    ownkeys = check_keys(collect_keys(own, others))
    actions = load_actions(ACTIONS)
    handlers = action_handlers(registered)
    byname = {s.name: s for s in own}
    check_completed(actions, handlers, byname)
    only2x, changed = check_maras_versions(own)
    check_action_parameters(actions, handlers, byname)
    check_results_cap()
    check_family_words(own)
    check_action_enums(own, actions)
    check_short_waits(own)
    check_child_scene_line(own)
    report([f'scripts: {len(own)} own, {len(others)} other Living World, {len(external)} Mantella / M.A.R.A.S / Ledger',
            f'mod events registered: {sum(len(v) for v in registered.values())}; actions: {len(actions)}; '
            f'keys used here: {len(ownkeys)}; M.A.R.A.S 2.x-only: {len(only2x)}, changed: {len(changed)}'], '-v' in sys.argv)
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
