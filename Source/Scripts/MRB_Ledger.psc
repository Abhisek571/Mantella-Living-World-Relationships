Scriptname MRB_Ledger extends Quest
{Tells Mantella an NPC's intimate history from Lover's Ledger: their history
with the player, their most frequent acts and their other lovers. After an
OStim scene with the player it tells the partner, and can open a Mantella
conversation so the partner speaks first. On its own quest so the rest of the
bridge works without Lover's Ledger.}

Actor Property PlayerRef Auto
; 1 = after a scene, open a Mantella conversation with the partner if none is running.
GlobalVariable Property MRB_AfterSceneTalk Auto

; How many lovers and acts to name.
int Property MAX_LOVERS = 3 AutoReadOnly
int Property MAX_ACTS = 3 AutoReadOnly

bool inConversation = false

Event OnInit()
	Register()
EndEvent

Function Register()
	RegisterForModEvent("MantellaConversation_Started", "OnConversationStarted")
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
	RegisterForModEvent("MantellaConversation_Ended", "OnConversationEnded")
	RegisterForModEvent("ttll_thread_data_event", "OnLedgerThreadData")
EndFunction

Event OnConversationStarted()
	inConversation = true
EndEvent

Event OnConversationEnded()
	inConversation = false
EndEvent

; ---------------------------------------------------------------------------
; History, acts and lovers, once per NPC when they join
; ---------------------------------------------------------------------------

Event OnNpcAdded(Form akActor)
	inConversation = true
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef || !PlayerTalkRunning()
		Return
	EndIf
	string rank = RankLine(npc)
	; Lover's Ledger not installed, or a child in the talk: no intimate history, acts or lovers are told.
	If SKSE.GetPluginVersion("LoversLedger") < 0 || IsMinor(npc) || MinorInTalk()
		If rank != ""
			AddMantellaEvent(rank)
		EndIf
		Return
	EndIf
	string line = Join(rank, HistoryLine(npc))
	string acts = ActsLine(npc)
	string lovers = LoversLine(npc)
	If acts != ""
		line = Join(line, acts)
	EndIf
	If lovers != ""
		line = Join(line, lovers)
	EndIf
	If line != ""
		AddMantellaEvent(line)
	EndIf
EndEvent

; The relationship rank other mods set through dialogue. Mantella's own prompt doesn't mention it.
string Function RankLine(Actor akActor)
	int rank = akActor.GetRelationshipRank(PlayerRef)
	string name = akActor.GetDisplayName()
	If rank >= 4
		Return name + " sees the player as a lover."
	ElseIf rank == 3
		If StorageUtil.GetIntValue(akActor, "MRB_Close", 0) > 0  ; M.A.R.A.S sets rank 3 for a fiance: the status line says it
			Return ""
		EndIf
		Return name + " sees the player as a trusted ally."
	ElseIf rank == 2
		Return name + " sees the player as a close friend."
	EndIf
	Return ""
EndFunction

string Function HistoryLine(Actor akActor)
	int alone = TTLL_Store.GetLoverInt(akActor, PlayerRef, "exclusiveSex")
	int group = TTLL_Store.GetLoverInt(akActor, PlayerRef, "partOfSameGroupSex")
	If alone + group <= 0
		Return ""
	EndIf
	string line = akActor.GetDisplayName() + " and the player have been intimate " + Times(alone + group)
	If group > 0
		line += " (" + group + " of them with others present)"
	EndIf
	string ago = AgoText(TTLL_Store.GetLoverFlt(akActor, PlayerRef, "lastTime"))
	If ago != ""
		line += "; the last time was " + ago
	EndIf
	Return line + "."
EndFunction

string Function ActsLine(Actor akActor)
	string[] acts = TTLL_Store.GetAllActions(akActor, true, MAX_ACTS)
	; Several act types share one word: name each word once.
	string[] names = new string[3]
	int count = 0
	int i = 0
	While i < acts.Length && count < names.Length
		If acts[i] != ""
			string name = MRB_Text.ActName(acts[i])
			If name != "" && names.Find(name) < 0
				names[count] = name
				count += 1
			EndIf
		EndIf
		i += 1
	EndWhile
	If count == 0
		Return ""
	EndIf
	string list = ""
	i = 0
	While i < count
		list = MRB_Text.ListAdd(list, names[i], i == count - 1 && count > 1)
		i += 1
	EndWhile
	Return "What " + akActor.GetDisplayName() + " does most in bed: " + list + "."
EndFunction

string Function LoversLine(Actor akActor)
	Form[] lovers = TTLL_Store.GetAllLovers(akActor, MAX_LOVERS + 1)
	ActorBase playerBase = PlayerRef.GetActorBase()
	string[] names = new string[4]
	int count = 0
	int i = 0
	While i < lovers.Length && count < MAX_LOVERS
		ActorBase loverBase = lovers[i] as ActorBase
		If loverBase && loverBase != playerBase && loverBase.GetName() != ""
			names[count] = loverBase.GetName()
			count += 1
		EndIf
		i += 1
	EndWhile
	If count == 0
		Return ""
	EndIf
	string list = ""
	i = 0
	While i < count
		list = MRB_Text.ListAdd(list, names[i], i == count - 1 && count > 1)
		i += 1
	EndWhile
	Return akActor.GetDisplayName() + " has also been intimate with " + list + "."
EndFunction

; ---------------------------------------------------------------------------
; After a scene
; ---------------------------------------------------------------------------

Event OnLedgerThreadData(int aiThreadID)
	Actor[] actors = TTLL_ThreadsCollector.GetActors(aiThreadID)
	If !actors || actors.Find(PlayerRef) < 0
		Return
	EndIf
	string partners = ""
	Actor first = None
	int count = 0
	int i = 0
	While i < actors.Length
		If actors[i] && actors[i] != PlayerRef
			count += 1
			If !first
				first = actors[i]
			EndIf
		EndIf
		i += 1
	EndWhile
	If !first
		Return
	EndIf
	i = 0
	int named = 0
	While i < actors.Length
		If actors[i] && actors[i] != PlayerRef
			named += 1
			partners = MRB_Text.ListAdd(partners, actors[i].GetDisplayName(), named == count && count > 1)
		EndIf
		i += 1
	EndWhile
	string line = partners + " and the player just finished having sex."
	; Mantella keeps a queued line until the next talk with anyone, so it is sent only to the player's running talk or
	; right before opening one.
	If PlayerTalkRunning()
		If !OStimExpansionLoaded() && !MinorInTalk()  ; OStim Expansion tells the running talk about the scene itself
			AddMantellaEvent(line)
		EndIf
	ElseIf MRB_AfterSceneTalk.GetValueInt() == 1
		StartTalk(first, line)
	EndIf
EndEvent

; Casts Mantella's own conversation spell from the player on the partner, the
; same as the player starting a conversation. Mantella reads queued in-game
; events when it builds the opening context, so the partner's first line can
; react to the scene.
Function StartTalk(Actor akPartner, string asLine)
	Spell mantellaSpell = Game.GetFormFromFile(0x0022EF, "Mantella.esp") as Spell
	If !mantellaSpell || akPartner.IsDead() || akPartner.IsInCombat()
		Return
	EndIf
	; Give the animation time to end so nobody talks mid get-up.
	Utility.Wait(3.0)
	AddMantellaEvent(asLine)
	mantellaSpell.Cast(PlayerRef, akPartner)
EndFunction

; ---------------------------------------------------------------------------
; Text helpers
; ---------------------------------------------------------------------------

string Function Times(int aiCount)
	If aiCount == 1
		Return "once"
	ElseIf aiCount == 2
		Return "twice"
	EndIf
	Return aiCount + " times"
EndFunction

; lastTime is in game days (GameDaysPassed).
string Function AgoText(float afLastTime)
	If afLastTime <= 0.0
		Return ""
	EndIf
	float days = Utility.GetCurrentGameTime() - afLastTime
	If days < 0.0
		Return ""
	ElseIf days < 1.0 / 24.0
		Return "less than an hour ago"
	ElseIf days < 1.0
		Return "earlier today"
	ElseIf days < 2.0
		Return "yesterday"
	ElseIf days < 14.0
		Return (days as int) + " days ago"
	ElseIf days < 60.0
		Return ((days / 7.0) as int) + " weeks ago"
	EndIf
	Return "months ago"
EndFunction


string Function Join(string asA, string asB)
	If asA == ""
		Return asB
	EndIf
	Return asA + " " + asB
EndFunction


Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
EndFunction

; Mantella's conversation quest runs only during a talk (the Ended event, and so inConversation, can be missed), and
; also for radiant talks between NPCs, so the player is looked for too.
bool Function PlayerTalkRunning()
	MantellaConversation talk = Game.GetFormFromFile(0x03D41A, "Mantella.esp") as MantellaConversation
	Return talk && talk.IsRunning() && talk.IsPlayerInConversation()
EndFunction

; A child, as the Integration Hub tells them apart: the child flag or a child race.
bool Function IsMinor(Actor akActor)
	If akActor.IsChild()
		Return true
	EndIf
	Race actorRace = akActor.GetRace()
	Return actorRace && StringUtil.Find(MiscUtil.GetRaceEditorID(actorRace), "Child") >= 0
EndFunction

; A child is in the running Mantella conversation.
bool Function MinorInTalk()
	MantellaConversation talk = Game.GetFormFromFile(0x03D41A, "Mantella.esp") as MantellaConversation
	If !talk || !talk.IsRunning()
		Return false
	EndIf
	int count = talk.CountActorsInConversation()
	int i = 0
	While i < count
		Actor member = talk.GetActorInConversationByIndex(i)
		If member && member != PlayerRef && IsMinor(member)
			Return true
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

bool Function OStimExpansionLoaded()
	string esp = "Mantella Living World - OStim Expansion.esp"
	Return Game.GetModByName(esp) != 255 || Game.GetLightModByName(esp) != 65535
EndFunction
