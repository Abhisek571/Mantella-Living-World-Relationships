Scriptname MRB_Text Hidden
{Shared wording helpers for the bridge scripts.}

; "a", "a, b", then " and c" for the last of several.
string Function ListAdd(string asList, string asItem, bool abLast) Global
	If asList == ""
		Return asItem
	ElseIf abLast
		Return asList + " and " + asItem
	EndIf
	Return asList + ", " + asItem
EndFunction

; OStim action types as habits ("what she does most"); unknown ones pass through.
string Function ActName(string asAction) Global
	If asAction == "vaginalsex"
		Return "vaginal sex"
	ElseIf asAction == "analsex"
		Return "anal sex"
	ElseIf asAction == "blowjob"
		Return "giving blowjobs"
	ElseIf asAction == "deepthroating"
		Return "deepthroating"
	ElseIf asAction == "cunnilingus" || asAction == "vulvaleating" || asAction == "vulvallicking"
		Return "oral on a woman"
	ElseIf asAction == "handjob"
		Return "handjobs"
	ElseIf asAction == "boobjob"
		Return "titjobs"
	ElseIf asAction == "footjob"
		Return "footjobs"
	ElseIf asAction == "thighjob"
		Return "thighjobs"
	ElseIf asAction == "rimjob" || asAction == "anallicking"
		Return "rimming"
	ElseIf asAction == "kissing" || asAction == "frenchkissing"
		Return "kissing"
	ElseIf asAction == "kissingneck"
		Return "kissing necks"
	ElseIf asAction == "cuddling" || asAction == "hugging" || asAction == "spooning"
		Return "cuddling"
	ElseIf asAction == "vaginalfingering"
		Return "fingering"
	ElseIf asAction == "analfingering"
		Return "anal fingering"
	ElseIf asAction == "tribbing"
		Return "tribbing"
	ElseIf asAction == "spanking"
		Return "spanking"
	ElseIf asAction == "choking"
		Return "choking"
	ElseIf asAction == "pullinghair"
		Return "hair pulling"
	ElseIf asAction == "suckingnipple" || asAction == "lickingnipple"
		Return "nipple play"
	ElseIf asAction == "gropingbreast" || asAction == "gropingbutt"
		Return "groping"
	ElseIf asAction == "femalemasturbation" || asAction == "malemasturbation" || asAction == "masturbation" || asAction == "fingerinmouthmasturbation"
		Return "masturbating"
	ElseIf asAction == "penilelicking" || asAction == "lickingpenis"
		Return "licking cock"
	ElseIf asAction == "testicularlicking" || asAction == "lickingtesticles"
		Return "licking balls"
	ElseIf asAction == "vulvalrubbing" || asAction == "rubbingclitoris"
		Return "rubbing pussy"
	ElseIf asAction == "anilingus"
		Return "rimming"
	ElseIf asAction == "buttjob"
		Return "buttjobs"
	ElseIf asAction == "vampirebite" || asAction == "vampirebiting"
		Return "biting"
	EndIf
	Return asAction
EndFunction
