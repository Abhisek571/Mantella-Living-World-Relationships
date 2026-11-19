# Changelog

Every change to Mantella Living World - Relationships. The Nexus page lists only the main changes for each version.

## Unreleased

### Changed
- Code cleanup of the offline check and simulation tools: long functions split into smaller steps, new tests for the Papyrus checker. No change in game behaviour.

## 1.2.1 (2026-11-18)

### New
- The NPC's M.A.R.A.S status (married, engaged, dating, lover) is written for the Integration Hub's NPCs page, so a partner is a fact the NPC never contradicts.
- Each NPC seen in a talk has their name, home and family ties (spouse, courting, parent, child, sibling, cousin, works for, employs, household, enemy) written for the Integration Hub, once a game day, from powerofthree's Papyrus Extender (relatives need not be loaded) and Relations Finder. The Hub uses them to pass news along families and households.
- Every M.A.R.A.S status change with you is logged for the Integration Hub, marked when an absolute command was in force.
- The Integration Hub can ask to end a marriage made under an absolute command when it is released: one Yes/No box, then the same M.A.R.A.S divorce as the divorce action.

### Changed
- Shorter description for ChangeAffection (less text sent to the model on every reply; same values). It now says plainly that the change is never mentioned as a score or amount.
- The note on why an NPC of your own sex cannot be courted through M.A.R.A.S is no longer sent as an event in every talk; the Hub adds it only when you speak of marrying or proposing.
- The short talk after a scene waits until you have been out of the game's dialogue, scenes and other talks for 10 seconds (at most 90 seconds, then it is skipped), so it never cuts into a dialogue mod's next line or the next scene.
- The after-scene talk is not opened when you have walked away from your partner (about 21 m), and every time it is not opened the Papyrus log says why (too far, timed out, a talk already open, setting off).

### Fixed
- Marriage boxes name M.A.R.A.S and the step: "Divorce (M.A.R.A.S)", "Engagement (M.A.R.A.S)", "Marriage crisis (M.A.R.A.S)".
- An NPC married to the player through M.A.R.A.S who also has a game spouse and a partner is told only once whom they left to marry the player.
- A husband or wife counts as close family: a widow is told she is grieving her husband, and an NPC is told you struck their wife. Before, only the word spouse counted.
- ChangeAffection and ResolveMarriageCrisis offer only the words they act on, so other wordings ("slightly warmer", "reconciled") no longer do nothing.
- Affection changes and the marriage log wait for each other in steps the game keeps reliably.
- request_results.json keeps only the newest 50 results instead of growing for the whole game.
- An NPC married to you no longer calls their own husband or wife "former spouse": the line says they left that spouse to marry you.
- Lover's Ledger: an NPC is no longer told they have "also been intimate with" their own husband or wife.
- A husband or wife who died or was struck is now grieved and mentioned like other close family.
- The talk opened after a scene no longer gets the scene line twice when OStim Expansion is installed.
- M.A.R.A.S asks the Integration Hub to update an NPC's file only when the standing changed, and registers its events only once.
- Two scenes close together no longer open two after-scene talks: only the newest scene's talk is opened, with its own line.
- With M.A.R.A.S removed from a save, the note on courting an NPC of your own sex is also cleared from the NPC's file.
- A divorce request already answered in another save is no longer looked up again after every loading screen.
- An NPC's file is saved when a talk starts only if their M.A.R.A.S values changed.
- A request made for one character no longer shows up in another character's game.
- No after-scene line or talk is made for a scene that has a child in it.
- Sworn enemies (the lowest relationship rank) are now written as enemies in an NPC's family ties, not only plain enemies.

## 1.2.0 (2026-11-09)

### New
- Affection action: an NPC's feelings for you grow warmer or colder after something in the talk that truly matters, through M.A.R.A.S.
- Debug menu support (Integration Hub's MCM page): set an NPC's M.A.R.A.S status and affection, and reset them.
- M.A.R.A.S 2.x support.
- Breakup cooldown, proposal chance, a clear "no" when an NPC turns you down, and a fact on your wedding day.
- Children are never offered romance.

### Fixed
- The debug menu's Reset after a status change always said the affection had changed.
- The same-sex courting line made a friend refuse a hug; it now says only M.A.R.A.S marriage courting is off.
- Spouse and target fixes; the score floor on events is removed.

## 1.1.0 (2026-10-30)
- New, with Mantella Living World - World 1.1.0: a relative who died in your playthrough gets the day, close family who died in the last 30 days are grieved, and close family you struck are mentioned.
- Version file for the Hub's update check.

## 1.0.0 (2026-10-30)
- First release. Requires Mantella Living World - Integration Hub.
