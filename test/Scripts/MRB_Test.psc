Scriptname MRB_Test Hidden
{Test build only (never shipped): global functions DevBench calls to drive the M.A.R.A.S half's live tests.}

MRB_MARAS Function Main() global
	MRB_MARAS m = Game.GetFormFromFile(0x000802, "Mantella Living World - Relationships.esp") as MRB_MARAS
	m.ProbeMaras()
	Return m
EndFunction

; Status, score, gates and today's total for one NPC.
string Function Status(Actor akNpc) global
	MRB_MARAS m = Main()
	string path = "MantellaLivingWorld/npc/" + m.BaseId(akNpc) + ".json"
	Return "status=" + MARAS.GetNpcStatusName(akNpc) + " enum=" + MARAS.GetNpcStatusEnum(akNpc) + " score=" + MARAS.GetPermanentAffection(akNpc) \
		+ " tracked=" + m.Tracked(akNpc) + " canAccept=" + m.CanAccept(akNpc) + " crisis=" + m.InCrisis(akNpc) \
		+ " close=" + StorageUtil.GetIntValue(akNpc, "MRB_Close", -1) + " used=" + StorageUtil.GetIntValue(akNpc, "MRB_AffectionUsed") \
		+ " usedDay=" + StorageUtil.GetIntValue(akNpc, "MRB_AffectionDay", -1) + " today=" + (Utility.GetCurrentGameTime() as int) \
		+ " jsonTracked=" + JsonUtil.GetIntValue(path, "maras_tracked", -1) + " jsonGate=" + JsonUtil.GetIntValue(path, "maras", -1)
EndFunction

; The raw file checks behind the version choice.
string Function Probe() global
	Return "TTM_Actions=" + MiscUtil.FileExists("Data/Scripts/TTM_Actions.pex") + " adapter2x=" + MiscUtil.FileExists("Data/Scripts/MRB_MarasCalls2x.pex")
EndFunction

; The same handler the action uses. Returns the score after it.
int Function Change(Actor akNpc, string asChange, string asAmount) global
	Main().ChangeAffection(akNpc, asChange, asAmount)
	Return MARAS.GetPermanentAffection(akNpc)
EndFunction

; Sets the score through the version's adapter and clears today's total.
int Function SetUp(Actor akNpc, int aiScore) global
	Main().SetScore(akNpc, aiScore)
	StorageUtil.UnsetIntValue(akNpc, "MRB_AffectionDay")
	StorageUtil.UnsetIntValue(akNpc, "MRB_AffectionUsed")
	Return MARAS.GetPermanentAffection(akNpc)
EndFunction

string Function Lines(Actor akNpc) global
	MRB_MARAS m = Main()
	string name = akNpc.GetDisplayName()
	Return m.StatusLine(name, MARAS.GetNpcStatusName(akNpc)) + " || " + m.OddsLine(akNpc, name) + " || chance=" + m.MarriageChance(akNpc)
EndFunction

; Pretends the wedding happened aiDaysAgo days ago, rewrites the file, returns the fact as written.
string Function Wedding(Actor akNpc, int aiDaysAgo) global
	MRB_MARAS m = Main()
	StorageUtil.SetIntValue(akNpc, "MRB_WeddingDay", (Utility.GetCurrentGameTime() as int) - aiDaysAgo)
	StorageUtil.SetStringValue(akNpc, "MRB_WeddingDate", m.TodaysDate())
	m.WriteGate(akNpc)
	Return JsonUtil.GetStringValue("MantellaLivingWorld/npc/" + m.BaseId(akNpc) + ".json", "fact_maras_wedding", "(none)")
EndFunction

string Function WeddingFact(Actor akNpc) global
	MRB_MARAS m = Main()
	Return "day=" + StorageUtil.GetIntValue(akNpc, "MRB_WeddingDay", -1) + " date=" + StorageUtil.GetStringValue(akNpc, "MRB_WeddingDate") \
		+ " fact=" + JsonUtil.GetStringValue("MantellaLivingWorld/npc/" + m.BaseId(akNpc) + ".json", "fact_maras_wedding", "(none)")
EndFunction

; Sends one score event as another module would and returns the score after it. Score events are queued: read
; Status a moment later if the number has not moved yet.
int Function ScoreEvent(Actor akNpc, string asKind, float afWeight) global
	int handle = ModEvent.Create("MLW_ScoreEvent")
	If handle
		ModEvent.PushForm(handle, akNpc)
		ModEvent.PushString(handle, asKind)
		ModEvent.PushFloat(handle, afWeight)
		ModEvent.Send(handle)
	EndIf
	Utility.Wait(0.5)
	Return MARAS.GetPermanentAffection(akNpc)
EndFunction

; Lets a kind count again at once, as if a game hour had passed.
Function ClearScoreHour(Actor akNpc, string asKind) global
	StorageUtil.UnsetFloatValue(akNpc, "MRB_ScoreAt_" + asKind)
EndFunction

; The profile rating used for a kind, and the last score events.
string Function ScoreInfo(Actor akNpc, string asKind) global
	MRB_MARAS m = Main()
	string text = "key=" + m.ProfileId(akNpc) + "_" + asKind + " rating=" + JsonUtil.GetIntValue(m.PROFILES, m.ProfileId(akNpc) + "_" + asKind, -1) + " log:"
	int i = 0
	While i < StorageUtil.StringListCount(None, "MRB_ScoreLog")
		text += " | " + StorageUtil.StringListGet(None, "MRB_ScoreLog", i)
		i += 1
	EndWhile
	Return text
EndFunction

; Promotes through the version's adapter, so the status event fires as in play. For a throwaway NPC on a test save.
Function Promote(Actor akNpc, string asStatus) global
	Main().Promote(akNpc, asStatus)
EndFunction
