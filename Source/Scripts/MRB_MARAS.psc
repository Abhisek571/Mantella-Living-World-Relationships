Scriptname MRB_MARAS extends Quest
{Tells Mantella each conversation NPC's M.A.R.A.S relationship with the player:
status (candidate, engaged, married, divorced or jilted) and how they feel
about it (MARAS affection), the odds of a yes if the player proposes,
polygamy, and the marriage-crisis rule. Lets the NPC act on it: accept a
proposal, break off the engagement, divorce, or settle a marriage crisis, each
after a Yes/No box. Writes "maras" into the NPC's file so the Integration Hub
offers each NPC only the actions that fit (0 none, 1 may accept a proposal,
2 engaged, 3 married, 4 married and in crisis). NPCs with MARAS's "ignore
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
string Property DIR = "MantellaLivingWorld/npc/" AutoReadOnly
string Property MARAS_ESP = "TT_MARAS.esp" AutoReadOnly

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

Event OnNpcAdded(Form akActor)
	; Saves made before these actions existed only registered this event.
	Register()
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef || !MarasLoaded()
		Return
	EndIf
	string name = npc.GetDisplayName()
	string status = MARAS.GetNpcStatusName(npc)
	string line = StatusLine(name, status, MARAS.GetPermanentAffection(npc))
	line = Join(line, CoSpouseLine(npc, status))
	line = Join(line, PolygamyLine(name, status))
	line = Join(line, CrisisLine(npc, name))
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

string Function Join(string asA, string asB)
	If asA == ""
		Return asB
	ElseIf asB == ""
		Return asA
	EndIf
	Return asA + " " + asB
EndFunction

; Status and mood, by MARAS affection (0-100): 75 and up, 50, 25, below 25.
string Function StatusLine(string asName, string asStatus, int aiAffection)
	int band = 0
	If aiAffection >= 75
		band = 3
	ElseIf aiAffection >= 50
		band = 2
	ElseIf aiAffection >= 25
		band = 1
	EndIf
	If asStatus == "Married"
		string[] married = new string[4]
		married[0] = "is unhappy and is thinking about divorce, but will raise it with the player first"
		married[1] = "has doubts about the marriage, but hopes things get better"
		married[2] = "is content and committed to the marriage"
		married[3] = "is deeply in love and committed to the marriage"
		Return asName + " is married to the player and " + married[band] + "."
	ElseIf asStatus == "Engaged"
		string[] engaged = new string[4]
		engaged[0] = "regrets it and is thinking of calling it off"
		engaged[1] = "has begun to wonder whether it was a good idea, but still hopes"
		engaged[2] = "is committed to making it work"
		engaged[3] = "is deeply in love and looks forward to the wedding"
		Return asName + " is engaged to the player and " + engaged[band] + "."
	ElseIf asStatus == "Candidate"
		string[] candidate = new string[4]
		candidate[0] = "cares little for them"
		candidate[1] = "does not think about them much"
		candidate[2] = "is attracted to them"
		candidate[3] = "has fallen for them"
		Return "The player has shown romantic interest in " + asName + ", who " + candidate[band] + "; they are not engaged."
	ElseIf asStatus == "Divorced"
		string[] divorced = new string[4]
		divorced[0] = "still hates the player for it"
		divorced[1] = "still resents the player"
		divorced[2] = "holds no grudge"
		divorced[3] = "would like to try again"
		Return asName + " and the player were married, but are now divorced; " + asName + " " + divorced[band] + "."
	ElseIf asStatus == "Jilted"
		string[] jilted = new string[4]
		jilted[0] = "still hates the player for it"
		jilted[1] = "still resents the player"
		jilted[2] = "holds no grudge"
		jilted[3] = "is thinking of rekindling it"
		Return asName + " was engaged to the player, but the engagement was called off; " + asName + " " + jilted[band] + "."
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
	Quest polygamy = Game.GetFormFromFile(0x5C, MARAS_ESP) as Quest  ; TTM_EnablePolygamy, 80 = accepted
	If (asStatus == "Married" || asStatus == "Engaged") && polygamy && polygamy.GetStage() >= 80
		Return asName + " accepts that the player may take more than one spouse, as Mara allows; that does not mean liking every co-spouse."
	EndIf
	Return ""
EndFunction

; How a proposal would land, from MARAS's own success chance. Only for NPCs who may accept one.
string Function OddsLine(Actor akNpc, string asName)
	If !CanAccept(akNpc)
		Return ""
	EndIf
	GlobalVariable allowed = Game.GetFormFromFile(0x06, MARAS_ESP) as GlobalVariable  ; TTM_EnablePolygamyToggle
	bool committed = MARAS.GetStatusCount("married") + MARAS.GetStatusCount("engaged") > 0
	Quest polygamy = Game.GetFormFromFile(0x5C, MARAS_ESP) as Quest  ; finishing MARAS's polygamy quest also allows it
	If committed && !(allowed && allowed.GetValue() == 1) && !(polygamy && polygamy.IsCompleted())
		Return "If the player proposes, " + asName + " would be puzzled: the player is already committed to someone."
	EndIf
	float chance = TTM_ServiceMarriageDifficulty.calcMarriageSuccessChance(akNpc)
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
		line += " A refusal is hesitation, not a final answer: heartfelt words that fit " + asName + "'s values can change it."
	EndIf
	Return line + " If " + asName + " accepts, say yes clearly."
EndFunction

string Function CrisisLine(Actor akNpc, string asName)
	If !InCrisis(akNpc)
		Return ""
	EndIf
	Return asName + " and the player are in a marriage crisis. " + asName + " decides in this talk, from what is said now, whether to reconcile or divorce, and asks for no proof, waiting or tasks later."
EndFunction

; MARAS tracks the NPC, they are not engaged or married yet, and they do not marry through their own quest.
bool Function CanAccept(Actor akNpc)
	Keyword ignore = Game.GetFormFromFile(0xC0B, MARAS_ESP) as Keyword  ; TTM_IgnoreProposal
	Return MARAS.IsNPCStatus(akNpc, "any") && !MARAS.IsNPCStatus(akNpc, "engaged") && !MARAS.IsNPCStatus(akNpc, "married") \
		&& !(ignore && akNpc.HasKeyword(ignore))
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

; Also marks engaged and married NPCs close (MRB_Close, read by the Integration Hub and by Arousal), so close-only
; actions work without the Arousal module, and asks the Hub to rewrite the NPC's file with it.
Function WriteGate(Actor akNpc)
	string path = DIR + BaseId(akNpc) + ".json"
	int gate = GateValue(akNpc)
	JsonUtil.SetIntValue(path, "maras", gate)
	JsonUtil.SetIntValue(path, "maras_on", 1)  ; gates the spouses action: only offered with M.A.R.A.S installed
	JsonUtil.Save(path)
	StorageUtil.SetIntValue(akNpc, "MRB_Close", (gate >= 2) as int)
	int handle = ModEvent.Create("MLW_RefreshNpc")
	If handle
		ModEvent.PushForm(handle, akNpc)
		ModEvent.Send(handle)
	EndIf
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

; Mantella's action events carry the NPC who spoke last, and an action-only reply has no line of its own, so in a
; group talk that can be someone else. If the speaker cannot take this step, use the one NPC in the talk who can;
; with two or more who could, nothing is guessed.
Actor Function Target(Actor akSpeaker, string asKind)
	If !MarasLoaded() || (akSpeaker && Fits(akSpeaker, asKind))
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

bool Function Fits(Actor akNpc, string asKind)
	If asKind == "accept"
		Return CanAccept(akNpc)
	ElseIf asKind == "break"
		Return MARAS.IsNPCStatus(akNpc, "engaged")
	ElseIf asKind == "divorce"
		Return MARAS.IsNPCStatus(akNpc, "married") && !InCrisis(akNpc)
	EndIf
	Return InCrisis(akNpc)
EndFunction

; The model named the action but gave no decision: nothing to do, but Mantella still waits for the answer.
Event OnCrisisNoDecision(Form akSpeaker)
	Completed(ACTION_CRISIS)
EndEvent

Function ResolveCrisis(Actor npc, string decision)
	If !npc || !MarasLoaded() || !InCrisis(npc) || (decision != "reconcile" && decision != "divorce")
		Return
	EndIf
	string name = npc.GetDisplayName()
	string ask = name + " wants to stay married. Reconcile?"
	If decision == "divorce"
		ask = name + " wants a divorce. Accept it?"
	EndIf
	If !Confirm("crisis", npc, ask)
		Return
	EndIf
	Quest crisis = Game.GetFormFromFile(0x11A, MARAS_ESP) as Quest
	If decision == "reconcile"
		crisis.SetStage(100)  ; MARAS: affection back to 50, quest done
		Done(npc, name + " and the player reconciled; the marriage goes on.")
	Else
		crisis.SetStage(200)  ; MARAS: divorced, affection 0
		Done(npc, name + " divorced the player.")
	EndIf
EndFunction

Function Accept(Actor akNpc)
	If !akNpc || !MarasLoaded() || !CanAccept(akNpc) || !Confirm("accept", akNpc, akNpc.GetDisplayName() + " accepted your proposal. Get engaged?")
		Return
	EndIf
	MARAS.PromoteNPCToStatus(akNpc, "engaged")
	Done(akNpc, akNpc.GetDisplayName() + " accepted the player's proposal; they are now engaged.")
EndFunction

Function Break(Actor akNpc)
	If !akNpc || !MarasLoaded() || !MARAS.IsNPCStatus(akNpc, "engaged") || !Confirm("break", akNpc, akNpc.GetDisplayName() + " wants to call off the engagement. Accept it?")
		Return
	EndIf
	MARAS.PromoteNPCToStatus(akNpc, "jilted")
	Done(akNpc, akNpc.GetDisplayName() + " called off the engagement with the player.")
EndFunction

Function Divorce(Actor akNpc)
	If !akNpc || !MarasLoaded() || !MARAS.IsNPCStatus(akNpc, "married") || InCrisis(akNpc) \
		|| !Confirm("divorce", akNpc, akNpc.GetDisplayName() + " wants a divorce. Accept it?")
		Return
	EndIf
	MARAS.PromoteNPCToStatus(akNpc, "divorced")
	Done(akNpc, akNpc.GetDisplayName() + " divorced the player.")
EndFunction

; Yes/No box, at most once a game day per NPC and kind, like MARAS's own AI actions.
bool Function Confirm(string asKind, Actor akNpc, string asText)
	string asked = "MRB_MARAS_Asked_" + asKind
	If Utility.GetCurrentGameTime() < StorageUtil.GetFloatValue(akNpc, asked, -1.0) + 1.0
		; the NPC may already have said it aloud; the talk should know it did not happen yet
		AddMantellaEvent("Nothing has changed between " + akNpc.GetDisplayName() + " and the player yet; such a decision can wait until tomorrow.")
		Return false
	EndIf
	StorageUtil.SetFloatValue(akNpc, asked, Utility.GetCurrentGameTime())
	Return SkyMessage.Show(asText, "Yes", "No") == "Yes"
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
	string digits = "0123456789ABCDEF"
	int v = akNpc.GetActorBase().GetFormID()
	string out = ""
	int i = 0
	While i < 6
		out = StringUtil.GetNthChar(digits, Math.LogicalAnd(v, 15)) + out
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
