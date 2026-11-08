Mantella Living World - Relationships
Version 1.1.0 by itsPigeon2000

Mantella NPCs who know where they stand with you: marriage and spouses (M.A.R.A.S), family ties (Relations Finder) and your history together (Lover's Ledger). Each part runs only when its mod is installed.

What it does
- Marriage (M.A.R.A.S): status lines, spouses and co-spouses. Proposal odds are shown only for NPCs M.A.R.A.S tracks as candidates (not for followers who marry through their own quest). M.A.R.A.S's own chance decides a proposal, rolled once per NPC per game day. No proposal is heard for 7 game days after a divorce or a called-off engagement. On M.A.R.A.S 2.x also dating, lover, ex-dating and ex-lover.
- Actions: accept a proposal, break off an engagement, divorce, settle a marriage crisis. Each asks you Yes/No first, once per game day per NPC and per kind. Choosing No blocks a retry for that day, and the talk is told you said no. When a step cannot happen, the talk is told that nothing has changed. On M.A.R.A.S 0.11.1 a second engagement needs its polygamy (MCM toggle or its polygamy quest). Generic (non-unique) spouses such as a married guard get no marriage actions. Same-sex courtship needs M.A.R.A.S MCM > Show start dialogue to genders set to All. These actions need Mantella's Advanced Actions on.
- Affection: the NPC can raise or lower their own M.A.R.A.S affection score from what is said in a talk, a little (1) or a lot (3), at most 5 up or down per game day. It never drops the score below 25 and does nothing during a marriage crisis.
- Event points: deeds, care and gifts recorded by Mantella Living World - World move the score too, scaled by what wins that NPC over (a small gift can count nothing), at most once a game hour per kind, within the same daily limit. Physical closeness is left to M.A.R.A.S when it counts scenes itself (2.x, or 0.11.1 with Lover's Ledger).
- Marriage crisis: when the spouse joins a talk, the crisis moves to M.A.R.A.S's talk stage and the NPC decides in the talk whether to reconcile or divorce. M.A.R.A.S ends it in divorce after 3 game days. The plain divorce action is not offered during a crisis.
- Wedding day: a spouse knows the wedding date and how long you have been married, for weddings that happen with this module installed.
- Learn the player's spouses: you can tell an NPC who you are married and engaged to. Only offered when M.A.R.A.S is installed.
- Family ties (Relations Finder): parents, children, siblings, spouses, cousins, partners, bosses, employees, enemies and sworn enemies, up to 4 names per kind. With Mantella Living World - World, a relative who died in your playthrough gets the day, close family who died in the last 30 days are grieved, and close family you struck are mentioned. The game's own spouse of an NPC who married you through M.A.R.A.S is named as former.
- Shared history (Lover's Ledger): a short summary of your time together (a few favourite acts and other lovers) and a short talk after a scene, never while a child is in the talk. Needs an adult framework that Lover's Ledger supports (OStim). The after-scene talk is skipped if the partner is dead or in combat; type set MRB_AfterSceneTalk to 0 in the console to turn it off (1 turns it back on).
- Engaged and married NPCs count as close for the other modules' actions; on M.A.R.A.S 2.x, also dating and lover.
- Radiant talks between NPCs get none of these lines.

Requirements
- Mantella Living World - Integration Hub (same version as this module)
- Mantella - Direct AI Connect
- Mantella 0.14, with Advanced Actions on (Actions tab of Mantella's settings)
- Papyrus MessageBox - SKSE NG
- PapyrusUtil SE
- SKSE_HTTP (comes with Mantella)
- Optional, each for its own part: M.A.R.A.S 0.11.1 or 2.x (with TT_MARAS.esp), Lover's Ledger, Relations Finder, Mantella Living World - World (for the grief and struck-family lines)

Before you start
1. Mantella 0.14: install it and check that a normal conversation works.
2. Mantella - Direct AI Connect: install it below Mantella in MO2 and run its Setup Backend.cmd once (needs Python 3.11). Without it the stock Mantella.exe runs and Living World does nothing.
3. Mantella Living World - Integration Hub, then the modules you want.
4. API key: your LLM service's key stays in GPT_SECRET_KEY.txt in the Mantella mod folder (in MO2, right-click Mantella, Open in Explorer). A key for another service goes in the file named on the Direct AI Connect page, next to it.
5. Open Mantella's settings page (http://localhost:4999/ui in your browser, only while Mantella is running), go to the Actions tab and turn on Advanced Actions. Many Living World actions (bribe, persuade, marriage steps, positions, map marks and others) only work with it, and it needs a model that supports tool calling.
6. Nothing happens? Living World Main Status in Mantella's settings page lists what is missing.

Installation
1. Install the hub, then this module.

Credits
- Mantella by Art from the Machine and contributors (AGPL-3.0)
- SKSE team
- PapyrusUtil SE by exiledviper and meh321
- M.A.R.A.S and Lover's Ledger by TangyTweaks
- Relations Finder (see its Nexus page for the author)

License
GNU Affero General Public License v3.0 (see LICENSE.txt). Script sources are included in Scripts\Source.
Source code: https://github.com/Abhisek571/Mantella-Living-World-Relationships
