Scriptname MRB_MarasCalls2x Hidden
{The M.A.R.A.S calls that only exist or differ in 2.x. Only called when MRB_MARAS has found 2.x. Compiled by
tools/compile_maras2x.py against build/stubs/maras2x: the main build sees 0.11.1's MARAS.psc.}

Function Promote(Actor akNpc, string asStatus) global
	MARAS.PromoteNPCToStatus(akNpc, asStatus, true)
EndFunction

Function SetScore(Actor akNpc, int aiScore) global
	MARAS.SetPermanentAffection(akNpc, aiScore, true)
EndFunction

bool Function AvailableForEngagement(Actor akNpc) global
	Return MARAS.IsAvailableForStatus(akNpc, "engaged")
EndFunction

bool Function AlwaysSuccess() global
	Return MARAS.GetSettingBool("alwaysSuccessMarriage")
EndFunction

bool Function AsksBeforeCrisisDivorce() global
	Return MARAS.GetSettingBool("confirmDivorceDuringLowAffectionQuest") && MARAS.GetSettingBool("enableConfirmationModal")
EndFunction

Function CountTalk(Actor akNpc) global
	TTM_ServiceAffection.AddDialogueStartedAffection(akNpc)
EndFunction
