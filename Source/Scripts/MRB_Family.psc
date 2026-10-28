Scriptname MRB_Family extends Quest
{Tells Mantella each conversation NPC's family and ties from the game's own
relationship records, through Relations Finder: parents, children, siblings,
cousins, spouse, partner, boss, workers and enemies. Runs only when the
Relations Finder SKSE plugin is loaded. Kept in its own script so the other
parts work without it.}

Actor Property PlayerRef Auto

int Property MAX_NAMES = 4 AutoReadOnly  ; per kind of tie

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
EndEvent

; Adds "kind A, B (dead)" to the list; the player is left out (Relationships' MARAS part covers them).
string Function Tie(string asTies, string asKind, Actor[] akActors)
	string names = ""
	int count = 0
	int i = 0
	While akActors && i < akActors.Length && count < MAX_NAMES
		Actor a = akActors[i]
		If a && a != PlayerRef
			string name = a.GetDisplayName()
			If a.IsDead()
				name += " (dead)"
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

Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
EndFunction
