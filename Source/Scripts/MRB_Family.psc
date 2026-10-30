Scriptname MRB_Family extends Quest
{Tells Mantella each conversation NPC's family and ties from the game's own
relationship records, through Relations Finder: parents, children, siblings,
cousins, spouse, partner, boss, workers and enemies. Runs only when the
Relations Finder SKSE plugin is loaded. Kept in its own script so the other
parts work without it.
With Mantella Living World - World installed, a relative who died during the
playthrough gets the day, close family who died in the last 30 days are
grieved, and close family the player struck in that time are mentioned (World
keeps both days on the relative: MLWW_DiedDay, MLWW_StruckDay).}

Actor Property PlayerRef Auto

int Property MAX_NAMES = 4 AutoReadOnly  ; per kind of tie
float Property RECENT_DAYS = 30.0 AutoReadOnly

; Filled by Tie for the NPC being described.
string grieving = ""
string struckKin = ""

Event OnInit()
	Register()
EndEvent

Function Register()
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
EndFunction

Event OnNpcAdded(Form akActor)
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef || SKSE.GetPluginVersion("RelationsFinder") < 0
		Return
	EndIf
	string ties = ""
	grieving = ""
	struckKin = ""
	ties = Tie(ties, "parent", TTRF_RelationsFinder.GetNpcRelationships(npc, "ParentChild", "primary"))
	ties = Tie(ties, "child", TTRF_RelationsFinder.GetNpcRelationships(npc, "ParentChild", "secondary"))
	ties = Tie(ties, "sibling", TTRF_RelationsFinder.GetNpcRelationships(npc, "Siblings"))
	ties = Tie(ties, "cousin", TTRF_RelationsFinder.GetNpcRelationships(npc, "Cousins"))
	ties = Tie(ties, "spouse", TTRF_RelationsFinder.GetNpcRelationships(npc, "Spouse"))
	ties = Tie(ties, "partner", TTRF_RelationsFinder.GetNpcRelationships(npc, "Courting"))
	ties = Tie(ties, "works for", TTRF_RelationsFinder.GetNpcRelationships(npc, "BossEmployee", "primary"))
	ties = Tie(ties, "employs", TTRF_RelationsFinder.GetNpcRelationships(npc, "BossEmployee", "secondary"))
	ties = Tie(ties, "enemy of", TTRF_RelationsFinder.GetNpcRelationships(npc, "", "any", -4, -3))
	ties = Tie(ties, "sworn enemy of", TTRF_RelationsFinder.GetNpcRelationships(npc, "", "any", -4, -4))
	If ties != ""
		AddMantellaEvent(npc.GetDisplayName() + "'s ties: " + ties + ".")
	EndIf
	If grieving != ""
		AddMantellaEvent(npc.GetDisplayName() + " is grieving: " + grieving + ".")
	EndIf
	If struckKin != ""
		AddMantellaEvent(npc.GetDisplayName() + " knows that " + PlayerRef.GetDisplayName() + " struck " + struckKin + ".")
	EndIf
EndEvent

bool Function IsCloseKind(string asKind)
	Return asKind == "parent" || asKind == "child" || asKind == "sibling" || asKind == "spouse" || asKind == "partner"
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

; Adds "kind A, B (dead)" to the list; the player is left out (Relationships' MARAS part covers them).
string Function Tie(string asTies, string asKind, Actor[] akActors)
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
						grieving = AddTo(grieving, "their " + asKind + " " + a.GetDisplayName() + ", who died " + DaysAgo(died, now))
					EndIf
				Else
					name += " (dead)"
				EndIf
			ElseIf close
				float struck = StorageUtil.GetFloatValue(a, "MLWW_StruckDay", -1.0)
				If struck >= 0.0 && now - struck <= RECENT_DAYS
					struckKin = AddTo(struckKin, "their " + asKind + " " + a.GetDisplayName() + " " + DaysAgo(struck, now))
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
	Return asTies + asKind + " " + names
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
