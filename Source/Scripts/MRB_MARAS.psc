Scriptname MRB_MARAS extends Quest
{Tells Mantella each conversation NPC's M.A.R.A.S relationship with the player:
status (candidate, engaged, married, divorced or jilted, and on M.A.R.A.S 2.x
dating, lover, ex-dating or ex-lover), the odds of a yes if the player proposes,
polygamy, and the marriage-crisis rule. Lets the NPC act on it: accept a
proposal, break off the engagement, divorce, or settle a marriage crisis, each
after a Yes/No box, and change their affection score from what is said in the
talk or from other modules' MLW_ScoreEvent (deeds, care, gifts, physical). Keeps the wedding day of spouses and writes it into the NPC's file as a
fact. Writes "maras" into the NPC's file so the Integration Hub offers each NPC
only the actions that fit (0 none, 1 may accept a proposal, 2 engaged, 3 married,
4 married and in crisis), and "maras_tracked" for NPCs with a status with the
player. NPCs with MARAS's "ignore
proposal" keyword (followers who marry through their own quest) never get the
proposal odds or action. When the player talks about their marriages, the
"Learn the Player's Spouses" action tells the NPCs who the player is married
and engaged to. Kept in its own script so the Lover's Ledger half still works
without M.A.R.A.S installed.}

Actor Property PlayerRef Auto

string Property ACTION_SPOUSES = "mantella_maras_spouses" AutoReadOnly
string Property ACTION_ACCEPT = "mantella_maras_accept_proposal" AutoReadOnly
string Property ACTION_BREAK = "mantella_maras_break_engagement" AutoReadOnly
string Property ACTION_DIVORCE = "mantella_maras_divorce" AutoReadOnly
string Property ACTION_CRISIS = "mantella_maras_resolve_crisis" AutoReadOnly
string Property ACTION_AFFECTION = "mantella_maras_affection" AutoReadOnly
string Property DIR = "MantellaLivingWorld/npc/" AutoReadOnly
string Property MARAS_ESP = "TT_MARAS.esp" AutoReadOnly
string Property FACT_WEDDING = "fact_maras_wedding" AutoReadOnly
string Property KEY_WEDDING_DAY = "MRB_WeddingDay" AutoReadOnly
string Property KEY_WEDDING_DATE = "MRB_WeddingDate" AutoReadOnly
string Property KEY_AFFECTION_DAY = "MRB_AffectionDay" AutoReadOnly
string Property KEY_AFFECTION_USED = "MRB_AffectionUsed" AutoReadOnly
string Property KEY_SCORE_AT = "MRB_ScoreAt_" AutoReadOnly  ; + kind: game time of the last change from that kind
string Property PROFILES = "MantellaLivingWorld/profiles.json" AutoReadOnly  ; the Hub's "what wins them over" ratings
int Property LIMIT_REACHED = 1000 AutoReadOnly
float Property BREAKUP_DAYS = 7.0 AutoReadOnly  ; no proposal this long after a divorce or a called-off engagement

bool maras2x = false  ; set by ProbeMaras when an NPC joins a talk
bool scoring = false  ; one score change at a time, see LockScore

Event OnInit()
	Register()
EndEvent

Function Register()
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_SPOUSES, "OnSpousesLegacy")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_SPOUSES, "OnSpousesAdvanced")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_ACCEPT, "OnAccept")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_ACCEPT, "OnAcceptAdvanced")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_BREAK, "OnBreak")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_BREAK, "OnBreakAdvanced")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_DIVORCE, "OnDivorce")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_DIVORCE, "OnDivorceAdvanced")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_CRISIS, "OnCrisis")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_CRISIS, "OnCrisisNoDecision")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_AFFECTION, "OnChangeAffection")
	RegisterForModEvent("maras_status_changed", "OnMarasStatusChanged")
	RegisterForModEvent("MLW_ScoreEvent", "OnScoreEvent")
	RegisterForModEvent("MLW_Cheat", "OnCheat")
EndFunction

; The Integration Hub MCM's cheats page (testing): a M.A.R.A.S status (0 candidate, 1 engaged, 2 married) or affection
; for the target; "reset" puts back the affection from before the first cheat, but only while the score is still the
; one the last cheat set (MRB_CheatScoreSet): affection earned or lost since then stays. A status change is not undone.
Event OnCheat(Form akNpc, string asWhat, float afValue)
	Actor npc = akNpc as Actor
	If !npc || !MarasLoaded()
		Return
	EndIf
	ProbeMaras()  ; a cheat can come before any talk this session: the version decides which calls work
	string name = npc.GetDisplayName()
	If asWhat == "maras_status"
		string[] names = new string[3]
		names[0] = "candidate"
		names[1] = "engaged"
		names[2] = "married"
		int i = afValue as int
		If i < 0 || i > 2
			Return
		EndIf
		If !StorageUtil.HasIntValue(npc, "MRB_CheatScore")  ; M.A.R.A.S sets the affection with the status
			StorageUtil.SetIntValue(npc, "MRB_CheatScore", MARAS.GetPermanentAffection(npc))
		EndIf
		int scoreBefore = MARAS.GetPermanentAffection(npc)
		Promote(npc, names[i])
		; M.A.R.A.S sets the new affection in its own handler of the status event, a moment later: wait for it (up to
		; 3 s, menu-safe since the MCM is open) so Reset compares against the value the status really gave.
		int tries = 15
		While tries > 0 && MARAS.GetPermanentAffection(npc) == scoreBefore
			Utility.WaitMenuMode(0.2)
			tries -= 1
		EndWhile
		StorageUtil.SetIntValue(npc, "MRB_CheatScoreSet", MARAS.GetPermanentAffection(npc))
	ElseIf asWhat == "maras_affection"
		If CrisisRunning(npc)
			Debug.Notification(name + ": M.A.R.A.S is settling a marriage crisis; debug menu affection changes wait")
			Return
		EndIf
		int old = MARAS.GetPermanentAffection(npc)
		int v = CheatFloor(npc, afValue as int)
		If v != afValue as int
			Debug.Notification(name + ": affection held at 25; lower starts M.A.R.A.S's divorce crisis")
		EndIf
		SetScore(npc, v)
		If MARAS.GetPermanentAffection(npc) != v
			Debug.Notification(name + ": affection unchanged (M.A.R.A.S refused)")
			Return
		EndIf
		If !StorageUtil.HasIntValue(npc, "MRB_CheatScore")
			StorageUtil.SetIntValue(npc, "MRB_CheatScore", old)
		EndIf
		StorageUtil.SetIntValue(npc, "MRB_CheatScoreSet", v)
	ElseIf asWhat == "reset"
		If !StorageUtil.HasIntValue(npc, "MRB_CheatScore")
			Return
		ElseIf CrisisRunning(npc)
			Debug.Notification(name + ": M.A.R.A.S is settling a marriage crisis; affection left as it is")
			Return
		EndIf
		int before = CheatFloor(npc, StorageUtil.GetIntValue(npc, "MRB_CheatScore"))
		int setTo = StorageUtil.GetIntValue(npc, "MRB_CheatScoreSet", -1)
		StorageUtil.UnsetIntValue(npc, "MRB_CheatScore")
		StorageUtil.UnsetIntValue(npc, "MRB_CheatScoreSet")
		If MARAS.GetPermanentAffection(npc) != setTo
			Debug.Notification(name + ": affection changed since the debug menu set it; left as it is")
			Return
		EndIf
		SetScore(npc, before)
	Else
		Return
	EndIf
	WriteGate(npc)
EndEvent

; The lowest affection a cheat may set: 25 for a spouse or fiance, as ApplyChange keeps to. Below 25 M.A.R.A.S starts
; its divorce crisis and moves the spouse out, which a reset cannot undo.
int Function CheatFloor(Actor akNpc, int aiValue)
	If aiValue < 25 && (MARAS.IsNPCStatus(akNpc, "married") || MARAS.IsNPCStatus(akNpc, "engaged"))
		Return 25
	EndIf
	Return aiValue
EndFunction

Event OnSpousesLegacy(Form akSpeaker)
	SendSpouses()
EndEvent

Event OnSpousesAdvanced(Form akSpeaker, Form akConversation, int aiArguments)
	SendSpouses()
EndEvent

; Tells the conversation who the player is married and engaged to, then lets
; Mantella continue (the action is marked requires_response).
Function SendSpouses()
	If !MarasLoaded()
		Completed(ACTION_SPOUSES)
		Return
	EndIf
	string married = NameList(MARAS.GetNPCsByStatus("married"), None)
	string engaged = NameList(MARAS.GetNPCsByStatus("engaged"), None)
	string line = ""
	If married != ""
		line = "The player is married to " + married + "."
	EndIf
	If engaged != ""
		If line != ""
			line += " "
		EndIf
		line += "The player is engaged to " + engaged + "."
	EndIf
	If line == ""
		line = "The player is not married or engaged to anyone."
	EndIf
	AddMantellaEvent(line)
	int handle = ModEvent.Create("Mantella_ActionResponseCompleted")
	If handle
		ModEvent.PushString(handle, ACTION_SPOUSES)
		ModEvent.Send(handle)
	EndIf
EndFunction

; "A", "A and B", "A, B and C". Skips dead or missing actors and akSkip.
string Function NameList(Actor[] akActors, Actor akSkip)
	string[] names = new string[20]
	int count = 0
	int i = 0
	While i < akActors.Length && count < names.Length
		If akActors[i] && akActors[i] != akSkip && !akActors[i].IsDead()
			names[count] = akActors[i].GetDisplayName()
			count += 1
		EndIf
		i += 1
	EndWhile
	string result = ""
	i = 0
	While i < count
		If i > 0
			If i == count - 1
				result += " and "
			Else
				result += ", "
			EndIf
		EndIf
		result += names[i]
		i += 1
	EndWhile
	Return result
EndFunction

; M.A.R.A.S is a light plugin: GetModByName is 255 for it, GetLightModByName 65535 when it is not loaded.
bool Function MarasLoaded()
	Return Game.GetModByName(MARAS_ESP) != 255 || Game.GetLightModByName(MARAS_ESP) != 65535
EndFunction

; Only M.A.R.A.S 2.x ships this script.
Function ProbeMaras()
	maras2x = MiscUtil.FileExists("Data/Scripts/TTM_Actions.pex")
EndFunction

; M.A.R.A.S 2.x added an argument to these two calls, so each version has its own script making them.
Function Promote(Actor akNpc, string asStatus)
	If maras2x
		MRB_MarasCalls2x.Promote(akNpc, asStatus)
	Else
		MRB_MarasCalls011.Promote(akNpc, asStatus)
	EndIf
EndFunction

Function SetScore(Actor akNpc, int aiScore)
	If maras2x
		MRB_MarasCalls2x.SetScore(akNpc, aiScore)
	Else
		MRB_MarasCalls011.SetScore(akNpc, aiScore)
	EndIf
EndFunction

; The NPC has a status with the player. -1 is unregistered, 255 only has ties to other NPCs.
bool Function Tracked(Actor akNpc)
	int status = MARAS.GetNpcStatusEnum(akNpc)
	Return status >= 0 && status <= 8
EndFunction

Event OnNpcAdded(Form akActor)
	; Saves made before these actions existed only registered this event.
	Register()
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef
		Return
	ElseIf !MarasLoaded()
		StorageUtil.UnsetIntValue(npc, "MRB_Close")  ; left from before M.A.R.A.S was removed from this save
		; The NPC's file is shared by every save: drop the gates and wedding fact another save wrote.
		string path = DIR + BaseId(npc) + ".json"
		If JsonUtil.HasStringValue(path, FACT_WEDDING) || JsonUtil.GetIntValue(path, "maras") != 0 \
			|| JsonUtil.GetIntValue(path, "maras_tracked") != 0 || JsonUtil.GetIntValue(path, "maras_on") != 0
			JsonUtil.UnsetStringValue(path, FACT_WEDDING)
			JsonUtil.SetIntValue(path, "maras", 0)
			JsonUtil.SetIntValue(path, "maras_tracked", 0)
			JsonUtil.SetIntValue(path, "maras_on", 0)
			JsonUtil.Save(path)
			int handle = ModEvent.Create("MLW_RefreshNpc")
			If handle
				ModEvent.PushForm(handle, npc)
				ModEvent.Send(handle)
			EndIf
		EndIf
		Return
	ElseIf !PlayerInTalk()
		; No lines in a talk between NPCs, but the shared file may hold another save's wedding fact: refresh that.
		string file = DIR + BaseId(npc) + ".json"
		string fact = JsonUtil.GetStringValue(file, FACT_WEDDING)
		WriteWeddingFact(npc, file)
		If JsonUtil.GetStringValue(file, FACT_WEDDING) != fact
			JsonUtil.Save(file)
		EndIf
		Return
	EndIf
	string name = npc.GetDisplayName()
	string status = MARAS.GetNpcStatusName(npc)
	ProbeMaras()
	; M.A.R.A.S starts the crisis at stage 0 and moves it to its talk stage (10: objective, 3-day timer) only from its own
	; dialogue: the spouse joining a talk is that talk.
	If CrisisRunning(npc)
		Quest crisis = Game.GetFormFromFile(0x11A, MARAS_ESP) as Quest  ; TTM_AffectionEstrangedDivorce
		If crisis.GetStage() < 10
			crisis.SetStage(10)
		EndIf
	EndIf
	JsonUtil.Unload(PROFILES, false, false)  ; the Hub may have rated someone since the last talk: Load alone keeps the old copy
	JsonUtil.Load(PROFILES)
	; Mantella sends this once per NPC per talk. 0.11.1 never adds daily points, so it has no use for this.
	If maras2x && Tracked(npc)
		MRB_MarasCalls2x.CountTalk(npc)
	EndIf
	string line = StatusLine(name, status)
	line = Join(line, CoSpouseLine(npc, status))
	line = Join(line, PolygamyLine(name, status))
	line = Join(line, CrisisLine(npc, name))
	line = Join(line, SameSexLine(npc, name))
	If line != ""
		AddMantellaEvent(line)
	EndIf
	WriteGate(npc)
	; MARAS's chance reads several game stats and is slow: sent on its own, after the status line.
	string odds = OddsLine(npc, name)
	If odds != ""
		AddMantellaEvent(odds)
	EndIf
EndEvent

; M.A.R.A.S 0.11.1 offers courtship only to the opposite sex by default (MCM: Show start dialogue to genders, global
; TTM_MCM_StartDialGender, 0 = opposite). Said once per NPC, for a friend or closer of the player's own sex whom
; M.A.R.A.S does not track, so the talk knows why nothing romantic can come of it. 2.x keeps that setting in its own
; settings file: not read there (the README says where to change it).
string Function SameSexLine(Actor akNpc, string asName)
	If maras2x || Tracked(akNpc) || StorageUtil.GetIntValue(akNpc, "MRB_SameSexNoted") == 1 \
		|| akNpc.GetRelationshipRank(PlayerRef) < 1 || akNpc.GetActorBase().GetSex() != PlayerRef.GetActorBase().GetSex() \
		|| IsMinor(akNpc)
		Return ""
	EndIf
	GlobalVariable genders = Game.GetFormFromFile(0x4B, MARAS_ESP) as GlobalVariable  ; TTM_MCM_StartDialGender
	If !genders || genders.GetValueInt() != 0
		Return ""
	EndIf
	StorageUtil.SetIntValue(akNpc, "MRB_SameSexNoted", 1)
	; Only marriage courting: worded so a friend's hug or other affection is not read as forbidden too.
	Return asName + " cannot be courted for marriage through M.A.R.A.S, which is set to opposite-sex only; friendship and other affection are not affected."
EndFunction

; Mantella also sends NPC_Added for radiant talks between NPCs; those get no lines and count no talk.
bool Function PlayerInTalk()
	MantellaConversation talk = Game.GetFormFromFile(0x03D41A, "Mantella.esp") as MantellaConversation
	Return talk && talk.IsRunning() && talk.IsPlayerInConversation()
EndFunction

string Function Join(string asA, string asB)
	If asA == ""
		Return asB
	ElseIf asB == ""
		Return asA
	EndIf
	Return asA + " " + asB
EndFunction

; One plain sentence per status. String compares ignore case: MARAS may send "married" or "Married".
string Function StatusLine(string asName, string asStatus)
	If asStatus == "Married"
		Return asName + " is married to the player."
	ElseIf asStatus == "Engaged"
		Return asName + " is engaged to the player."
	ElseIf asStatus == "Candidate"
		Return "The player has shown romantic interest in " + asName + "; they are not engaged."
	ElseIf asStatus == "Divorced"
		Return asName + " and the player were married, but are now divorced."
	ElseIf asStatus == "Jilted"
		Return asName + " was engaged to the player, but the engagement was called off."
	ElseIf asStatus == "Dating"
		Return asName + " and the player are dating."
	ElseIf asStatus == "Lover"
		Return asName + " and the player are lovers."
	ElseIf asStatus == "ExDating"
		Return asName + " and the player used to date, but no longer do."
	ElseIf asStatus == "ExLover"
		Return asName + " and the player used to be lovers, but no longer are."
	EndIf
	Return ""
EndFunction

; The player's other spouses and fiances, so co-spouses in a group know they share the marriage.
string Function CoSpouseLine(Actor akNpc, string asStatus)
	If asStatus != "Married" && asStatus != "Engaged"
		Return ""
	EndIf
	string others = NameList(MARAS.GetNPCsByStatus("married"), akNpc)
	string fiances = NameList(MARAS.GetNPCsByStatus("engaged"), akNpc)
	string line = ""
	If others != ""
		line = "The player is also married to " + others + "."
	EndIf
	If fiances != ""
		line = Join(line, "The player is also engaged to " + fiances + ".")
	EndIf
	If line != ""
		line += " They all share one marriage to the player."
	EndIf
	Return line
EndFunction

string Function PolygamyLine(string asName, string asStatus)
	If (asStatus == "Married" || asStatus == "Engaged") && PolygamyAllowed()
		Return asName + " accepts that the player may take more than one spouse, as Mara allows; that does not mean liking every co-spouse."
	EndIf
	Return ""
EndFunction

; How a proposal would land, from MARAS's own success chance. Only for NPCs who may accept one.
string Function OddsLine(Actor akNpc, string asName)
	If RecentBreakup(akNpc) && Tracked(akNpc) && !MARAS.IsNPCStatus(akNpc, "engaged") && !MARAS.IsNPCStatus(akNpc, "married")
		Return asName + " and the player broke up recently; " + asName + " will not hear a proposal yet."
	ElseIf !MayPropose(akNpc)
		Return ""
	ElseIf Committed() && !PolygamyAllowed()
		Return "If the player proposes, " + asName + " would be puzzled: the player is already committed to someone."
	EndIf
	float chance = MarriageChance(akNpc)
	string odds = "would almost certainly refuse, though nothing is impossible"
	If chance >= 0.9
		odds = "would accept at once"
	ElseIf chance >= 0.7
		odds = "would be eager to accept"
	ElseIf chance >= 0.5
		odds = "would probably accept if asked kindly"
	ElseIf chance >= 0.3
		odds = "is unsure and could be swayed by the right words"
	ElseIf chance >= 0.15
		odds = "would likely refuse; only exceptional words could change that"
	EndIf
	string line = "If the player proposes marriage, " + asName + " " + odds + "."
	If chance < 0.9
		line += " A refusal is hesitation, not a final answer: asked again on another day, with heartfelt words that fit " + asName + "'s values, " + asName + " may say yes."
	EndIf
	Return line + " If " + asName + " accepts, say yes clearly."
EndFunction

; MARAS's native chance is 0.0-1.0 on every version; its script wrapper changed its return type in 2.x. No intimacy
; adjustment. "Player killer" is a StorageUtil key on both versions; 2.x moved "always success" into its own settings
; and leaves the old key as it was when it took it over.
float Function MarriageChance(Actor akNpc)
	If maras2x
		If MRB_MarasCalls2x.AlwaysSuccess()
			Return 1.0
		EndIf
	ElseIf StorageUtil.GetIntValue(None, "AlwaysSuccessMarriage") == 1
		Return 1.0
	EndIf
	Return MARAS.CalculateMarriageSuccessChance(akNpc, 0.0, Game.QueryStat("Most Gold Carried"), Game.QueryStat("Houses Owned"), \
		Game.QueryStat("Horses Owned"), Game.QueryStat("Quests Completed"), Game.QueryStat("Dungeons Cleared"), \
		Game.QueryStat("Dragon Souls Collected"), StorageUtil.GetIntValue(None, "PlayerKiller") == 1)
EndFunction

string Function CrisisLine(Actor akNpc, string asName)
	If !InCrisis(akNpc)
		Return ""
	EndIf
	Return asName + " and the player are in a marriage crisis. " + asName + " decides in this talk, from what is said now, whether to reconcile or divorce, and asks for no proof, waiting or tasks later."
EndFunction

; MARAS tracks the NPC, they are not engaged or married yet, they do not marry through their own quest, and they did not
; break up with the player in the last week.
bool Function MayPropose(Actor akNpc)
	Keyword ignore = Game.GetFormFromFile(0xC0B, MARAS_ESP) as Keyword  ; TTM_IgnoreProposal
	If !Tracked(akNpc) || MARAS.IsNPCStatus(akNpc, "engaged") || MARAS.IsNPCStatus(akNpc, "married") \
		|| (ignore && akNpc.HasKeyword(ignore)) || RecentBreakup(akNpc)
		Return false
	EndIf
	Return !maras2x || MRB_MarasCalls2x.AvailableForEngagement(akNpc)
EndFunction

; M.A.R.A.S stamps "BrokeupTime" (game days) on a divorce or a called-off engagement, on 0.11.1 and 2.x alike. Engaging
; or marrying sets affection to 100, so a quick re-proposal would undo a divorce's affection 0 and skip the crisis.
bool Function RecentBreakup(Actor akNpc)
	Return Utility.GetCurrentGameTime() < StorageUtil.GetFloatValue(akNpc, "BrokeupTime", -1000.0) + BREAKUP_DAYS
EndFunction

; As MayPropose, and on 0.11.1 the player is free to take another fiance (2.x's AvailableForEngagement checks that).
bool Function CanAccept(Actor akNpc)
	If !MayPropose(akNpc)
		Return false
	EndIf
	Return maras2x || !Committed() || PolygamyAllowed()
EndFunction

bool Function Committed()
	Return MARAS.GetStatusCount("married") + MARAS.GetStatusCount("engaged") > 0
EndFunction

; The MCM toggle, or MARAS's polygamy quest finished (stage 80 also sets the toggle), as MARAS's own wedding checks.
bool Function PolygamyAllowed()
	GlobalVariable allowed = Game.GetFormFromFile(0x06, MARAS_ESP) as GlobalVariable  ; TTM_EnablePolygamyToggle
	Quest polygamy = Game.GetFormFromFile(0x5C, MARAS_ESP) as Quest  ; TTM_EnablePolygamy, 80 = accepted
	Return (allowed && allowed.GetValue() == 1) || (polygamy && (polygamy.IsCompleted() || polygamy.GetStage() >= 80))
EndFunction

; MARAS's low-affection divorce quest is at its talk stage (10) with this spouse.
bool Function InCrisis(Actor akNpc)
	Quest crisis = Game.GetFormFromFile(0x11A, MARAS_ESP) as Quest  ; TTM_AffectionEstrangedDivorce
	If !crisis || !crisis.IsRunning() || crisis.GetStage() != 10
		Return false
	EndIf
	ReferenceAlias spouse = crisis.GetAliasByName("Spouse") as ReferenceAlias
	Return spouse && spouse.GetActorRef() == akNpc
EndFunction

; The crisis quest is running with this spouse at any stage, also before the talk stage (0: the player has not
; spoken to them yet). Affection changes wait for MARAS to settle it.
bool Function CrisisRunning(Actor akNpc)
	Quest crisis = Game.GetFormFromFile(0x11A, MARAS_ESP) as Quest  ; TTM_AffectionEstrangedDivorce
	If !crisis || !crisis.IsRunning()
		Return false
	EndIf
	ReferenceAlias spouse = crisis.GetAliasByName("Spouse") as ReferenceAlias
	Return spouse && spouse.GetActorRef() == akNpc
EndFunction

int Function GateValue(Actor akNpc)
	If MARAS.IsNPCStatus(akNpc, "married")
		If InCrisis(akNpc)
			Return 4
		EndIf
		Return 3
	ElseIf MARAS.IsNPCStatus(akNpc, "engaged")
		Return 2
	ElseIf CanAccept(akNpc)
		Return 1
	EndIf
	Return 0
EndFunction

; Also marks engaged, married, dating and lover NPCs close (MRB_Close, read by the Integration Hub and by Arousal), so close-only
; actions work without the Arousal module, and asks the Hub to rewrite the NPC's file with it.
; A generic (non-unique) NPC shares its file with every actor of that base (two Whiterun Guards): such a spouse gets no
; marriage actions, or a stranger of the same base would be offered them too. MRB_Close stays on the reference.
Function WriteGate(Actor akNpc)
	string path = DIR + BaseId(akNpc) + ".json"
	int gate = GateValue(akNpc)
	bool unique = akNpc.GetActorBase().IsUnique()
	If unique
		JsonUtil.SetIntValue(path, "maras", gate)
	Else
		JsonUtil.SetIntValue(path, "maras", 0)
	EndIf
	JsonUtil.SetIntValue(path, "maras_on", 1)  ; gates the spouses action: only offered with M.A.R.A.S installed
	JsonUtil.SetIntValue(path, "maras_tracked", (unique && Tracked(akNpc) && !CrisisRunning(akNpc)) as int)  ; gates the affection action
	WriteWeddingFact(akNpc, path)
	JsonUtil.Save(path)
	string status = MARAS.GetNpcStatusName(akNpc)
	StorageUtil.SetIntValue(akNpc, "MRB_Close", (gate >= 2 || status == "Dating" || status == "Lover") as int)
	int handle = ModEvent.Create("MLW_RefreshNpc")
	If handle
		ModEvent.PushForm(handle, akNpc)
		ModEvent.Send(handle)
	EndIf
EndFunction

; The wedding date of a spouse whose wedding this script saw. The Hub adds "(N days ago)" after the text, so the last
; sentence is the one about the wedding day. No countdown: the file is shared by every save and may be read days later.
Function WriteWeddingFact(Actor akNpc, string asPath)
	int day = StorageUtil.GetIntValue(akNpc, KEY_WEDDING_DAY, -1)
	If day < 0 || !MARAS.IsNPCStatus(akNpc, "married") || !akNpc.GetActorBase().IsUnique()
		JsonUtil.UnsetStringValue(asPath, FACT_WEDDING)
		Return
	EndIf
	string date = StorageUtil.GetStringValue(akNpc, KEY_WEDDING_DATE)
	string text = "Their wedding anniversary falls on " + date + " each year. " + akNpc.GetDisplayName() + " and the player married on that date"
	JsonUtil.SetStringValue(asPath, FACT_WEDDING, day + "|-1|2|" + text)
EndFunction

; M.A.R.A.S also sends this for ties between NPCs, so the status with the player is read back.
Event OnMarasStatusChanged(string asEventName, string asStatus, float afStatusEnum, Form akNpc)
	Actor npc = akNpc as Actor
	If !npc || npc == PlayerRef
		Return
	EndIf
	ProbeMaras()  ; WriteGate's CanAccept needs it, and this can come before any talk this session
	bool hasDay = StorageUtil.HasIntValue(npc, KEY_WEDDING_DAY)
	If MARAS.IsNPCStatus(npc, "married")
		; Only a change to married is a wedding: on 2.x a spouse married before this module can get this event for
		; a tie with another NPC.
		If !hasDay && asStatus == "married"
			StorageUtil.SetIntValue(npc, KEY_WEDDING_DAY, Utility.GetCurrentGameTime() as int)
			StorageUtil.SetStringValue(npc, KEY_WEDDING_DATE, TodaysDate())
		EndIf
	ElseIf hasDay
		StorageUtil.UnsetIntValue(npc, KEY_WEDDING_DAY)
		StorageUtil.UnsetStringValue(npc, KEY_WEDDING_DATE)
	EndIf
	; Every change with the player (an ex is no longer close) is written now: the Hub and Arousal read MRB_Close as
	; the next talk starts, before this script's own WriteGate runs. Ties between other NPCs are left alone.
	If Tracked(npc) || StorageUtil.GetIntValue(npc, "MRB_Close", 0) > 0
		WriteGate(npc)
	EndIf
EndEvent

; "17 Last Seed", from the game's GameDay and GameMonth (0 is Morning Star).
string Function TodaysDate()
	string[] months = new string[12]
	months[0] = "Morning Star"
	months[1] = "Sun's Dawn"
	months[2] = "First Seed"
	months[3] = "Rain's Hand"
	months[4] = "Second Seed"
	months[5] = "Midyear"
	months[6] = "Sun's Height"
	months[7] = "Last Seed"
	months[8] = "Hearthfire"
	months[9] = "Frostfall"
	months[10] = "Sun's Dusk"
	months[11] = "Evening Star"
	GlobalVariable month = Game.GetFormFromFile(0x36, "Skyrim.esm") as GlobalVariable
	GlobalVariable day = Game.GetFormFromFile(0x37, "Skyrim.esm") as GlobalVariable
	Return (day.GetValue() as int) + " " + months[month.GetValue() as int]
EndFunction

; ---- Actions ----

Event OnAccept(Form akSpeaker)
	Accept(Target(akSpeaker as Actor, "accept"))
	Completed(ACTION_ACCEPT)
EndEvent

Event OnAcceptAdvanced(Form akSpeaker, Form akConversation, int aiArguments)
	Accept(Target(akSpeaker as Actor, "accept"))
	Completed(ACTION_ACCEPT)
EndEvent

Event OnBreak(Form akSpeaker)
	Break(Target(akSpeaker as Actor, "break"))
	Completed(ACTION_BREAK)
EndEvent

Event OnBreakAdvanced(Form akSpeaker, Form akConversation, int aiArguments)
	Break(Target(akSpeaker as Actor, "break"))
	Completed(ACTION_BREAK)
EndEvent

Event OnDivorce(Form akSpeaker)
	Divorce(Target(akSpeaker as Actor, "divorce"))
	Completed(ACTION_DIVORCE)
EndEvent

Event OnDivorceAdvanced(Form akSpeaker, Form akConversation, int aiArguments)
	Divorce(Target(akSpeaker as Actor, "divorce"))
	Completed(ACTION_DIVORCE)
EndEvent

Event OnCrisis(Form akSpeaker, Form akConversation, int aiArguments)
	ResolveCrisis(Target(akSpeaker as Actor, "crisis"), SKSE_HTTP.getString(aiArguments, "decision", "undecided"))
	Completed(ACTION_CRISIS)
EndEvent

; requires_response is false for this action: never send Completed here, a stray one cancels the next action's wait.
Event OnChangeAffection(Form akSpeaker, Form akConversation, int aiArguments)
	; Always the speaker's own score: the change rides on their line.
	ChangeAffection(akSpeaker as Actor, SKSE_HTTP.getString(aiArguments, "change", ""), \
		SKSE_HTTP.getString(aiArguments, "amount", ""))
EndEvent

Function ChangeAffection(Actor akNpc, string asChange, string asAmount)
	If !akNpc || akNpc == PlayerRef || !MarasLoaded() || !Tracked(akNpc) || CrisisRunning(akNpc)
		Return
	EndIf
	int delta = 1
	If asAmount == "a lot"
		delta = 3
	ElseIf asAmount != "a little"
		Return
	EndIf
	If asChange == "colder"
		delta = -delta
	ElseIf asChange != "warmer"
		Return
	EndIf
	LockScore()
	int applied = ApplyChange(akNpc, delta)
	scoring = false
	string name = akNpc.GetDisplayName()
	If applied == LIMIT_REACHED
		AddMantellaEvent(name + "'s affection for the player will not change any further today.")
		Return
	ElseIf applied == 0
		AddMantellaEvent(name + "'s affection for the player did not change.")
		Return
	EndIf
	string size = "a little"
	If applied >= 3 || applied <= -3
		size = "a lot"
	EndIf
	If applied > 0
		AddMantellaEvent(name + "'s affection for the player rose " + size + ".")
	Else
		AddMantellaEvent(name + "'s affection for the player fell " + size + ".")
	EndIf
EndFunction

; The score change shared by the action and score events, at once and saved. Today's total is held to -5..+5. Neither
; takes the score below 25, so they cannot start MARAS's crisis (below 25); a score already below that can rise but not
; fall. Returns the change made, 0 at the floor or 100, or LIMIT_REACHED when today has no room left that way.
int Function ApplyChange(Actor akNpc, int aiDelta)
	int today = Utility.GetCurrentGameTime() as int
	int used = 0
	If StorageUtil.GetIntValue(akNpc, KEY_AFFECTION_DAY, -1) == today
		used = StorageUtil.GetIntValue(akNpc, KEY_AFFECTION_USED)
	EndIf
	int delta = aiDelta
	If used + delta > 5
		delta = 5 - used
	ElseIf used + delta < -5
		delta = -5 - used
	EndIf
	If delta == 0
		Return LIMIT_REACHED
	EndIf
	int score = MARAS.GetPermanentAffection(akNpc)
	int goal = score + delta
	If delta < 0 && goal < 25
		goal = 25
		If score < 25
			goal = score
		EndIf
	ElseIf delta > 0 && goal > 100
		goal = 100
		If score > 100  ; M.A.R.A.S may leave a score above 100: it can fall, not rise, and never jumps to 100
			goal = score
		EndIf
	EndIf
	If goal == score
		Return 0
	EndIf
	SetScore(akNpc, goal)
	If MARAS.GetPermanentAffection(akNpc) != goal  ; the call failed (wrong M.A.R.A.S version found): nothing counted
		Return 0
	EndIf
	StorageUtil.SetIntValue(akNpc, KEY_AFFECTION_DAY, today)
	StorageUtil.SetIntValue(akNpc, KEY_AFFECTION_USED, used + goal - score)
	Return goal - score
EndFunction

; Events run side by side, and each call into M.A.R.A.S lets another one in on this script: two changes at once (a
; gift and the action in one reply) would both read the same total and score. Call before reading them, and set
; scoring to false right after; gives up waiting after about 2 seconds rather than hold anything up for good.
Function LockScore()
	int tries = 0
	While scoring && tries < 40
		Utility.WaitMenuMode(0.05)
		tries += 1
	EndWhile
	scoring = true
EndFunction

; Points from other modules (World: deeds, care, gifts), silent. The weight is scaled by the NPC's rating of that kind
; in the Hub's profiles (1 x0.5, 2 x1, 3 x1.5, 2 if unrated) and rounded half away from zero, so a small weight can
; score 0; each kind changes the score at most once a game hour.
Event OnScoreEvent(Form akNpc, string asKind, float afWeight)
	Actor npc = akNpc as Actor
	If !npc || npc == PlayerRef || afWeight == 0.0 || !MarasLoaded() || !Tracked(npc) || CrisisRunning(npc)
		Return
	EndIf
	If asKind != "deeds" && asKind != "care" && asKind != "gifts" && asKind != "physical"
		Return
	EndIf
	ProbeMaras()
	If asKind == "physical" && (maras2x || SKSE.GetPluginVersion("LoversLedger") >= 0)
		Return  ; M.A.R.A.S adds intimacy affection itself when a scene ends: 2.x always, 0.11.1 from Lover's Ledger threads
	EndIf
	int rating = JsonUtil.GetIntValue(PROFILES, ProfileId(npc) + "_" + asKind, 2)
	If rating < 1 || rating > 3
		rating = 2
	EndIf
	float points = afWeight * rating * 0.5
	int delta = Math.Ceiling(points - 0.5)
	If points > 0.0
		delta = Math.Floor(points + 0.5)  ; under 0.5 scores nothing: one coin handed over and back is not affection
	EndIf
	If delta == 0
		Return
	EndIf
	LockScore()
	float now = Utility.GetCurrentGameTime()
	If now < StorageUtil.GetFloatValue(npc, KEY_SCORE_AT + asKind, -1.0) + 1.0 / 24.0
		scoring = false
		ScoreLog(npc.GetDisplayName() + " " + asKind + " skipped: less than a game hour since the last one")
		Return
	EndIf
	int applied = ApplyChange(npc, delta)
	If applied != 0 && applied != LIMIT_REACHED
		StorageUtil.SetFloatValue(npc, KEY_SCORE_AT + asKind, now)
	EndIf
	scoring = false
	ScoreLog(npc.GetDisplayName() + " " + asKind + " weight=" + afWeight + " rating=" + rating + " delta=" + delta + " applied=" + applied)
EndEvent

; The last ten score events (MRB_ScoreLog), for troubleshooting, like MRB_Sent for event lines.
Function ScoreLog(string asText)
	StorageUtil.StringListAdd(None, "MRB_ScoreLog", asText)
	While StorageUtil.StringListCount(None, "MRB_ScoreLog") > 10
		StorageUtil.StringListRemoveAt(None, "MRB_ScoreLog", 0)
	EndWhile
EndFunction

; Mantella's action events carry the NPC who spoke last, and an action-only reply has no line of its own, so in a
; group talk that can be someone else. If the speaker cannot take this step, use the one NPC in the talk who can;
; with two or more who could, nothing is guessed. A spouse, fiance, ex or other NPC with a status, or a child, speaks
; for themselves and is never swapped (the step then changes nothing for them).
Actor Function Target(Actor akSpeaker, string asKind)
	If !MarasLoaded() || (akSpeaker && Fits(akSpeaker, asKind))
		Return akSpeaker
	ElseIf akSpeaker && (IsMinor(akSpeaker) || Tracked(akSpeaker))
		Return akSpeaker
	EndIf
	MantellaConversation talk = Game.GetFormFromFile(0x03D41A, "Mantella.esp") as MantellaConversation
	If !talk || !talk.IsRunning()
		Return akSpeaker
	EndIf
	Actor found = None
	int i = 0
	int count = talk.CountActorsInConversation()
	While i < count
		Actor member = talk.GetActorInConversationByIndex(i)
		If member && member != PlayerRef && member != akSpeaker && Fits(member, asKind)
			If found
				Return akSpeaker
			EndIf
			found = member
		EndIf
		i += 1
	EndWhile
	If found
		Return found
	EndIf
	Return akSpeaker
EndFunction

; A child, as the Integration Hub tells them apart: the child flag or a child race.
bool Function IsMinor(Actor akActor)
	If akActor.IsChild()
		Return true
	EndIf
	Race actorRace = akActor.GetRace()
	Return actorRace && StringUtil.Find(MiscUtil.GetRaceEditorID(actorRace), "Child") >= 0
EndFunction

bool Function Fits(Actor akNpc, string asKind)
	If asKind == "accept"
		Return CanAccept(akNpc)
	ElseIf asKind == "break"
		Return MARAS.IsNPCStatus(akNpc, "engaged")
	ElseIf asKind == "divorce"
		Return MARAS.IsNPCStatus(akNpc, "married") && !CrisisRunning(akNpc)
	EndIf
	Return InCrisis(akNpc)
EndFunction

; The model named the action but gave no decision: nothing to do, but Mantella still waits for the answer.
Event OnCrisisNoDecision(Form akSpeaker)
	Completed(ACTION_CRISIS)
EndEvent

Function ResolveCrisis(Actor npc, string decision)
	If !npc || !MarasLoaded() || (decision != "reconcile" && decision != "divorce")
		Return
	ElseIf !InCrisis(npc)
		NothingChanged(npc)
		Return
	EndIf
	string name = npc.GetDisplayName()
	string ask = name + " wants to stay married. Reconcile?"
	If decision == "divorce"
		ask = name + " wants a divorce. Accept it?"
	EndIf
	; On M.A.R.A.S 2.x, stage 200 shows its own box when these settings are on: one box is enough.
	bool marasAsks = decision == "divorce" && maras2x && MRB_MarasCalls2x.AsksBeforeCrisisDivorce()
	If !marasAsks && !Confirm("crisis_" + decision, npc, ask)
		Return
	EndIf
	Quest crisis = Game.GetFormFromFile(0x11A, MARAS_ESP) as Quest
	If decision == "reconcile"
		crisis.SetStage(100)  ; MARAS: affection back to 50, quest done
		Done(npc, name + " and the player reconciled; the marriage goes on.")
	Else
		crisis.SetStage(200)  ; MARAS: divorced, affection 0
		If marasAsks
			Done(npc, name + " asked the player for a divorce.")  ; a No in MARAS's box reconciles them instead
		Else
			Done(npc, name + " divorced the player.")
		EndIf
	EndIf
EndFunction

Function Accept(Actor akNpc)
	If !akNpc || !MarasLoaded()
		Return
	ElseIf !CanAccept(akNpc)
		NothingChanged(akNpc)
		Return
	EndIf
	; M.A.R.A.S's own chance decides, once a game day per NPC: asking again the same day gets the same answer.
	int today = Utility.GetCurrentGameTime() as int
	If StorageUtil.GetIntValue(akNpc, "MRB_ProposalDay", -1) != today
		float chance = MarriageChance(akNpc)
		StorageUtil.SetIntValue(akNpc, "MRB_ProposalDay", today)
		StorageUtil.SetIntValue(akNpc, "MRB_ProposalRoll", (chance >= 1.0 || Utility.RandomFloat() < chance) as int)
	EndIf
	If StorageUtil.GetIntValue(akNpc, "MRB_ProposalRoll") == 0
		AddMantellaEvent(akNpc.GetDisplayName() + " is not ready to say yes to a proposal today.")
		Return
	ElseIf !Confirm("accept", akNpc, akNpc.GetDisplayName() + " accepted your proposal. Get engaged?")
		Return
	EndIf
	Promote(akNpc, "engaged")
	If !MARAS.IsNPCStatus(akNpc, "engaged")  ; M.A.R.A.S refused the change
		NothingChanged(akNpc)
		Return
	EndIf
	Done(akNpc, akNpc.GetDisplayName() + " accepted the player's proposal; they are now engaged.")
EndFunction

Function Break(Actor akNpc)
	If !akNpc || !MarasLoaded()
		Return
	ElseIf !MARAS.IsNPCStatus(akNpc, "engaged")
		NothingChanged(akNpc)
		Return
	ElseIf !Confirm("break", akNpc, akNpc.GetDisplayName() + " wants to call off the engagement. Accept it?")
		Return
	EndIf
	Promote(akNpc, "jilted")
	If !MARAS.IsNPCStatus(akNpc, "jilted")
		NothingChanged(akNpc)
		Return
	EndIf
	Done(akNpc, akNpc.GetDisplayName() + " called off the engagement with the player.")
EndFunction

; A spouse in a marriage crisis (any stage) settles it through the crisis action instead.
Function Divorce(Actor akNpc)
	If !akNpc || !MarasLoaded()
		Return
	ElseIf !MARAS.IsNPCStatus(akNpc, "married") || CrisisRunning(akNpc)
		NothingChanged(akNpc)
		Return
	ElseIf !Confirm("divorce", akNpc, akNpc.GetDisplayName() + " wants a divorce. Accept it?")
		Return
	EndIf
	Promote(akNpc, "divorced")
	If !MARAS.IsNPCStatus(akNpc, "divorced")
		NothingChanged(akNpc)
		Return
	EndIf
	Done(akNpc, akNpc.GetDisplayName() + " divorced the player.")
EndFunction

; The NPC may already have said it aloud; the talk should know it did not happen.
Function NothingChanged(Actor akNpc)
	AddMantellaEvent("Nothing has changed between " + akNpc.GetDisplayName() + " and the player.")
EndFunction

; Yes/No box, at most once a game day per NPC and kind, like MARAS's own actions.
bool Function Confirm(string asKind, Actor akNpc, string asText)
	string asked = "MRB_MARAS_Asked_" + asKind
	If Utility.GetCurrentGameTime() < StorageUtil.GetFloatValue(akNpc, asked, -1.0) + 1.0
		; the NPC may already have said it aloud; the talk should know it did not happen yet
		AddMantellaEvent("Nothing has changed between " + akNpc.GetDisplayName() + " and the player yet; such a decision can wait until tomorrow.")
		Return false
	EndIf
	StorageUtil.SetFloatValue(akNpc, asked, Utility.GetCurrentGameTime())
	bool yes = SkyMessage.Show(asText, "Yes", "No") == "Yes"
	If !yes
		AddMantellaEvent("The player said no: nothing has changed between " + akNpc.GetDisplayName() + " and the player.")
	EndIf
	Return yes
EndFunction

; The action files set requires_response: Mantella waits (up to 5 s of unpaused time) for this before the NPC
; speaks, so the reply knows what happened. Sent on every path, also when nothing was done.
Function Completed(string asAction)
	int handle = ModEvent.Create("Mantella_ActionResponseCompleted")
	If handle
		ModEvent.PushString(handle, asAction)
		ModEvent.Send(handle)
	EndIf
EndFunction

Function Done(Actor akNpc, string asLine)
	WriteGate(akNpc)
	AddMantellaEvent(asLine)
EndFunction

; The base record's FormID as its last 6 hex digits, like the Integration Hub's file channel.
string Function BaseId(Actor akNpc)
	Return Hex6(akNpc.GetActorBase().GetFormID(), "0123456789ABCDEF")
EndFunction

; The same id in lowercase, as the Hub writes the profile keys.
string Function ProfileId(Actor akNpc)
	Return Hex6(akNpc.GetActorBase().GetFormID(), "0123456789abcdef")
EndFunction

string Function Hex6(int aiValue, string asDigits)
	int v = aiValue
	string out = ""
	int i = 0
	While i < 6
		out = StringUtil.GetNthChar(asDigits, Math.LogicalAnd(v, 15)) + out
		v = Math.RightShift(v, 4)
		i += 1
	EndWhile
	Return out
EndFunction

Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
EndFunction
