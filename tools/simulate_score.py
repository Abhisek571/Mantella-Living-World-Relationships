"""Offline model of MRB_MARAS's affection score maths, checked against the design by random runs and by every
interleaving of two or three handlers at each Papyrus suspension point.

usage: py -3 tools/simulate_score.py [--runs 5000] [--seed 1] [--quick]

The model follows Source/Scripts/MRB_MARAS.psc line by line; "L570" style comments name the Papyrus lines. Each native
or latent call, and each call into another script, is a point where Papyrus may run another handler on this quest
script (the object lock is released there), so the handlers below are generators that yield just before every such
call. Code between two yields runs without another handler on this script getting in.

What is checked (exit 1 when any check fails):
  - the score stays in 0..100
  - a change never ends below 25 unless it started there, and then it never falls
  - today's total stays within -5..+5 and equals the sum of what was applied today
  - each score kind moves the score at most once per game hour per NPC
  - nothing moves while the crisis quest runs with that NPC
  - physical is skipped on M.A.R.A.S 2.x, and on 0.11.1 with Lover's Ledger installed
  - the action mapping and the event rounding match the design (weight x rating x 0.5, rounded half away from 0, so
    a small positive weight scores 0), and a failed adapter call (wrong M.A.R.A.S version) counts nothing
  - with the lock: no lost update in any interleaving (score and today's total both equal start + sum of applied)
  - the wedding fact for every wedding day of the year: the date, no countdown that goes stale in a shared file
  - proposals: one roll per NPC per game day from M.A.R.A.S's chance, the box only after a yes roll, no proposal
    within a week of a divorce or called-off engagement
  - the Cheats page: a spouse or fiance never set below 25, nothing during a crisis, and Reset puts back the old score
    only while the score is still the one the cheat set
  - action target: a child or an NPC with a M.A.R.A.S status is never swapped for another member
"""
import argparse, copy, random, struct, sys

sys.dont_write_bytecode = True

LIMIT_REACHED = 1000                      # L36
KEY_AFFECTION_DAY = 'MRB_AffectionDay'    # L32
KEY_AFFECTION_USED = 'MRB_AffectionUsed'  # L33
KEY_SCORE_AT = 'MRB_ScoreAt_'             # L34
KEY_WEDDING_DAY = 'MRB_WeddingDay'        # L30
KINDS = ('deeds', 'care', 'gifts', 'physical')  # L629


def f32(x):
    """Papyrus floats are 32-bit."""
    return struct.unpack('<f', struct.pack('<f', x))[0]


def as_int(x):
    """Papyrus 'float as int' truncates toward zero."""
    return int(x)


def ceiling(x):  # Math.Ceiling returns int
    import math
    return math.ceil(x)


def floor(x):  # Math.Floor returns int
    import math
    return math.floor(x)


def pmod(a, b):
    """Papyrus % on ints keeps the sign of the dividend (C rule)."""
    r = abs(a) % abs(b)
    return -r if a < 0 else r


def peq(a, b):
    """Papyrus string == ignores case."""
    return a.lower() == b.lower()


class World:
    """Everything outside the script's own code: M.A.R.A.S, StorageUtil, JsonUtil, game time, and the script's two
    variables maras2x (L38) and scoring (L39)."""

    def __init__(self, scores, actual2x=False, flag2x=None, time=10.25, tries=40):
        self.score = dict(scores)             # M.A.R.A.S permanent affection per NPC
        self.actual2x = actual2x              # which M.A.R.A.S is installed
        self.maras2x = actual2x if flag2x is None else flag2x  # the script's flag, set by ProbeMaras
        self.time = f32(time)                 # Utility.GetCurrentGameTime()
        self.store = {}                       # StorageUtil (npc, key) -> value
        self.profiles = {}                    # Hub profiles.json: npc_kind -> rating
        self.crisis = set()                   # NPCs the crisis quest runs with (any stage)
        self.tracked = set(scores)            # GetNpcStatusEnum 0..8
        self.loaded = True
        self.ledger = False                   # Lover's Ledger installed (SKSE.GetPluginVersion >= 0)
        self.scoring = False                  # L39
        self.tries = tries                    # L615; None = wait for ever (to tell timeout loss from lock bugs)
        self.use_lock = True                  # False only to prove the interleaving search finds lost updates
        self.sets = []                        # (npc, old, new, crisis at the time) for every SetScore that landed
        self.attempts = []                    # for every SetScore: did the flag match the installed version

    def snapshot(self):
        return (tuple(sorted(self.score.items())), self.maras2x, self.time, tuple(sorted(self.store.items())),
                tuple(sorted(self.crisis)), self.scoring)

    # StorageUtil
    # StorageUtil keys ignore case
    def get(self, npc, key, default=0):
        return self.store.get((npc, key.lower()), default)

    def put(self, npc, key, value):
        self.store[(npc, key.lower())] = value

    # M.A.R.A.S
    def set_score(self, npc, value):
        """L147-153: the adapter for the version the flag names. A 2.x call on 0.11.1, or a 0.11.1 call on 2.x, has the
        wrong number of arguments for the installed native: Papyrus logs an error and nothing changes."""
        self.attempts.append(self.maras2x == self.actual2x)
        if self.maras2x == self.actual2x:
            self.sets.append((npc, self.score[npc], value, npc in self.crisis))
            self.score[npc] = value


# ---- the script, one generator per function; 'yield' marks a suspension point -------------------------------------

def marasloaded(w):  # L129-131: two natives
    yield 'GetModByName'
    yield 'GetLightModByName'
    return w.loaded


def tracked(w, npc):  # L156-159
    yield 'GetNpcStatusEnum'
    return npc in w.tracked


def crisis_running(w, npc):  # L377-384
    yield 'GetFormFromFile'
    yield 'IsRunning'
    if npc not in w.crisis:
        return False
    yield 'GetAliasByName'
    yield 'GetActorRef'
    return True


def probe(w):  # L134-136
    yield 'MiscUtil.FileExists'
    w.maras2x = w.actual2x


def lock_score(w, me):  # L613-620
    if not w.use_lock:
        return
    tries = 0
    while w.scoring and (w.tries is None or tries < w.tries):
        yield 'WaitMenuMode'
        if w.tries is not None:  # unbounded: the count does not matter, and leaving it keeps the state space finite
            tries += 1
    w.scoring = True


def apply_change(w, npc, adelta, log):  # L570-608
    yield 'GetCurrentGameTime'
    today = as_int(w.time)                                     # L571
    used = 0                                                   # L572
    yield 'StorageUtil.GetIntValue day'
    if w.get(npc, KEY_AFFECTION_DAY, -1) == today:             # L573
        yield 'StorageUtil.GetIntValue used'
        used = w.get(npc, KEY_AFFECTION_USED)                  # L574
    delta = adelta                                             # L576
    if used + delta > 5:                                       # L577
        delta = 5 - used
    elif used + delta < -5:                                    # L579
        delta = -5 - used
    if delta == 0:                                             # L582
        return LIMIT_REACHED
    yield 'GetPermanentAffection'
    score = w.score[npc]                                       # L585
    goal = score + delta                                       # L586
    if delta < 0 and goal < 25:                                # L587
        goal = 25
        if score < 25:                                         # L589
            goal = score
    elif delta > 0 and goal > 100:                             # L592
        goal = 100
        if score > 100:                                        # L594
            goal = score
    if goal == score:                                          # L598
        return 0
    yield 'MRB_MarasCallsXX.SetScore'                          # L601 call into the adapter script
    yield 'MARAS.SetPermanentAffection'
    w.set_score(npc, goal)
    yield 'GetPermanentAffection'
    if w.score[npc] != goal:                                   # L602
        return 0
    yield 'StorageUtil.SetIntValue day'
    w.put(npc, KEY_AFFECTION_DAY, today)                       # L605
    yield 'StorageUtil.SetIntValue used'
    w.put(npc, KEY_AFFECTION_USED, used + goal - score)        # L606
    log.append(('applied', npc, goal - score, today))
    return goal - score                                        # L607


def change_affection(w, npc, change, amount, log, me='A'):  # L530-565
    if not (yield from marasloaded(w)) or not (yield from tracked(w, npc)) or (yield from crisis_running(w, npc)):
        return None                                            # L531
    delta = 1                                                  # L534
    if peq(amount, 'a lot'):                                   # L535
        delta = 3
    elif not peq(amount, 'a little'):                          # L537
        return None
    if peq(change, 'colder'):                                  # L540
        delta = -delta
    elif not peq(change, 'warmer'):                            # L542
        return None
    log.append(('asked', npc, delta))
    yield from lock_score(w, me)                               # L545
    applied = yield from apply_change(w, npc, delta, log)      # L546
    if w.use_lock:
        w.scoring = False                                      # L547
    yield 'GetDisplayName'
    yield 'AddMantellaEvent'
    return applied


def score_event(w, npc, kind, weight, log, me='B'):  # L624-664
    weight = f32(weight)
    if weight == 0.0:                                          # L626 (no call before this test)
        return None
    if not (yield from marasloaded(w)) or not (yield from tracked(w, npc)) or (yield from crisis_running(w, npc)):
        return None
    if kind not in KINDS:                                      # L629 (case-insensitive in Papyrus; kinds are lower case)
        if kind.lower() not in KINDS:
            return None
    yield from probe(w)                                        # L632
    if peq(kind, 'physical'):                                  # L633: physical && (maras2x || Lover's Ledger)
        if w.maras2x:
            return None
        yield 'SKSE.GetPluginVersion'
        if w.ledger:
            return None
    yield 'JsonUtil.GetIntValue'                               # L636
    rating = w.profiles.get((npc, kind.lower()), 2)
    if rating < 1 or rating > 3:                               # L637
        rating = 2
    points = f32(f32(weight * rating) * f32(0.5))              # L640
    yield 'Math.Ceiling'
    delta = ceiling(f32(points - 0.5))                         # L641
    if points > 0.0:                                           # L642
        yield 'Math.Floor'
        delta = floor(f32(points + 0.5))                       # L643 (no floor of 1: a tiny gift scores nothing)
    log.append(('rounded', npc, kind, weight, rating, delta))
    if delta == 0:                                             # L648
        return None
    yield from lock_score(w, me)                               # L651
    yield 'GetCurrentGameTime'
    now = w.time                                               # L652
    yield 'StorageUtil.GetFloatValue'
    last = w.get(npc, KEY_SCORE_AT + kind, -1.0)
    if now < f32(last + f32(1.0 / 24.0)):                      # L653
        if w.use_lock:
            w.scoring = False                                  # L654
        return 'hour'
    applied = yield from apply_change(w, npc, delta, log)      # L658
    if applied != 0 and applied != LIMIT_REACHED:              # L659
        yield 'StorageUtil.SetFloatValue'
        w.put(npc, KEY_SCORE_AT + kind, now)                   # L660
        log.append(('kind', npc, kind, now))
    if w.use_lock:
        w.scoring = False                                      # L662
    return applied


def run_to_end(gen):
    try:
        while True:
            next(gen)
    except StopIteration as e:
        return e.value


# ---- design oracle (written from the README and the action file, not from the code) --------------------------------

def design_action_delta(change, amount):
    """mantella_maras_affection.json: change warmer|colder, amount a little|a lot."""
    size = {'a little': 1, 'a lot': 3}.get(amount.lower())
    sign = {'warmer': 1, 'colder': -1}.get(change.lower())
    return None if size is None or sign is None else size * sign


def design_event_delta(weight, rating):
    """README: rating 1 x0.5, 2 x1, 3 x1.5, unrated 2; rounded half away from zero (a weight under 1 at rating 2
    scores 0, so handing one coin over and back is not affection)."""
    from decimal import Decimal, ROUND_HALF_UP
    r = rating if rating in (1, 2, 3) else 2
    p = Decimal(repr(f32(weight))) * r / 2
    return int(p.to_integral_value(rounding=ROUND_HALF_UP))  # ROUND_HALF_UP in decimal is half away from zero


class Failures:
    def __init__(self):
        self.items = {}

    def add(self, name, detail):
        self.items.setdefault(name, []).append(detail)

    def ok(self):
        return not self.items

    def report(self):
        for k, v in self.items.items():
            print(f'  FAIL {k}: {len(v)} times, first: {v[0]}')


# ---- 1. random sequences --------------------------------------------------------------------------------------------

CHANGES = ['warmer', 'colder', 'Warmer', 'COLDER', 'hotter', '', 'warm', 'colder.']
AMOUNTS = ['a little', 'a lot', 'A Lot', 'a  lot', 'alot', 'some', '', 'a little bit']
WEIGHTS = [0.1, 0.25, 0.49, 0.5, 0.51, 0.99, 1.0, 1.5, 2.0, 2.5, 3.0, 5.0, 7.5, 10.0,
           -0.1, -0.25, -0.5, -0.75, -1.0, -1.5, -2.0, -3.0, -5.0, 0.0, 1e-7, 0.3333]


def random_run(rng, fails, steps=60):
    npc = 'N'
    start = rng.randint(0, 100)
    actual2x = rng.random() < 0.5
    flag2x = actual2x if rng.random() < 0.9 else not actual2x
    w = World({npc: start}, actual2x=actual2x, flag2x=flag2x, time=rng.uniform(0, 400))
    w.ledger = rng.random() < 0.5
    for k in KINDS:
        if rng.random() < 0.7:
            w.profiles[(npc, k)] = rng.choice([-1, 0, 1, 2, 3, 4, 5])
    day_total = {}        # oracle: day -> sum of applied
    kind_moves = {}       # oracle: kind -> game times it moved the score
    for _ in range(steps):
        op = rng.random()
        before = w.score[npc]
        sets_before = len(w.sets)
        attempts_before = len(w.attempts)
        log = []
        if op < 0.12:
            w.time = f32(w.time + rng.choice([1 / 1440, 1 / 60, 1 / 24, 1 / 24 + 1e-4, 0.5, 1.0, 3.0]))
            continue
        if op < 0.17:
            (w.crisis.discard if npc in w.crisis else w.crisis.add)(npc)
            continue
        if op < 0.20:  # M.A.R.A.S's own daily change, which may leave the score anywhere in 0..100
            w.score[npc] = rng.randint(0, 100)
            continue
        if op < 0.55:
            c, a = rng.choice(CHANGES), rng.choice(AMOUNTS)
            res = run_to_end(change_affection(w, npc, c, a, log))
            want = design_action_delta(c, a)
            asked = [e for e in log if e[0] == 'asked']
            if (want is None) != (not asked) or (asked and asked[0][2] != want):
                if not (npc in w.crisis):
                    fails.add('action mapping', (c, a, want, asked))
            kind = None
        else:
            kind = rng.choice(list(KINDS) + ['Deeds', 'other'])
            weight = rng.choice(WEIGHTS) if rng.random() < 0.8 else rng.uniform(-6, 6)
            res = run_to_end(score_event(w, npc, kind, weight, log))
            for e in log:
                if e[0] == 'rounded':
                    want = design_event_delta(e[3], w.profiles.get((npc, kind.lower()), 2))
                    if want != e[5]:
                        fails.add('event rounding', dict(weight=e[3], rating=e[4], got=e[5], want=want))
            if actual2x and flag2x and kind.lower() == 'physical' and w.score[npc] != before:
                fails.add('physical on 2.x moved', (before, w.score[npc]))
            if w.ledger and kind.lower() == 'physical' and w.score[npc] != before:
                fails.add("physical with Lover's Ledger moved", (before, w.score[npc]))
        after = w.score[npc]
        applied = [e for e in log if e[0] == 'applied']
        # checks
        if not 0 <= after <= 100:
            fails.add('score out of 0..100', (before, after, log))
        if before >= 25 and after < 25:
            fails.add('fell below 25', (before, after, log))
        if before < 25 and after < before:
            fails.add('fell while below 25', (before, after, log))
        if npc in w.crisis and after != before:
            fails.add('moved during crisis', (before, after, log))
        if False in w.attempts[attempts_before:] and (after != before or applied):
            fails.add('failed adapter call counted', (before, after, log))
        for e in applied:
            day_total[e[3]] = day_total.get(e[3], 0) + e[2]
            if abs(day_total[e[3]]) > 5:
                fails.add('daily total past 5', (day_total[e[3]], log))
            if after - before != e[2]:
                fails.add('applied differs from score change', (before, after, e))
            asked = [x for x in log if x[0] in ('asked', 'rounded')]
            if asked and (asked[0][-1] > 0) != (e[2] > 0):
                fails.add('change moved the wrong way', (before, after, e))
        if applied:
            today = applied[0][3]
            if w.get(npc, KEY_AFFECTION_USED) != day_total[today]:
                fails.add('stored total differs from sum applied', (w.get(npc, KEY_AFFECTION_USED), day_total[today]))
        for e in log:
            if e[0] == 'kind':
                times = kind_moves.setdefault(e[2].lower(), [])
                # Papyrus compares now < last + 1/24 in 32-bit floats, so allow two float steps at this game time
                if times and e[3] - times[-1] < f32(1 / 24) - 2 * e[3] * 2 ** -23:
                    fails.add('kind moved twice within an hour', (e[2], times[-1], e[3]))
                times.append(e[3])
        if len(w.sets) > sets_before and res is None:
            fails.add('score set by a handler that returned early', log)


# ---- 2. interleavings -----------------------------------------------------------------------------------------------

def frame_locals(gen):
    out = []
    g = gen
    while g is not None and getattr(g, 'gi_frame', None) is not None:
        out.append((g.gi_code.co_name, g.gi_frame.f_lasti, tuple(sorted(
            (k, v) for k, v in g.gi_frame.f_locals.items() if isinstance(v, (int, float, str, bool, type(None)))))))
        g = g.gi_yieldfrom
    return tuple(out)


def explore(make, check, limit=2_000_000):
    """Every schedule of the handlers make() returns, choosing which one runs at each suspension point; states seen
    before (same shared state and same locals in every thread) are not explored again. check(world, results, logs) is
    called for each finished schedule and returns a failure text or None."""
    seen, stack, finished, bad = set(), [()], 0, []

    def replay(sched):
        w, specs = make()
        logs = [[] for _ in specs]
        gens = [fn(w, *args, logs[i]) for i, (fn, args) in enumerate(specs)]
        done, results = [False] * len(gens), [None] * len(gens)
        for t in sched:
            try:
                next(gens[t])
            except StopIteration as e:
                done[t], results[t] = True, e.value
        return w, gens, done, results, logs

    while stack:
        sched = stack.pop()
        w, gens, done, results, logs = replay(sched)
        if all(done):
            finished += 1
            msg = check(w, results, logs)
            if msg and len(bad) < 3:
                bad.append((msg, sched))
            elif msg:
                bad.append(None)
            continue
        key = (w.snapshot(), tuple(done), tuple(frame_locals(g) if not d else () for g, d in zip(gens, done)))
        if key in seen:
            continue
        seen.add(key)
        if len(seen) > limit:
            raise SystemExit('state limit reached')
        for i, d in enumerate(done):
            if not d:
                stack.append(sched + (i,))
    return finished, len(seen), bad


def no_lost_update(start, start_used=0):
    def check(w, results, logs):
        applied = sum(e[2] for lg in logs for e in lg if e[0] == 'applied')
        if w.score['N'] != start + applied:
            return f'score {w.score["N"]} != {start} + applied {applied}'
        used = w.get('N', KEY_AFFECTION_USED)
        if used != start_used + applied:
            return f'today total {used} != {start_used} + applied {applied}'
        if abs(used) > 5:
            return f'today total {used}'
        kinds = [e for lg in logs for e in lg if e[0] == 'kind']
        if len(kinds) != len({e[2] for e in kinds}):
            return 'one kind moved twice in an hour'
        if any(c for (_, _, _, c) in w.sets):
            return 'set during crisis'
        if w.scoring:
            return 'lock left held'
        return None
    return check


def crisis_start(w, log):
    """M.A.R.A.S starting its crisis quest with N while a handler runs."""
    yield 'M.A.R.A.S crisis quest start'
    w.crisis.add('N')


def scenarios(quick):
    S = []

    def mk(start, specs, used=0, tries=40, lock=True, actual2x=False):
        def make():
            w = World({'N': start}, actual2x=actual2x, tries=tries)
            w.use_lock = lock
            if used:
                w.put('N', KEY_AFFECTION_DAY, as_int(w.time))
                w.put('N', KEY_AFFECTION_USED, used)
            return w, specs
        return make

    A = (change_affection, ('N', 'warmer', 'a lot'))
    Ac = (change_affection, ('N', 'colder', 'a lot'))
    G = (score_event, ('N', 'gifts', 2.0))
    G2 = (score_event, ('N', 'gifts', 5.0))
    D = (score_event, ('N', 'deeds', 5.0))
    C = (score_event, ('N', 'care', -2.0))
    for tries, label in ((None, 'lock, unbounded wait'), (40, 'lock, 40 tries (as shipped)')):
        S.append((f'action + gift, {label}', mk(50, [A, G], tries=tries), no_lost_update(50), tries is None))
        S.append((f'gift + gift same kind, {label}', mk(50, [G, G2], tries=tries), no_lost_update(50), tries is None))
        S.append((f'action + deeds near the daily limit, {label}', mk(60, [A, D], used=3, tries=tries), no_lost_update(60, 3), tries is None))
        S.append((f'colder action + care at the floor, {label}', mk(27, [Ac, C], tries=tries), no_lost_update(27), tries is None))
        if not quick:
            S.append((f'action + gift + deeds, {label}', mk(50, [A, G, D], tries=tries), no_lost_update(50), tries is None))
    S.append(('action + gift, NO lock (the search must find the loss)', mk(50, [A, G], lock=False), no_lost_update(50), False))
    S.append(('action while M.A.R.A.S starts the crisis', mk(30, [A, (crisis_start, ())]), no_lost_update(30), False))
    return S


def odds_line(can_accept, committed, toggle, quest_done, chance):
    """L287-311. can_accept is MayPropose (CanAccept's 0.11.1 polygamy test comes after the puzzled line). toggle None /
    quest_done None: the form was not found."""
    if not can_accept:                                                     # L288
        return ''
    if committed > 0 and not (toggle is not None and toggle == 1) and not (quest_done is True):  # L290     
        return 'puzzled'
    odds = 'would almost certainly refuse, though nothing is impossible'  # L294
    if chance >= f32(0.9):
        odds = 'would accept at once'
    elif chance >= f32(0.7):
        odds = 'would be eager to accept'
    elif chance >= f32(0.5):
        odds = 'would probably accept if asked kindly'
    elif chance >= f32(0.3):
        odds = 'is unsure and could be swayed by the right words'
    elif chance >= f32(0.15):
        odds = 'would likely refuse; only exceptional words could change that'
    line = 'If the player proposes marriage, X ' + odds + '.'
    if chance < f32(0.9):                                                  # L307
        line += ' A refusal is hesitation, not a final answer'
    return line


# ---- 3. anniversary ------------------------------------------------------------------------------------------------

MONTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]  # Morning Star .. Evening Star, 365 days, no leap day
START = (7, 17)  # a new game: GameMonth 7 (Last Seed), GameDay 17 at GameDaysPassed 0.33 (8 am), read from saves


import functools


@functools.lru_cache(maxsize=None)
def calendar(days_passed):
    """GameMonth (0-based, global 0x36) and GameDay (1-based, 0x37) for an int(GameDaysPassed). Saves show
    GameDaysPassed = GameHour / 24 on the first day, so the int part and GameDay turn over together at midnight."""
    doy = sum(MONTHS[:START[0]]) + START[1] - 1 + days_passed
    doy %= 365
    m = 0
    while doy >= MONTHS[m]:
        doy -= MONTHS[m]
        m += 1
    return m, doy + 1


def wedding_text(day, name='Lydia'):
    """WriteWeddingFact with the date as TodaysDate wrote it on the wedding day. The fact is stored as
    'day|-1|2|text' and the Hub adds '(N days ago)'; the text itself depends on nothing but the wedding day, so a copy
    another save or a radiant talk reads days later is still true."""
    m, d = calendar(day)
    date = f'{d} {m}'
    return 'Their wedding anniversary falls on ' + date + ' each year. ' + name + ' and the player married on that date'


def check_anniversary(fails):
    import re
    cases = 0
    for wd in range(365):                   # a wedding on every day of the year
        day = wd + 400
        m, d = calendar(day)
        text = wedding_text(day)
        cases += 1
        if f'falls on {d} {m} each year' not in text:
            fails.add('wedding date missing', (wd, text))
        if re.search(r'\b(next in|today|tomorrow|days?)\b', text):
            fails.add('wedding fact has a countdown', (wd, text))
        if not text.endswith('married on that date'):
            fails.add("wedding fact's last sentence is not the wedding day (the Hub appends the age)", (wd, text))
    # GameMonth/GameDay as TodaysDate reads them: months[GameMonth] needs 0..11 (an index of 12 is a Papyrus error)
    for doy in range(365):
        m, d = calendar(doy)
        if not (0 <= m <= 11 and 1 <= d <= MONTHS[m]):
            fails.add('calendar out of range', (doy, m, d))
    # what a leap day would do, if a mod ever added one: the count drifts a day every fourth year
    return cases


# ---- 4. proposals, cheats and the action target ------------------------------------------------------------------

BREAKUP_DAYS = 7.0  # MRB_MARAS BREAKUP_DAYS


def may_propose(tracked, engaged, married, ignore, now, brokeup, avail2x=True):
    """MayPropose with RecentBreakup: BrokeupTime defaults to -1000 when M.A.R.A.S never stamped it."""
    recent = f32(now) < f32((brokeup if brokeup is not None else -1000.0) + BREAKUP_DAYS)
    if not tracked or engaged or married or ignore or recent:
        return False
    return avail2x


class ProposalNpc:
    def __init__(self):
        self.store = {}
        self.boxes = 0
        self.engaged = False


def accept(npc, now, chance, rand, box_yes=True, can_accept=True):
    """Accept: CanAccept, then one roll per game day stored on the NPC, then the box (Confirm) only for a yes roll."""
    if not can_accept:
        return 'nothing changed'
    today = as_int(now)
    if npc.store.get('MRB_ProposalDay', -1) != today:
        npc.store['MRB_ProposalDay'] = today
        npc.store['MRB_ProposalRoll'] = int(chance >= 1.0 or rand() < chance)
    if npc.store.get('MRB_ProposalRoll', 0) == 0:
        return 'not today'
    npc.boxes += 1
    if not box_yes:
        return 'player said no'
    npc.engaged = True
    return 'engaged'


def check_proposals(fails, rng):
    cases = 0
    # cooldown: no proposal for 7 days after a breakup, then as before
    for brokeup in (None, 0.0, 10.0, 99.5):
        for dt in (0.0, 0.5, 1.0, 6.99, 7.0, 7.01, 30.0):
            now = (brokeup or 0.0) + dt
            got = may_propose(True, False, False, False, now, brokeup)
            want = brokeup is None or dt >= BREAKUP_DAYS
            cases += 1
            if got != want:
                fails.add('breakup cooldown', (brokeup, dt, got))
    for st in ((False, False, False, False), (True, True, False, False), (True, False, True, False), (True, False, False, True)):
        if may_propose(*st, 50.0, None):
            fails.add('proposal for an untracked, engaged, married or ignored NPC', st)
    # rolls: the same answer all day, a fresh one the next day, the box only after a yes
    for chance in (0.0, 0.1, 0.5, 0.9, 1.0):
        yes_days = 0
        for day in range(200):
            npc = ProposalNpc()
            first = None
            for k in range(5):  # five proposals spread over the day
                now = day + 0.1 + k * 0.15
                res = accept(npc, now, chance, rng.random, box_yes=False)
                cases += 1
                first = res if first is None else first
                if res != first:
                    fails.add('roll changed within a day', (chance, day, first, res))
            if first == 'not today' and npc.boxes:
                fails.add('box shown after a no roll', (chance, day))
            if first != 'not today':
                yes_days += 1
        if chance == 1.0 and yes_days != 200:
            fails.add('always-success chance refused', yes_days)
        if chance == 0.0 and yes_days != 0:
            fails.add('zero chance accepted', yes_days)
        if 0.0 < chance < 1.0 and not (chance - 0.15) * 200 < yes_days < (chance + 0.15) * 200:
            fails.add('roll does not follow the chance', (chance, yes_days))
    npc = ProposalNpc()
    a = accept(npc, 3.2, 1.0, rng.random)
    b = accept(npc, 3.9, 0.0, rng.random)  # same day: the stored roll holds even if the chance changed
    if (a, b) != ('engaged', 'engaged'):
        fails.add('stored roll not reused within the day', (a, b))
    if accept(npc, 4.1, 0.0, rng.random) != 'not today':
        fails.add('no new roll on the next day', '')
    return cases


class CheatNpc:
    def __init__(self, score, status='candidate', crisis=False, refuses=False):
        self.score = score
        self.status = status
        self.crisis = crisis
        self.refuses = refuses
        self.store = {}
        self.notes = []


def cheat_floor(npc, value):
    return 25 if value < 25 and npc.status in ('married', 'engaged') else value


def on_cheat(npc, what, value):
    """OnCheat's affection, status and reset branches."""
    if what == 'maras_status':
        if 'MRB_CheatScore' not in npc.store:
            npc.store['MRB_CheatScore'] = npc.score
        npc.status = ['candidate', 'engaged', 'married'][value]
        npc.score = 50 if value == 0 else 100  # M.A.R.A.S sets these with the status
        npc.store['MRB_CheatScoreSet'] = npc.score
    elif what == 'maras_affection':
        if npc.crisis:
            npc.notes.append('crisis')
            return
        old = npc.score
        v = cheat_floor(npc, value)
        if not npc.refuses:
            npc.score = v
        if npc.score != v:
            npc.notes.append('refused')
            return
        npc.store.setdefault('MRB_CheatScore', old)
        npc.store['MRB_CheatScoreSet'] = v
    elif what == 'reset':
        if 'MRB_CheatScore' not in npc.store:
            return
        if npc.crisis:
            npc.notes.append('crisis')
            return
        before = cheat_floor(npc, npc.store.pop('MRB_CheatScore'))
        set_to = npc.store.pop('MRB_CheatScoreSet', -1)
        if npc.score != set_to:
            npc.notes.append('changed since')
            return
        npc.score = before


def check_cheats(fails, rng):
    cases = 0
    for _ in range(20000):
        npc = CheatNpc(rng.randint(0, 100), rng.choice(['candidate', 'engaged', 'married']), rng.random() < 0.15,
                       rng.random() < 0.05)
        start = npc.score
        start_crisis = npc.crisis
        took_snapshot_at = None
        earned = False
        for _ in range(rng.randint(1, 6)):
            op = rng.random()
            before = npc.score
            if op < 0.5:
                v = rng.randint(0, 100)
                on_cheat(npc, 'maras_affection', v)
                cases += 1
                if npc.crisis and npc.score != before:
                    fails.add('affection cheat during a crisis', (before, npc.score))
                if npc.status in ('married', 'engaged') and npc.score < 25 and npc.score != before:
                    fails.add('spouse set below 25', (v, npc.score))
            elif op < 0.65:
                on_cheat(npc, 'maras_status', rng.randint(0, 2))
            elif op < 0.8:  # affection earned in play after the cheat
                npc.score = max(0, min(100, npc.score + rng.choice([-3, -1, 1, 3])))
                earned = earned or npc.score != before
            else:
                snap = npc.store.get('MRB_CheatScore')
                set_to = npc.store.get('MRB_CheatScoreSet')
                on_cheat(npc, 'reset', 0)
                cases += 1
                if snap is None:
                    if npc.score != before:
                        fails.add('reset without a snapshot moved the score', (before, npc.score))
                elif npc.crisis:
                    if npc.score != before or 'MRB_CheatScore' not in npc.store:
                        fails.add('reset during a crisis', (before, npc.score))
                elif before != set_to:
                    if npc.score != before:
                        fails.add('reset wiped affection earned since the cheat', (before, set_to, npc.score))
                else:
                    if npc.score != cheat_floor(npc, snap):
                        fails.add('reset did not put back the old score', (snap, npc.score))
                if not npc.crisis and ('MRB_CheatScore' in npc.store or 'MRB_CheatScoreSet' in npc.store):
                    fails.add('reset kept the snapshot', npc.store)
            if npc.crisis and rng.random() < 0.3:
                npc.crisis = False
    # the status cheat: Reset puts back the affection from before Promote
    npc = CheatNpc(40)
    on_cheat(npc, 'maras_status', 1)
    on_cheat(npc, 'reset', 0)
    if npc.score != 40:
        fails.add('status cheat affection not undone by reset', npc.score)
    return cases


def target(speaker, members, fits):
    """Target: the speaker if they fit, or are a child or tracked; else the one other member who fits, or the speaker."""
    if speaker and fits(speaker):
        return speaker
    if speaker and (speaker['minor'] or speaker['tracked']):
        return speaker
    found = None
    for m in members:
        if m is not speaker and fits(m):
            if found:
                return speaker
            found = m
    return found or speaker


def check_target(fails):
    cases = 0
    import itertools
    kinds = [dict(minor=mi, tracked=tr, fit=fi, id=i)
             for i, (mi, tr, fi) in enumerate(itertools.product((False, True), repeat=3)) if not (mi and tr)]
    fits = lambda a: a['fit']
    for sp in kinds:
        for others in itertools.product(kinds, repeat=2):
            members = [sp] + [dict(o, id=100 + j) for j, o in enumerate(others)]
            got = target(sp, members, fits)
            cases += 1
            if (sp['minor'] or sp['tracked']) and got is not sp:
                fails.add('child or tracked speaker swapped for another member', (sp, got))
            if sp['fit'] and got is not sp:
                fails.add('fitting speaker swapped', (sp, got))
            fitting = [m for m in members[1:] if m['fit']]
            if not sp['fit'] and not sp['minor'] and not sp['tracked'] and len(fitting) == 1 and got is not fitting[0]:
                fails.add('untracked adult speaker not redirected to the one who fits', (sp, got))
    return cases


# --------------------------------------------------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', type=int, default=5000)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--quick', action='store_true')
    a = ap.parse_args()
    ok = True

    fails = Failures()
    rng = random.Random(a.seed)
    for _ in range(a.runs):
        random_run(rng, fails)
    print(f'random sequences: {a.runs} runs x 60 steps')
    if fails.ok():
        print('  all checks hold')
    else:
        fails.report()
        ok = False

    # every weight 0.01 step from -10 to 10, every rating, against the design
    rf = Failures()
    for i in range(-1000, 1001):
        wgt = i / 100
        for r in (-1, 0, 1, 2, 3, 4):
            w = World({'N': 50})
            w.profiles[('N', 'deeds')] = r
            log = []
            run_to_end(score_event(w, 'N', 'deeds', wgt, log))
            got = [e[5] for e in log if e[0] == 'rounded']
            want = [design_event_delta(wgt, r)] if f32(wgt) != 0.0 else []
            if got != want:
                rf.add('event rounding sweep', dict(weight=wgt, rating=r, got=got, want=want))
    print('rounding sweep: weights -10..10 step 0.01 x ratings -1..4')
    if rf.ok():
        print('  matches the design')
    else:
        rf.report()
        ok = False

    # scores M.A.R.A.S might leave outside 0..100: a change never goes against its sign or past today's limit
    of = Failures()
    for start in range(-10, 131):
        for c in ('warmer', 'colder'):
            for amt in ('a little', 'a lot'):
                for used in range(-5, 6):
                    w = World({'N': start})
                    w.put('N', KEY_AFFECTION_DAY, as_int(w.time))
                    w.put('N', KEY_AFFECTION_USED, used)
                    log = []
                    r = run_to_end(change_affection(w, 'N', c, amt, log))
                    moved = w.score['N'] - start
                    sign = 1 if c == 'warmer' else -1
                    if moved * sign < 0:
                        of.add('moved against the request', (start, c, amt, used, w.score['N']))
                    if abs(w.get('N', KEY_AFFECTION_USED)) > 5:
                        of.add('daily total past 5', (start, c, amt, used, w.get('N', KEY_AFFECTION_USED)))
                    if 0 <= start <= 100 and not 0 <= w.score['N'] <= 100:
                        of.add('left 0..100', (start, c, amt, w.score['N']))
    print('scores -10..130 x every request x every used total -5..5')
    if of.ok():
        print('  never against the request, total within 5')
    else:
        of.report()
        ok = False

    # OddsLine (L287-311): MARAS's own proposal rule (TTM_ServiceMarriageQuest: polygamy quest completed or toggle 1)
    od = Failures()
    BANDS = [(0.9, 'would accept at once'), (0.7, 'would be eager to accept'), (0.5, 'would probably accept if asked kindly'),
             (0.3, 'is unsure'), (0.15, 'would likely refuse'), (-1, 'would almost certainly refuse')]
    for committed in (0, 1, 2):
        for toggle in (None, 0.0, 1.0, 2.0):
            for done in (None, False, True):
                for i in range(0, 1001):
                    chance = f32(i / 1000)
                    line = odds_line(True, committed, toggle, done, chance)
                    may = committed == 0 or toggle == 1.0 or done is True
                    if not may:
                        if 'puzzled' not in line:
                            od.add('committed player not puzzled', (committed, toggle, done))
                        continue
                    want = next(t for lo, t in BANDS if chance >= f32(lo))
                    if want not in line:
                        od.add('odds band', (chance, line))
                    if (chance < f32(0.9)) != ('hesitation' in line):
                        od.add('refusal hint', (chance, line))
    if odds_line(False, 0, None, None, f32(0.95)) != '':
        od.add('odds for an NPC who may not accept', '')
    print('odds line: chance 0..1 step 0.001 x commitments x polygamy states')
    if od.ok():
        print('  bands, puzzled rule and refusal hint match')
    else:
        od.report()
        ok = False

    print('interleavings (every schedule at every suspension point):')
    for name, make, check, must_hold in scenarios(a.quick):
        finished, states, bad = explore(make, check)
        status = 'no lost update' if not bad else f'{len(bad)} bad schedules' + ('' if must_hold else ' (expected)')
        print(f'  {name}: {finished} schedules, {states} states: {status}')
        if bad:
            msg, sched = bad[0]
            print(f'    first: {msg}; schedule length {len(sched)}')
        if bad and must_hold:
            ok = False

    af = Failures()
    n = check_anniversary(af)
    print(f'wedding fact: {n} wedding days')
    if af.ok():
        print('  date kept, no countdown, wedding day last')
    else:
        af.report()
        ok = False

    for label, fn, good in (('proposals', check_proposals, 'one roll a day, box after a yes, week-long breakup cooldown'),
                            ('cheats', check_cheats, 'floor 25 for spouses, nothing in a crisis, reset only if unchanged'),
                            ('action target', lambda f, r: check_target(f), 'children and tracked NPCs never swapped')):
        pf = Failures()
        n = fn(pf, random.Random(a.seed))
        print(f'{label}: {n} cases')
        if pf.ok():
            print('  ' + good)
        else:
            pf.report()
            ok = False

    print('RESULT:', 'pass' if ok else 'FAIL')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
