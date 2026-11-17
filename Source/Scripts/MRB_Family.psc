Scriptname MRB_Family extends Quest
{Tells Mantella each conversation NPC's family and ties from the game's own
relationship records, through Relations Finder: parents, children, siblings,
cousins, spouse, partner, boss, workers and enemies. The lines need the
Relations Finder SKSE plugin. Kept in its own script so the other parts work
without it.
With Mantella Living World - World installed, a relative who died during the
playthrough gets the day, close family who died in the last 30 days are
grieved, and close family the player struck in that time are mentioned (World
keeps both days on the relative: MLWW_DiedDay, MLWW_StruckDay).
Also writes each NPC seen in a talk to ties.json (once a game day per NPC) for
the Integration Hub: name, home and ties, from powerofthree's Papyrus Extender
(base records, so relatives need not be loaded) and Relations Finder. With
neither installed nothing is written.}

Actor Property PlayerRef Auto

int Property MAX_NAMES = 4 AutoReadOnly  ; per kind of tie
float Property RECENT_DAYS = 30.0 AutoReadOnly
string Property TIES_FILE = "MantellaLivingWorld/ties.json" AutoReadOnly
string Property PO3_PLUGIN = "powerofthree's Papyrus Extender" AutoReadOnly
int Property MAX_TIES = 128 AutoReadOnly  ; per NPC in ties.json

Event OnInit()
	Register()
EndEvent

Function Register()
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
EndFunction

Event OnNpcAdded(Form akActor)
	If StorageUtil.GetIntValue(None, "MLW_TimingOn", 0) == 1  ; speed testing (off by default): one stage-time row
		MiscUtil.WriteToFile("Data/SKSE/Plugins/StorageUtilData/MantellaLivingWorld/timing_game.csv", StorageUtil.GetIntValue(None, "MLW_TimingTalk", 0) + "," + Utility.GetCurrentRealTime() + ",MRB_Family,OnNpcAdded_start,\n", true, false)
	EndIf
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef
		Return
	EndIf
	bool finder = SKSE.GetPluginVersion("RelationsFinder") >= 0
	If finder && PlayerInTalk()
		SendTies(npc)
	EndIf
	WriteTies(npc, finder)  ; after the lines, so they are never held up
	If StorageUtil.GetIntValue(None, "MLW_TimingOn", 0) == 1  ; speed testing (off by default): one stage-time row
		MiscUtil.WriteToFile("Data/SKSE/Plugins/StorageUtilData/MantellaLivingWorld/timing_game.csv", StorageUtil.GetIntValue(None, "MLW_TimingTalk", 0) + "," + Utility.GetCurrentRealTime() + ",MRB_Family,OnNpcAdded_end,\n", true, false)
	EndIf
EndEvent

Function SendTies(Actor npc)
	string ties = ""
	; Filled by Tie on the NPC itself: two NPCs joining one talk run this side by side.
	StorageUtil.UnsetStringValue(npc, "MRB_Grieving")
	StorageUtil.UnsetStringValue(npc, "MRB_Struck")
	; M.A.R.A.S makes an NPC the player's spouse or fiance without touching the game's own spouse records: the game's
	; spouse stays their husband or wife (no divorce between them ever happened), whom they left for the player.
	Actor[] spouses = TTRF_RelationsFinder.GetNpcRelationships(npc, "Spouse")
	string after = ""
	If Game.GetModByName("TT_MARAS.esp") != 255 || Game.GetLightModByName("TT_MARAS.esp") != 65535
		If MARAS.IsNPCStatus(npc, "married")
			after = ", whom " + npc.GetDisplayName() + " left to marry the player"
		ElseIf MARAS.IsNPCStatus(npc, "engaged")
			after = ", though " + npc.GetDisplayName() + " is now engaged to the player"
		EndIf
	EndIf
	ties = Tie(npc, ties, "parent", TTRF_RelationsFinder.GetNpcRelationships(npc, "ParentChild", "primary"))
	ties = Tie(npc, ties, "child", TTRF_RelationsFinder.GetNpcRelationships(npc, "ParentChild", "secondary"))
	ties = Tie(npc, ties, "sibling", TTRF_RelationsFinder.GetNpcRelationships(npc, "Siblings"))
	ties = Tie(npc, ties, "cousin", TTRF_RelationsFinder.GetNpcRelationships(npc, "Cousins"))
	string withoutSpouse = ties
	ties = Tie(npc, ties, SpouseWord(spouses), spouses, after)
	If ties != withoutSpouse  ; the M.A.R.A.S note goes on the first of the spouse and partner ties only
		after = ""
	EndIf
	ties = Tie(npc, ties, "partner", TTRF_RelationsFinder.GetNpcRelationships(npc, "Courting"), after)
	ties = Tie(npc, ties, "works for", TTRF_RelationsFinder.GetNpcRelationships(npc, "BossEmployee", "primary"))
	ties = Tie(npc, ties, "employs", TTRF_RelationsFinder.GetNpcRelationships(npc, "BossEmployee", "secondary"))
	ties = Tie(npc, ties, "enemy of", TTRF_RelationsFinder.GetNpcRelationships(npc, "", "any", -4, -3))
	ties = Tie(npc, ties, "sworn enemy of", TTRF_RelationsFinder.GetNpcRelationships(npc, "", "any", -4, -4))
	If ties != ""
		AddMantellaEvent(npc.GetDisplayName() + "'s ties: " + ties + ".")
	EndIf
	string grieving = StorageUtil.GetStringValue(npc, "MRB_Grieving")
	string struckKin = StorageUtil.GetStringValue(npc, "MRB_Struck")
	StorageUtil.UnsetStringValue(npc, "MRB_Grieving")
	StorageUtil.UnsetStringValue(npc, "MRB_Struck")
	If grieving != ""
		AddMantellaEvent(npc.GetDisplayName() + " is grieving: " + grieving + ".")
	EndIf
	If struckKin != ""
		AddMantellaEvent(npc.GetDisplayName() + " knows that " + PlayerRef.GetDisplayName() + " struck " + struckKin + ".")
	EndIf
EndFunction

; "husband" or "wife" from the first spouse's sex, "spouse" when that is unknown.
string Function SpouseWord(Actor[] akSpouses)
	int i = 0
	While akSpouses && i < akSpouses.Length
		If akSpouses[i] && akSpouses[i] != PlayerRef
			int sex = akSpouses[i].GetActorBase().GetSex()
			If sex == 0
				Return "husband"
			ElseIf sex == 1
				Return "wife"
			EndIf
			Return "spouse"
		EndIf
		i += 1
	EndWhile
	Return "spouse"
EndFunction

; Mantella also sends NPC_Added for radiant talks between NPCs; those get no lines.
bool Function PlayerInTalk()
	MantellaConversation talk = Game.GetFormFromFile(0x03D41A, "Mantella.esp") as MantellaConversation
	Return talk && talk.IsRunning() && talk.IsPlayerInConversation()
EndFunction

; SpouseWord names a spouse "husband" or "wife": those are close too.
bool Function IsCloseKind(string asKind)
	Return asKind == "parent" || asKind == "child" || asKind == "sibling" || asKind == "spouse" || asKind == "husband" \
		|| asKind == "wife" || asKind == "partner" || asKind == "former spouse" || asKind == "former partner"
EndFunction

; "today", "yesterday" or "N days ago".
string Function DaysAgo(float afDay, float afNow)
	int days = (afNow as int) - (afDay as int)
	If days <= 0
		Return "today"
	ElseIf days == 1
		Return "yesterday"
	EndIf
	Return days + " days ago"
EndFunction

; Adds "their sibling Sven, who died 3 days ago" style text to a list.
string Function AddTo(string asList, string asText)
	If asList != ""
		Return asList + "; " + asText
	EndIf
	Return asText
EndFunction

; Adds "kind A, B (dead)" (then asAfter) to the list and grief or struck kin to akNpc's MRB_Grieving / MRB_Struck; the player is left out (Relationships' MARAS part covers them).
string Function Tie(Actor akNpc, string asTies, string asKind, Actor[] akActors, string asAfter = "")
	string names = ""
	int count = 0
	float now = Utility.GetCurrentGameTime()
	bool close = IsCloseKind(asKind)
	int i = 0
	While akActors && i < akActors.Length && count < MAX_NAMES
		Actor a = akActors[i]
		If a && a != PlayerRef
			string name = a.GetDisplayName()
			If a.IsDead()
				float died = StorageUtil.GetFloatValue(a, "MLWW_DiedDay", -1.0)
				If died >= 0.0
					name += " (died " + DaysAgo(died, now) + ")"
					If close && now - died <= RECENT_DAYS
						StorageUtil.SetStringValue(akNpc, "MRB_Grieving", AddTo(StorageUtil.GetStringValue(akNpc, "MRB_Grieving"), "their " + asKind + " " + a.GetDisplayName() + ", who died " + DaysAgo(died, now)))
					EndIf
				Else
					name += " (dead)"
				EndIf
			ElseIf close
				float struck = StorageUtil.GetFloatValue(a, "MLWW_StruckDay", -1.0)
				If struck >= 0.0 && now - struck <= RECENT_DAYS
					StorageUtil.SetStringValue(akNpc, "MRB_Struck", AddTo(StorageUtil.GetStringValue(akNpc, "MRB_Struck"), "their " + asKind + " " + a.GetDisplayName() + " " + DaysAgo(struck, now)))
				EndIf
			EndIf
			If names != ""
				names += ", "
			EndIf
			names += name
			count += 1
		EndIf
		i += 1
	EndWhile
	If names == ""
		Return asTies
	ElseIf asTies != ""
		asTies += "; "
	EndIf
	Return asTies + asKind + " " + names + asAfter
EndFunction

; Sends one event line to the running Mantella conversation and keeps the last ten (MRB_Sent) for troubleshooting.
Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
	StorageUtil.StringListAdd(None, "MRB_Sent", asText)
	While StorageUtil.StringListCount(None, "MRB_Sent") > 10
		StorageUtil.StringListRemoveAt(None, "MRB_Sent", 0)
	EndWhile
EndFunction

; ---- ties.json ----

; Writes akNpc's name, home and ties into ties.json under their base id, at most once a game day per NPC. Merged with
; what the file holds: a relative who is not loaded now is never dropped. po3 reads the base records (relatives need
; not be loaded) but cannot tell a parent from a child or a boss from a worker; Relations Finder tells those for
; loaded relatives, and a child or elder race tells the rest of parent and child. A tie neither can place is left out
; until one can.
Function WriteTies(Actor akNpc, bool abFinder)
	bool po3 = SKSE.GetPluginVersion(PO3_PLUGIN) >= 0
	int today = Utility.GetCurrentGameTime() as int
	If (!po3 && !abFinder) || StorageUtil.GetIntValue(akNpc, "MRB_TiesDay", -1) == today
		Return
	EndIf
	StorageUtil.SetIntValue(akNpc, "MRB_TiesDay", today)  ; first, so a second join the same moment skips
	ActorBase base = akNpc.GetActorBase()
	string id = "." + MRB_Text.Id6(base.GetFormID())
	string[] kinds = new string[128]
	string[] bases = new string[128]
	string[] names = new string[128]
	int n = 0
	int count = JsonUtil.PathCount(TIES_FILE, id + ".ties")
	int i = 0
	While i < count && n < MAX_TIES
		string row = id + ".ties[" + i + "]"
		kinds[n] = JsonUtil.GetPathStringValue(TIES_FILE, row + ".kind")
		bases[n] = JsonUtil.GetPathStringValue(TIES_FILE, row + ".base")
		names[n] = JsonUtil.GetPathStringValue(TIES_FILE, row + ".name")
		If kinds[n] != "" && bases[n] != ""
			n += 1
		EndIf
		i += 1
	EndWhile
	Actor[] parents
	Actor[] children
	If abFinder
		parents = TTRF_RelationsFinder.GetNpcRelationships(akNpc, "ParentChild", "primary")
		children = TTRF_RelationsFinder.GetNpcRelationships(akNpc, "ParentChild", "secondary")
		n = AddActors(kinds, bases, names, n, "parent", parents)
		n = AddActors(kinds, bases, names, n, "child", children)
		n = AddActors(kinds, bases, names, n, "sibling", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "Siblings"))
		n = AddActors(kinds, bases, names, n, "cousin", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "Cousins"))
		n = AddActors(kinds, bases, names, n, "spouse", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "Spouse"))
		n = AddActors(kinds, bases, names, n, "courting", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "Courting"))
		n = AddActors(kinds, bases, names, n, "works_for", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "BossEmployee", "primary"))
		n = AddActors(kinds, bases, names, n, "employs", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "BossEmployee", "secondary"))
		n = AddActors(kinds, bases, names, n, "enemy", TTRF_RelationsFinder.GetNpcRelationships(akNpc, "", "any", -4, -3))
	EndIf
	If po3
		n = AddBases(kinds, bases, names, n, "spouse", PO3_SKSEFunctions.GetRelationships(base, Association(0x0142CA)))
		n = AddBases(kinds, bases, names, n, "courting", PO3_SKSEFunctions.GetRelationships(base, Association(0x01EE23)))
		n = AddBases(kinds, bases, names, n, "sibling", PO3_SKSEFunctions.GetRelationships(base, Association(0x0142C5)))
		n = AddBases(kinds, bases, names, n, "cousin", PO3_SKSEFunctions.GetRelationships(base, Association(0x0142C8)))
		ActorBase[] family = PO3_SKSEFunctions.GetRelationships(base, Association(0x0142C6))  ; ParentChild, either way
		i = 0
		While family && i < family.Length
			n = AddTie(kinds, bases, names, n, ParentOrChild(base, family[i], parents, children), family[i], "")
			i += 1
		EndWhile
	EndIf
	string home = ""
	Location place = akNpc.GetEditorLocation()
	If place && IsHome(place)
		home = place.GetName()
		If po3 && IsHousehold(place)
			n = AddHousehold(kinds, bases, names, n, akNpc, place)
		EndIf
	EndIf
	If home == ""
		home = JsonUtil.GetPathStringValue(TIES_FILE, id + ".home")
	EndIf
	string raw = "{\"name\":" + MRB_Text.Quote(akNpc.GetDisplayName()) + ",\"home\":" + MRB_Text.Quote(home) + ",\"day\":" + today + ",\"ties\":["
	i = 0
	While i < n
		If i > 0
			raw += ","
		EndIf
		raw += "{\"kind\":\"" + kinds[i] + "\",\"base\":\"" + bases[i] + "\",\"name\":" + MRB_Text.Quote(names[i]) + "}"
		i += 1
	EndWhile
	If JsonUtil.SetRawPathValue(TIES_FILE, id, raw + "]}")
		JsonUtil.Save(TIES_FILE)
	Else
		StorageUtil.UnsetIntValue(akNpc, "MRB_TiesDay")  ; try again at the next talk
	EndIf
EndFunction

AssociationType Function Association(int aiFormId)
	Return Game.GetFormFromFile(aiFormId, "Skyrim.esm") as AssociationType
EndFunction

; Adds a tie unless the same kind and base id is there; a known one gets the name it has now. Returns the new count.
int Function AddTie(string[] akKinds, string[] akBases, string[] akNames, int aiCount, string asKind, ActorBase akBase, string asName)
	If asKind == "" || !akBase || akBase == PlayerRef.GetActorBase()
		Return aiCount
	EndIf
	string id = MRB_Text.Id6(akBase.GetFormID())
	string name = asName
	If name == ""
		name = akBase.GetName()
	EndIf
	int i = 0
	While i < aiCount
		If akBases[i] == id && akKinds[i] == asKind
			If name != ""
				akNames[i] = name
			EndIf
			Return aiCount
		EndIf
		i += 1
	EndWhile
	If aiCount >= MAX_TIES
		Return aiCount
	EndIf
	akKinds[aiCount] = asKind
	akBases[aiCount] = id
	akNames[aiCount] = name
	Return aiCount + 1
EndFunction

int Function AddActors(string[] akKinds, string[] akBases, string[] akNames, int aiCount, string asKind, Actor[] akActors)
	int n = aiCount
	int i = 0
	While akActors && i < akActors.Length
		If akActors[i] && akActors[i] != PlayerRef
			n = AddTie(akKinds, akBases, akNames, n, asKind, akActors[i].GetActorBase(), akActors[i].GetDisplayName())
		EndIf
		i += 1
	EndWhile
	Return n
EndFunction

int Function AddBases(string[] akKinds, string[] akBases, string[] akNames, int aiCount, string asKind, ActorBase[] akList)
	int n = aiCount
	int i = 0
	While akList && i < akList.Length
		n = AddTie(akKinds, akBases, akNames, n, asKind, akList[i], "")
		i += 1
	EndWhile
	Return n
EndFunction

; "parent" or "child" for a ParentChild relative of akBase, "" when that cannot be told: Relations Finder's answer
; for a loaded relative first, then a child race on one side, then an elder race on one side.
string Function ParentOrChild(ActorBase akBase, ActorBase akRelative, Actor[] akParents, Actor[] akChildren)
	If !akRelative
		Return ""
	ElseIf HasBase(akParents, akRelative)
		Return "parent"
	ElseIf HasBase(akChildren, akRelative)
		Return "child"
	EndIf
	string own = RaceId(akBase)
	string theirs = RaceId(akRelative)
	bool ownChild = StringUtil.Find(own, "Child") >= 0
	bool theirChild = StringUtil.Find(theirs, "Child") >= 0
	If theirChild && !ownChild
		Return "child"
	ElseIf ownChild && !theirChild
		Return "parent"
	EndIf
	bool ownElder = StringUtil.Find(own, "Elder") >= 0
	bool theirElder = StringUtil.Find(theirs, "Elder") >= 0
	If theirElder && !ownElder
		Return "parent"
	ElseIf ownElder && !theirElder
		Return "child"
	EndIf
	Return ""
EndFunction

string Function RaceId(ActorBase akBase)
	Race r = akBase.GetRace()
	If r
		Return MiscUtil.GetRaceEditorID(r)
	EndIf
	Return ""
EndFunction

bool Function HasBase(Actor[] akActors, ActorBase akBase)
	int i = 0
	While akActors && i < akActors.Length
		If akActors[i] && akActors[i].GetActorBase() == akBase
			Return true
		EndIf
		i += 1
	EndWhile
	Return false
EndFunction

; A place someone lives: a house, dwelling, farm, inn, castle or the player's house (Skyrim.esm location types).
bool Function IsHome(Location akPlace)
	Return IsHousehold(akPlace) || HasLocType(akPlace, 0x01CB87) || HasLocType(akPlace, 0x01CD57)  ; Inn, Castle
EndFunction

; A home small enough that everyone placed in it lives together: house, dwelling, farm or the player's house. Inns and
; castles are left out (guests, guards and the court are not a household).
bool Function IsHousehold(Location akPlace)
	Return HasLocType(akPlace, 0x01CB85) || HasLocType(akPlace, 0x0130DC) || HasLocType(akPlace, 0x018EF0) \
		|| HasLocType(akPlace, 0x0FC1A3)  ; House, Dwelling, Farm, PlayerHouse
EndFunction

bool Function HasLocType(Location akPlace, int aiKeyword)
	Keyword k = Game.GetFormFromFile(aiKeyword, "Skyrim.esm") as Keyword
	Return k && akPlace.HasKeyword(k)
EndFunction

; Other people loaded now whose editor location is the same home (po3's high-process actor list, usually a few
; dozen). People living there who are not loaded now are added on a later day, when they are.
int Function AddHousehold(string[] akKinds, string[] akBases, string[] akNames, int aiCount, Actor akNpc, Location akPlace)
	Keyword npcType = Game.GetFormFromFile(0x013794, "Skyrim.esm") as Keyword  ; ActorTypeNPC
	Actor[] loaded = PO3_SKSEFunctions.GetActorsByProcessingLevel(0)
	int n = aiCount
	int i = 0
	While loaded && i < loaded.Length
		Actor other = loaded[i]
		If other && other != akNpc && other != PlayerRef && other.HasKeyword(npcType) && other.GetEditorLocation() == akPlace
			n = AddTie(akKinds, akBases, akNames, n, "household", other.GetActorBase(), other.GetDisplayName())
		EndIf
		i += 1
	EndWhile
	Return n
EndFunction
