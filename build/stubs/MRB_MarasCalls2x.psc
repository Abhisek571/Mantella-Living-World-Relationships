Scriptname MRB_MarasCalls2x Hidden
; Compile stub for the main build: Source/Scripts2x has the real script, compiled by tools/compile_maras2x.py.
Function Promote(Actor akNpc, string asStatus) global
EndFunction
Function SetScore(Actor akNpc, int aiScore) global
EndFunction
bool Function AvailableForEngagement(Actor akNpc) global
	Return false
EndFunction
bool Function AlwaysSuccess() global
	Return false
EndFunction
bool Function AsksBeforeCrisisDivorce() global
	Return false
EndFunction
Function CountTalk(Actor akNpc) global
EndFunction
