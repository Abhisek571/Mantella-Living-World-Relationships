Scriptname MRB_MarasCalls011 Hidden
{The M.A.R.A.S calls that changed in 2.x, as 0.11.1 declares them. Only called on 0.11.1.}

Function Promote(Actor akNpc, string asStatus) global
	MARAS.PromoteNPCToStatus(akNpc, asStatus)
EndFunction

Function SetScore(Actor akNpc, int aiScore) global
	MARAS.SetPermanentAffection(akNpc, aiScore)
EndFunction
