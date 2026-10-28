ScriptName TTLL_Store Hidden
; Compile stub of Lover's Ledger: only the functions this mod calls (signatures of Lover's Ledger 1.2.0). Not shipped.
String[] Function GetAllActions(Actor npc, Bool isDid, Int topK) Global Native
Form[] Function GetAllLovers(Actor npc, Int topK) Global Native
Float Function GetLoverFlt(Actor npc, Actor lover, String propName) Global Native
Int Function GetLoverInt(Actor npc, Actor lover, String propName) Global Native
