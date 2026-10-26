Scriptname MRB_MARAS extends Quest
{Tells Mantella each conversation NPC's M.A.R.A.S relationship status with the
player (candidate, engaged, married, divorced or jilted). When the player
talks about their marriages, the "Learn the Player's Spouses" action tells the
NPCs who the player is married and engaged to. Kept in its own script so the
Romantasy half still works without M.A.R.A.S installed.}

Actor Property PlayerRef Auto

string Property ACTION_SPOUSES = "mantella_maras_spouses" AutoReadOnly

Event OnInit()
	Register()
EndEvent

Function Register()
	RegisterForModEvent("MantellaConversation_NPC_Added", "OnNpcAdded")
	RegisterForModEvent("MantellaConversation_Action_" + ACTION_SPOUSES, "OnSpousesLegacy")
	RegisterForModEvent("MantellaConversation_Advanced_Action_" + ACTION_SPOUSES, "OnSpousesAdvanced")
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
	string married = NameList(MARAS.GetNPCsByStatus("married"))
	string engaged = NameList(MARAS.GetNPCsByStatus("engaged"))
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

; "A", "A and B", "A, B and C". Skips dead or missing actors.
string Function NameList(Actor[] akActors)
	string[] names = new string[20]
	int count = 0
	int i = 0
	While i < akActors.Length && count < names.Length
		If akActors[i] && !akActors[i].IsDead()
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

Event OnNpcAdded(Form akActor)
	; Saves made before the spouses action existed only registered this event.
	Register()
	Actor npc = akActor as Actor
	If !npc || npc == PlayerRef
		Return
	EndIf
	string line = StatusLine(npc.GetDisplayName(), MARAS.GetNpcStatusName(npc))
	If line != ""
		AddMantellaEvent(line)
	EndIf
EndEvent

string Function StatusLine(string asName, string asStatus)
	If asStatus == "Married"
		Return asName + " is married to the player."
	ElseIf asStatus == "Engaged"
		Return asName + " is engaged to the player."
	ElseIf asStatus == "Candidate"
		Return "The player has shown romantic interest in " + asName + ", but they are not engaged."
	ElseIf asStatus == "Divorced"
		Return asName + " and the player were married, but are now divorced."
	ElseIf asStatus == "Jilted"
		Return asName + " was engaged to the player, but the engagement fell apart."
	EndIf
	Return ""
EndFunction

Function AddMantellaEvent(string asText)
	int handle = ModEvent.Create("MantellaAddEvent")
	If handle
		ModEvent.PushString(handle, asText)
		ModEvent.Send(handle)
	EndIf
EndFunction
