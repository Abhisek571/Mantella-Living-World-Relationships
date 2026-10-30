# Mantella Living World - Relationships

Mantella NPCs who know where they stand with you. A module of [Mantella Living World - Integration Hub](https://github.com/Abhisek571/Mantella-Living-World-Hub).

| Feature | What it does |
|---|---|
| Marriage (M.A.R.A.S) | Status and mood lines, spouses and co-spouses. Proposal odds are shown only for NPCs M.A.R.A.S tracks as proposal candidates, as a six-step scale, and never for followers who marry through their own quest. Actions: accept a proposal, break off an engagement, divorce, settle a marriage crisis |
| Yes/No box | Each marriage action asks the player first. Allowed once per game day per NPC and per kind of action; choosing No also blocks a retry for that day, and Mantella is not told about the No, so the NPC may have said yes aloud with nothing happening |
| Learn the player's spouses | Lets the player tell an NPC who they are married and engaged to. Only offered when M.A.R.A.S is installed |
| Marriage crisis | The NPC is told to decide in the talk. M.A.R.A.S ends the crisis in divorce after 3 game days |
| Family ties (Relations Finder) | Parents, children, siblings, spouses, cousins, partners, bosses, employees, enemies and sworn enemies from the game's own relationship records. Up to 4 names per kind; dead relatives are marked |
| Shared history (Lover's Ledger) | A short summary of what you have been through together (a few favourite acts and a few other lovers, group scenes noted) and a short talk after a scene. Needs an adult framework that Lover's Ledger supports (OStim). The after-scene talk is skipped if the partner is dead or in combat |
| Closeness | Engaged and married NPCs count as close for the other modules' actions |

Each part runs only when its mod is installed. Group talks: if the last speaker cannot take a marriage step, the action goes to the one NPC in the talk who can; with two or more possible, nothing happens. Without Mantella's Advanced Actions on (Actions tab of Mantella's settings), the actions are not offered.

Family (with Relations Finder): each NPC hears their family and ties. With Mantella Living World - World installed, a relative who died during the playthrough gets the day, close family (parent, child, sibling, spouse, partner) who died in the last 30 days are grieved, and close family you struck in that time are mentioned.

Requires: the Integration Hub, Mantella - Direct AI Connect (supplies the action events), [Mantella](https://www.nexusmods.com/skyrimspecialedition/mods/98631) 0.14 with Advanced Actions on, [Papyrus MessageBox - SKSE NG](https://www.nexusmods.com/skyrimspecialedition/mods/83578), PapyrusUtil SE, SKSE_HTTP (comes with Mantella). Optional, each for its own part: [M.A.R.A.S](https://www.nexusmods.com/skyrimspecialedition/mods/159033) (with its TT_MARAS.esp), [Lover's Ledger](https://www.nexusmods.com/skyrimspecialedition/mods/158983), [Relations Finder](https://www.nexusmods.com/skyrimspecialedition/mods/158980). Keep the Hub and this module on matching versions.

Build: the Hub's `tools/build.py --only relationships`.

License: GNU AGPL-3.0.
