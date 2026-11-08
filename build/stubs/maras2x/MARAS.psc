Scriptname MARAS Hidden
; Compile stub of M.A.R.A.S 2.x: only what MRB_MarasCalls2x calls. The real script ships with M.A.R.A.S.
bool Function PromoteNPCToStatus(Actor npc, string statusType, bool sendEvent = true) global native
Function SetPermanentAffection(Actor npc, int amount, bool sendEvent = true) global native
bool Function IsAvailableForStatus(Actor npc, string status) global native
bool Function GetSettingBool(string key) global native
