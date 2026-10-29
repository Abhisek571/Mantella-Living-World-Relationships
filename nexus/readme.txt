Mantella Living World - Relationships
Version 1.0.0 by itsPigeon2000

Mantella NPCs who know where they stand with you: marriage and spouses (M.A.R.A.S), family ties (Relations Finder) and your history together (Lover's Ledger). Each part runs only when its mod is installed.

What it does
- Marriage: status and mood lines, spouses and co-spouses. Proposal odds are shown only for NPCs M.A.R.A.S tracks as candidates (not for followers who marry through their own quest).
- Actions: accept a proposal, break off an engagement, divorce, settle a marriage crisis. Each asks you Yes/No first, once per game day per NPC and per kind. Choosing No blocks a retry for that day and Mantella is not told, so the NPC may have said yes aloud with nothing happening. These actions need Mantella's Advanced Actions on.
- Learn the player's spouses: you can tell an NPC who you are married and engaged to. Only offered when M.A.R.A.S is installed.
- Family ties: parents, children, siblings, spouses, cousins, partners, bosses, employees, enemies and sworn enemies, up to 4 names per kind.
- Shared history: a short summary of your time together (a few favourite acts and other lovers) and a short talk after a scene. Needs an adult framework that Lover's Ledger supports (OStim).
- Engaged and married NPCs count as close for the other modules' actions.

Requirements
- Mantella Living World - Integration Hub (same version as this module)
- Mantella - Direct AI Connect
- Mantella 0.14, with Advanced Actions on (Actions tab of Mantella's settings)
- Papyrus MessageBox - SKSE NG
- PapyrusUtil SE
- SKSE_HTTP (comes with Mantella)
- Optional, each for its own part: M.A.R.A.S (with TT_MARAS.esp), Lover's Ledger, Relations Finder

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
