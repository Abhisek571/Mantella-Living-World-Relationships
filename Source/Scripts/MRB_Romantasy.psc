Scriptname MRB_Romantasy extends Quest
{Tells Mantella each conversation NPC's Romantasy bond tier, and awards
Romantasy points to bonded NPCs after a Mantella conversation that lasted long
enough. Kept in its own script so the M.A.R.A.S half still works without
Romantasy installed. It sits on its own quest: SKSE keeps one mod event
registration per object, so two scripts on one quest cannot both receive the
same Mantella event.}

Actor Property PlayerRef Auto
GlobalVariable Property MRB_PointsPerTalk Auto
GlobalVariable Property MRB_MinTalkSeconds Auto

Actor[] talkers
float[] joinedAt

Event OnInit()
	ResetTalkers()
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
	RegisterForModEvent("MantellaConversation_NPC_Removed", "OnNpcRemoved")
	RegisterForModEvent("MantellaConversation_Ended", "OnConversationEnded")
EndEvent

Event OnNpcAdded(Form akActor)
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef || Romantasy.GetLevel(npc) <= 0
		Return
	EndIf
	AddMantellaEvent(npc.GetDisplayName() + "'s bond with the player: " + Romantasy.GetLevelName(npc) + " (" + Romantasy.GetPoints(npc) + " points; tiers are Stranger, Acquaintance, Friend, Confidant, Lover, Spouse).")
	Track(npc)
EndEvent

Event OnNpcRemoved(Form akActor)
	int i = talkers.Find(akActor as Actor)
	If i >= 0
		Reward(i)
	EndIf
EndEvent

; Mod events arrive in no fixed order, so nothing resets on conversation start:
; an NPC-added event could be handled first and be wiped. Ending clears every
; slot instead.
Event OnConversationEnded()
	int i = 0
	While i < talkers.Length
		Reward(i)
		i += 1
	EndWhile
EndEvent

Function ResetTalkers()
	talkers = new Actor[20]
	joinedAt = new float[20]
EndFunction

Function Track(Actor akActor)
	If !talkers
		ResetTalkers()
	EndIf
	If talkers.Find(akActor) >= 0
		Return
	EndIf
	int i = talkers.Find(None)
	If i >= 0
		talkers[i] = akActor
		joinedAt[i] = Utility.GetCurrentRealTime()
	EndIf
EndFunction

; Awards the points once and frees the slot. Real time, so pausing in menus
; still counts as talking.
Function Reward(int aiSlot)
	Actor npc = talkers[aiSlot]
	talkers[aiSlot] = None
	If !npc
		Return
	EndIf
	int points = MRB_PointsPerTalk.GetValueInt()
	If points != 0 && Utility.GetCurrentRealTime() - joinedAt[aiSlot] >= MRB_MinTalkSeconds.GetValue()
		Romantasy.ModifyPoints(npc, points, "Talked with you")
	EndIf
EndFunction

Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
EndFunction
