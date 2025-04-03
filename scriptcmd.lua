---------------------------------------------------------------------
--Theater Mode
--Title = name within a cnvrs-text file. Event = internal ID of the event
--Exit does not need to be called because the "theater" is not in a seq script
--TODO: 
---------------------------------------------------------------------
islandName = "" -- Set within the Lua sequence scripts for the given island. Not included in this repo.
timestop = false -- Tracks whether time should advance naturally
timeTable = {} --Stores the time values when timestop is enabled
local cutsceneIndex = 1 -- Used for table page traversal
local currentPage = 1
local currentTime = {} --Stores time values. Set to timeTable when timestop is enabled.
local customTime = {} --Used for the customizable time preset
local ReferenceTable = {} --Gets set to one of the cutscene tables so that everything can run from 1 function
local animIndex = "" --Anim type for the animation viewer (Object/Traversal/Ability/Misc)
local animSubIndex
local lastAnim = ""
local anime = ""
local advSaveAnim = false
local advSaveMenu = false
local storedAnim = {}
local storedDuration = {}
local storedIndex = 1
local storedPage = 1

local currentCharacter = "Sonic"
local charTable = {"Sonic", "Amy", "Knuckles", "Tails"}
function ResetParams()
  cutsceneIndex = 1
  currentPage = 1
end
function LoadMenu()
  if anime == "" then
    anime = GetCurrentAnimationName()
  end
  if anime ~= GetCurrentAnimationName() then
	if GetCurrentAnimationName() ~= "STAND" then
	  lastAnim = anime
	  anime = GetCurrentAnimationName()
	end
  end
  if advSaveAnim then
    if anime:match("(AVOID)_%a*_(AIR)") and storedAnim[1] ~= nil then
	  print(storedAnim, storedDuration)
	  AnimationPlay(storedAnim, storedDuration)
	  anime = lastAnim
	end
  end
  if lastAnim == "SQUAT_LOOP" then
	if anime:find("COMBO_ACCELE_") or anime:find("COMBO_FINISH") or anime:find("IDLE01") then
	  lastAnim = ""
	  anime = ""
	  CutTypeSelect()
	elseif anime:find("SIDESTEP_") then
	  if anime == "SIDESTEP_LEFT" then
		if timestop then
		  UpdateTime(timeTable.Hour, timeTable.Minute-30)
		else
		  UpdateTime(GetTime().Hour, GetTime().Minute-30)
		end
	  elseif anime == "SIDESTEP_RIGHT" then
		if timestop then
		  UpdateTime(timeTable.Hour, timeTable.Minute+30)
		else
		  UpdateTime(GetTime().Hour, GetTime().Minute+30)
		end
	  end
	  lastAnim = ""
	  anime = ""
	elseif anime:find("PARRY") then
	  lastAnim = ""
	  anime = ""
	  MinigameMenu()
	end
  end
end
function MinigameMenu()
  if MinigameTable[islandName] == nil then
    return
  end
  local Entry1 = MinigameTable[islandName][cutsceneIndex] or {}
  local Entry2 = MinigameTable[islandName][cutsceneIndex+1] or {}
  local Entry3 = MinigameTable[islandName][cutsceneIndex+2] or {}
  local EntryTable = {Entry1.title, Entry2.title, Entry3.title, "theater_exit"}
  local refEntry = {}
  ShowSelectBox("theater_minigame", table.unpack(EntryTable))
  local choice = GetSelectResult()
  if Entry2.title == nil then
    if choice == 1 then choice = 3 end
  elseif Entry3.title == nil then
    if choice == 2 then choice = 3 end
  end
  if choice == 0 then
    refEntry = Entry1
  elseif choice == 1 then
    refEntry = Entry2
  elseif choice == 2 then
    refEntry = Entry3
  elseif choice == 3 then
    return
  end
  if refEntry.warning then
	ShowYesNoWindowUI("theater_animation_warning00", "theater_minigame_unfinished")
	if GetSelectResult() == 1 then
	  return
	end
  end
  if islandName ~= "Chaos" or choice ~= 2 then
    SetMenuDisabledMinigameQuest("AutoSave")
    StartMinigameQuest(refEntry.event)
    StartWaitMinigameQuest()
	while not((IsPlayingQuest()
      ) == 0) do
      coroutine.yield(0)
      end
    ResetMenuDisabledMinigameQuest()
	ReleaseHoldPlayer()
  elseif islandName == "Chaos" and choice == 2 then
    LoadPinball()
  end
end
function LoadPinball()
  KillPinballObjects()
  SpawnPinballObjects()
  while not((GetPinballStatus('isready')) == 1) do
    coroutine.yield(0)
  end
  NotifyAction('CameraActivator00','on')
  StartPinball()
  while not((GetPinballStatus('playing')) == 0) do
    coroutine.yield(0)
  end
  ResetPinball()
  NotifyAction('CameraActivator00','off')
  KillPinballObjects()
end
---------------------------------------
function ReloadMenu(lastFunction)
  if advSaveMenu then
    storedIndex = cutsceneIndex
    storedPage = currentPage
    lastFunction()
  end
end
function CutTypeAnimation()
  local Entry1 = AnimationTable[animIndex][cutsceneIndex]
  local Entry2 = AnimationTable[animIndex][cutsceneIndex + 1] or {}
  local Entry3 = AnimationTable[animIndex][cutsceneIndex + 2] or {}
  local EntryPage = AnimationTable[animIndex].Page
  local entryTable = { Entry1.title, Entry2.title, Entry3.title, "theater_page_reset", "theater_exit" }
  local refEntry = {}
  local stitched = ""
  ShowSelectBox("theater_animation_type", table.unpack(entryTable))
  local choice = GetSelectResult()
  if Entry2.title == nil then 
    if choice == 1 then --If you chose "more options", run the code to pull up the next page.
	  choice = 3
	elseif choice == 2 then --If you chose "exit", quit.
	  choice = 4
	end
  elseif Entry3.title == nil then
    if choice == 2 then
	  choice = 3
	elseif choice == 3 then
	  choice = 4
	end
  end
  if choice == 0 then
	refEntry = Entry1
  elseif choice == 1 then
	refEntry = Entry2
  elseif choice == 2 then
	refEntry = Entry3
  elseif choice == 3 then --Change page
	currentPage = currentPage + 1
	cutsceneIndex = math.min(#AnimationTable[animIndex], cutsceneIndex + 3)
	if currentPage > EntryPage.pageCount then --Passed the last page. Reset to page 1
	  ResetParams()
	end
	return CutTypeAnimation()
  elseif choice == 4 then
    ResetParams()
  end
  if choice <= 2 then
    if refEntry.dirs then
	  AnimDirSelect(refEntry)
    elseif refEntry.subcat then
      AnimSubCatSelect(refEntry)
    elseif refEntry.append then
	  stitched = AnimStitch(refEntry)
	  AnimationPlay(stitched, refEntry.duration)
    else
	  AnimationPlay(refEntry.event, refEntry.duration)
    end
	ReloadMenu(CutTypeAnimation)
  end
end
function CutTypeSelect()
  local Entry1, Entry2, Entry3 = BasicOptions[cutsceneIndex], BasicOptions[cutsceneIndex + 1] or {}, BasicOptions[cutsceneIndex + 2] or {}
  local EntryPage = BasicOptions.Page
  local EntryTable = { Entry1.title, Entry2.title, Entry3.title, "theater_page", "theater_exit" }
  ShowSelectBoxNoWaitVoice("theater_type_select", table.unpack(EntryTable))
  local choice = GetSelectResult()
  if Entry2.title == nil then
    if choice == 1 then
	  choice = 3
	elseif choice == 2 then
	  choice = 4
	end
  elseif Entry3.title == nil then
    if choice == 2 then
	  choice = 3
	elseif choice == 3 then
	  choice = 4
	end
  end
  if choice ~= 3 then --Ensures all menu options are correct when making a selection.
    ResetParams()
  end
  if choice == 0 then
    Entry1.func()
  elseif choice == 1 then
    Entry2.func()
  elseif choice == 2 then
    Entry3.func()
  elseif choice == 3 then
    currentPage = currentPage + 1
	cutsceneIndex = math.min(#BasicOptions, cutsceneIndex + 3)
    if currentPage > EntryPage.pageCount then
	  ResetParams()
	end
	CutTypeSelect()
  end
end
function AdvSelect()
  local Entry1, Entry2, Entry3 = AdvancedOptions[cutsceneIndex], AdvancedOptions[cutsceneIndex + 1] or {}, AdvancedOptions[cutsceneIndex + 2] or {}
  local EntryPage = AdvancedOptions.Page
  local EntryTable = {}
  local isSinglePage = false
  if EntryPage.pageCount > 1 then
    EntryTable = { Entry1.header, Entry2.header, Entry3.header, "theater_page", "theater_exit" }
  else
    EntryTable = { Entry1.header, Entry2.header, Entry3.header, "theater_exit" } 
	isSinglePage = true
  end
  local refEntry = {}
  ShowSelectBox("theater_advanced_select", table.unpack(EntryTable))
  local choice = GetSelectResult()
  if not isSinglePage then
    if Entry2.header == nil then
      if choice == 1 then
	    choice = 3
	  elseif choice == 2 then
	    choice = 4
	  end
    elseif Entry3.header == nil then
      if choice == 2 then
	    choice = 3
	  elseif choice == 3 then
	    choice = 4
	  end
    end
  else
    if Entry2.header == nil then --If only 1 option, can only be 0 or 1. 1 = 4 (exit)
      if choice == 1 then
	    choice = 4
	  end
    elseif Entry3.header == nil then --If only 2 options, can only be 0, 1 or 2. 2 = 4 (exit)
      if choice == 2 then
	    choice = 4
	  end
	else --If all 3, can be 0, 1, 2 or 3. 3 = 4 (exit)
	  if choice == 3 then
	    choice = 4
	  end
    end
  end
  if choice == 0 then
    refEntry = Entry1
  elseif choice == 1 then
    refEntry = Entry2
  elseif choice == 2 then
    refEntry = Entry3
  elseif choice == 3 then
    currentPage = currentPage + 1
	cutsceneIndex = math.min(#AdvancedOptions, cutsceneIndex + 3)
    if currentPage > EntryPage.pageCount then
	  ResetParams()
	end
	return AdvSelect()
  end
  if choice < 3 then
    ShowYesNoWindowUI(refEntry.header, refEntry.body)
    if GetSelectResult() == 1 then
      return
    end
	HoldPlayer()
	if refEntry.event == "SaveAnim" then
	  if not advSaveAnim then
	    advSaveAnim = true
		ShowTalkCaption("adv_AnimOn")
	  else
	    advSaveAnim = false
		ShowTalkCaption("adv_AnimOff")
	  end
	elseif refEntry.event == "SaveMenuPos" then
	  if not advSaveMenu then
	    advSaveMenu = true
		ShowTalkCaption("adv_SaveOn")
	  else
	    advSaveMenu = false
		ShowTalkCaption("adv_SaveOff")
	  end
	end
	ReleaseHoldPlayer()
  end
end
function CharSwap()
  ShowSelectBox("ko9000_171", "ko9000_172", "ko9000_173", "ko9000_174", "ko9000_175")
  local Select = GetSelectResult() + 1
  currentCharacter = charTable[Select]
  ChangePlayerCharacter(currentCharacter)
end
function AnimTypeSelect()
  ShowSelectBox("theater_type", "theater_animation_object", "theater_animation_ability", "theater_animation_traversal", "theater_animation_misc", "theater_animation_all")
  local choice = GetSelectResult()
  if choice == 0 then
    animIndex = "Object"
  elseif choice == 1 then
    animIndex = "Ability"
  elseif choice == 2 then
    animIndex = "Traversal"
  elseif choice == 3 then
    animIndex = "Misc"
  elseif choice == 4 then
    PlayAnimationAll()
	return
  end
  table.sort(AnimationTable[animIndex], function(a,b) return (a.event < b.event) end)
  CutTypeAnimation()
end
function PlayAnimationAll()
  ShowYesNoWindowUI("theater_animation_warning00", "theater_animation_warning05")
  if GetSelectResult() == 1 then
    return
  end
  AnimationPlay(PlayAllTable)
end
function AnimSubCatSelect(animTable)
  local nameTable = {} --Stores all button names
  local eventTable = {} --Animation to play
  local buttonTable = {} --Button names to display
  local counter = 1
  local loopCount = 1
  local playEV = 1
  local duration = animTable.duration
  for i = 1, #animTable.subcat do
    nameTable[i] = string.lower("theater_animation" .. animTable.subcat[i])
	if animTable.appFirst then
	  eventTable[i] = animTable.subcat[i] .. animTable.event --Create a list of events, loading the subcat before the base ev
	else
	  eventTable[i] = animTable.event .. animTable.subcat[i] --Create a list of events, combining the base ev with the subcat
	end
  end
  if animTable.append then
    for i = 1, #animTable.subcat do
	  if animTable.append[i] ~= nil then
	    eventTable[i] = AnimStitch{event = eventTable[i], append = animTable.append[i]}
		if animTable.append[i].subIndex then
		  eventTable[i].subIndex = animTable.append[i].subIndex --Makes this entry bring up a new page group
		end
	  end
	end
  end
  while true do
    buttonTable = {}
    for i = counter, #nameTable do
      table.insert(buttonTable, nameTable[i])
	  counter = counter + 1
	  if counter%4 == 0 then
	    table.insert(buttonTable, nameTable[counter])
		counter = counter + 1
	    break
	  end
    end
	table.insert(buttonTable, "theater_page")
	if animTable.neutral and loopCount == 1 then
	  print("PRE: " .. buttonTable[1])
	  buttonTable[1] = string.lower("theater_animation_" .. animTable.event)
	  print(buttonTable[1])
	end
	ShowSelectBox("theater_animation_direction", table.unpack(buttonTable))
	local choice = GetSelectResult()
	if buttonTable[2] == "theater_page" then
	  if choice == 1 then choice = 4 end
	elseif buttonTable[3] == "theater_page" then
	  if choice == 2 then choice = 4 end
	elseif buttonTable[4] == "theater_page" then
	  if choice == 3 then choice = 4 end
	end
	if choice <= 3 then
	  local refPlay = eventTable[playEV + choice]
	  if refPlay.subIndex then
	    AnimSubCatSelect(AnimationSubTable[animTable.event][refPlay.subIndex]) --The chosen anim has directional variants. Open a new page group.
	  else
	    AnimationPlay(refPlay, duration)
	  end
	  return
	end
	playEV = playEV + 4
	loopCount = loopCount + 1
	if loopCount > animTable.subcat.count then
	  loopCount = 1
	  playEV = 1
	  counter = 1
	end
	if playEV > #eventTable then
	  playEV = #eventTable - 4
	end
  end 
end
function AnimDirSelect(animTable)
  local dirF, dirL, dirR, dirB = table.unpack(animTable.dirs) --Names are slightly misleading. E.g. can accommodate storing Left in dirF
  local baseAnim = animTable.event
  local add = animTable.append --Names to append to the main animation
  local dur = animTable.duration
  local dirTable = { dirF, dirL, dirR, dirB } --Button name directional variants
  local dirAnim = ""
  local dirBaseAnim = ""
  for i = 1, #dirTable do
    if dirTable[i] ~= nil then
	  dirTable[i] = string.lower("theater_animation" .. dirTable[i])
	else 
	  break 
	end
  end
  if animTable.neutral then
    ShowSelectBox("theater_animation_direction", "theater_animation_reg", table.unpack(dirTable))
  else
    ShowSelectBox("theater_animation_direction", table.unpack(dirTable))
  end
  local choice = GetSelectResult()
  if not animTable.neutral then
    choice = choice + 1
  end
  if not animTable.appFirst then
    if choice == 1 then --front
      dirBaseAnim = baseAnim .. dirF
    elseif choice == 2 then --left
      dirBaseAnim = baseAnim .. dirL
    elseif choice == 3 then --right
      dirBaseAnim = baseAnim .. dirR
    elseif choice == 4 then --back
      dirBaseAnim = baseAnim .. dirB
    end
	if add ~= nil then
      if choice == 0 then
        dirAnim = AnimStitch{event = baseAnim, append = add}
      else
        dirAnim = AnimStitch{event = dirBaseAnim, append = add}
      end
	else
	  dirAnim = dirBaseAnim
	end
  else
    dirAnim = AnimStitch{event = baseAnim, append = add}
	if choice == 1 then
	  for i = 1, #dirAnim do
	    dirAnim[i] = dirAnim[i] .. dirF
	  end
	elseif choice == 2 then
	  for i = 1, #dirAnim do
	    dirAnim[i] = dirAnim[i] .. dirL
	  end
	elseif choice == 3 then
	  for i = 1, #dirAnim do
	    dirAnim[i] = dirAnim[i] .. dirR
	  end
	elseif choice == 4 then
	  for i = 1, #dirAnim do
	    dirAnim[i] = dirAnim[i] .. dirB
	  end
	end
  end
  AnimationPlay(dirAnim, dur)
end
function AnimStitch(animTable)
  local baseAnim, add = animTable.event, animTable.append
  local fullAnim = {}
  for i = 1, #add do
	table.insert(fullAnim, baseAnim .. add[i])
  end
  return fullAnim
end
function AnimationPlay(anim, duration, subcat)
  local parts = 0
  local subTable = {}
  if not duration then
    duration = 1.5
  end
  if type(anim) == "table" then
    parts = #anim
	for i = 1, parts do
	  subTable[i] = anim[i]
	end
  end
  HoldPlayer()
  if parts ~= 0 then
    for i = 1, parts do
	  if subTable[i] ~= nil then
	    print("PLAYING ANIM: " .. subTable[i])
	    if type(duration) == "table" then
	      ChangePlayerAnimInHold(subTable[i], duration[i])
		  WaitTime(duration[i])
	    else
	      ChangePlayerAnimInHold(subTable[i], duration)
		  WaitTime(duration)
	    end
	  else break end
	end
  else
    print("PLAYING ANIM: " .. anim)
    ChangePlayerAnimInHold(anim, duration)
    WaitTime(duration)
  end
  if advSaveAnim then
	if type(anim) == "table" then
	  storedAnim = anim
	else
	  storedAnim[1] = anim
	end
	storedDuration = duration
  end
  ReleaseHoldPlayer()
  if not advSaveMenu then
    ResetParams()
  end
end
function CutTypeTime()
  if not timestop then
    ShowSelectBox("theater_time_type", "theater_time_preset", "theater_time_manual", "theater_custom", "theater_time_stop", "theater_exit")
  else
    ShowSelectBox("theater_time_type", "theater_time_preset", "theater_time_manual", "theater_custom", "theater_time_start", "theater_exit")
  end
  local choice = GetSelectResult()
  if choice == 0 then
    CutTimePreset()
  elseif choice == 1 then
    CutTimeManual()
  elseif choice == 2 then
    CutTimeCustom()
  elseif choice == 3 then
    if timestop then
	  SetTimePause(false)
	  timestop = false
	else
	  timeTable = GetTime()
	  SetTimePause(true)
	  timestop = true
	end
  end
end
function CutTimeCustom()
  ShowSelectBox("theater_custom_select", "theater_custom_load", "theater_custom_save", "theater_exit")
  local choice = GetSelectResult()
  if choice == 0 then
    if customTime.Hour then
	  UpdateTime(customTime.Hour, customTime.Minute)
	else
	  HoldPlayer()
	  ShowTalkCaption("theater_custom_invalid")
	  ReleaseHoldPlayer()
	end
  elseif choice == 1 then
    if timestop then
	  SetTimePause(false)
	  customTime.Hour = timeTable.Hour
	  customTime.Minute = timeTable.Minute
	  SetTimePause(true)
	else
	  customTime = GetTime()
	end
  end
end
function UpdateTime(hour, minute, second)
  if timestop then
    if minute then
      timeTable.Minute = minute
	  if timeTable.Minute >= 60 then
	    minute = minute - 60
        timeTable.Minute = timeTable.Minute - 60
	    timeTable.Hour = timeTable.Hour + 1
	    hour = hour + 1
	  elseif timeTable.Minute < 0 then
	    minute = minute * -1
		timeTable.Minute = timeTable.Minute * -1
		timeTable.Hour = timeTable.Hour - 1 
		hour = hour - 1
      end
    end
    timeTable.Hour = hour
	if timeTable.Hour >= 24 then
      timeTable.Hour = timeTable.Hour - 24
	  hour = hour - 24
	elseif timeTable.Hour < 0 then
	  timeTable.Hour = timeTable.Hour + 24
	  hour = hour + 24
    end
    if second then
      timeTable.Second = second
    end
  else
    if minute then
      if minute >= 60 then
	    hour = hour + 1
	    minute = minute - 60
	  elseif minute < 0 then
	    hour = hour - 1
	    minute = minute * -1
	  end
    end
	if hour < 0 then
	  hour = hour + 24
	end
  end
  if hour <= 3 or hour >= 20 then
    ChangeWeather(0, "Sunny")
  end
  if not minute then
    SetTime(hour)
  else
    SetTime(hour, minute)
  end
  if minute then
    print("NEW TIME: " .. hour .. ":" .. minute)
  else
    print("NEW TIME: " .. hour)
  end
end
function ErrorHandle(erType)
  if erType == "Weather" then
    if timestop then
	  if timeTable.Hour <= 3 or timeTable.Hour >= 20 then
        ShowYesNoWindowUI("theater_weather_invalid00", "theater_weather_invalid05")
		if GetSelectResult() == 0 then
		  return false
		else
          return true
		end
	  end
	else
	  if GetTime().Hour <= 3 or GetTime().Hour >= 20 then
        ShowYesNoWindowUI("theater_weather_invalid00", "theater_weather_invalid05")
		if GetSelectResult() == 0 then
		  return false
		else
          return true
		end
      end
	end
  end
  return false
end
function CutTimePreset()
  ShowSelectBox("theater_time_type2", "theater_time_dawn", "theater_time_day", "theater_time_evening", "theater_time_night", "theater_exit")
  local choice = GetSelectResult()
  if choice == 0 then
    UpdateTime(5, 0)
	print("TIME SET MORNING: " .. GetTime().Hour .. ":" .. GetTime().Minute)
  elseif choice == 1 then
    UpdateTime(12, 0)
	print("TIME SET DAY: " .. GetTime().Hour .. ":" .. GetTime().Minute)
  elseif choice == 2 then
    UpdateTime(20, 15)
	print("TIME SET DUSK: " .. GetTime().Hour .. ":" .. GetTime().Minute)
  elseif choice == 3 then
    UpdateTime(1, 0)
	print("TIME SET NIGHT: " .. GetTime().Hour .. ":" .. GetTime().Minute)
  end
end
function CutTimeManual()
  ShowSelectBox("theater_time_type3", "theater_time_adv30", "theater_time_adv1", "theater_time_adv5", "theater_time_adv12", "theater_exit")
  local choice = GetSelectResult()
  if timestop then 
    currentTime = timeTable
  else
    currentTime = GetTime()
  end
  if choice == 0 then
    UpdateTime(currentTime.Hour, currentTime.Minute + 30)
	--print("ADVANCED BY 30 MIN. NEW TIME: " .. currentTime.Hour .. ":" .. currentTime.Minute)
  elseif choice == 1 then
    UpdateTime(currentTime.Hour + 1)
	--print("ADVANCED BY 1 HOUR. NEW TIME: " .. currentTime.Hour .. ":" .. currentTime.Minute)
  elseif choice == 2 then
    UpdateTime(currentTime.Hour + 5)
	--print("ADVANCED BY 5 HOURS. NEW TIME: " .. currentTime.Hour .. ":" .. currentTime.Minute)
  elseif choice == 3 then
    UpdateTime(currentTime.Hour + 12)
	--print("ADVANCED BY 12 HOURS. NEW TIME: " .. currentTime.Hour .. ":" .. currentTime.Minute)
  end
  if advSaveMenu and choice ~= 4 then
    ReloadMenu(CutTimeManual)
  end
end

function CutTypeWeather()
  if islandName ~= "Ares" then --Locks Sandstorm to Ares
    ShowSelectBox("theater_weather_type", "theater_weather_sunny", "theater_weather_cloudy", "theater_weather_rainy", "theater_exit")
  else
    ShowSelectBox("theater_weather_type", "theater_weather_sunny", "theater_weather_cloudy", "theater_weather_rainy", "theater_weather_sandstorm", "theater_exit")
  end
  local choice = GetSelectResult()
  if choice == 0 then
    ChangeWeather(0, "Sunny")
  elseif choice == 1 then
    if not ErrorHandle("Weather") then
      ChangeWeather(0, "Cloudy")
	end
  elseif choice == 2 then
    if not ErrorHandle("Weather") then
      ChangeWeather(0, "Rainy")
	end
  elseif choice == 3 then
    if islandName == "Ares" then
	  ChangeWeather(0, "SandStorm")
	end --There's an implicit "else return" here if you're not on Ares.
  end
end
---------------------------------------
function CutTypeSelectCutscene()
  if islandName ~= "Rhea" then
    ShowSelectBox("theater_type", "theater_main", "theater_side", "theater_boss", "theater_misc", "theater_exit")
  else
    ShowSelectBox("theater_type", "theater_main", "theater_misc", "theater_exit")
  end
  local choice = GetSelectResult()
  if choice == 0 then
	ReferenceTable = CutsceneTable
  elseif choice == 1 then
    if islandName == "Rhea" then
	  ReferenceTable = CutsceneTableMisc
	else
	  ReferenceTable = CutsceneTableSide
	end
  elseif choice == 2 then
    if islandName == "Rhea" then
	  return
	else
	  ReferenceTable = CutsceneTableBoss
	end
  elseif choice == 3 then
	ReferenceTable = CutsceneTableMisc
  elseif choice == 4 then
    return
  end
  CutsceneSelect()
end
function CutsceneSelect()
  local Entry1 = ReferenceTable[islandName][cutsceneIndex]
  local Entry2 = ReferenceTable[islandName][cutsceneIndex + 1] or {}
  local Entry3 = ReferenceTable[islandName][cutsceneIndex + 2] or {}
  local EntryTable = { Entry1.title, Entry2.title, Entry3.title, "theater_page_reset", "theater_exit" }
  local EntryPage = ReferenceTable[islandName].Page
  local refPlay = {}
  ShowSelectBox("theater_select", table.unpack(EntryTable))
  local choice = GetSelectResult()
  if Entry2.title == nil then 
    if choice == 1 then --If you chose "more options", run the code to pull up the next page.
	  choice = 3
	elseif choice == 2 then --If you chose "exit", quite.
	  choice = 4
	end
  elseif Entry3.title == nil then
    if choice == 2 then
	  choice = 3
	elseif choice == 3 then
	  choice = 4
	end
  end
  if choice == 0 then
    refPlay = Entry1
  elseif choice == 1 then
    refPlay = Entry2
  elseif choice == 2 then
    refPlay = Entry3
  elseif choice == 3 then
    currentPage = currentPage + 1
	cutsceneIndex = math.min(#ReferenceTable[islandName], cutsceneIndex + 3)
    if currentPage > EntryPage.pageCount then
	  ResetParams()
	end
	return CutsceneSelect()
  elseif choice == 4 then
    ResetParams()
  end
  if choice < 3 then
    if refPlay.hide then
	  if type(refPlay.hide) == "table" then
	    for i = 1, #refPlay.hide do
		  HideObjectInEvent(refPlay.hide[i])
		end
	  else
	    HideObjectInEvent(refPlay.hide)
	  end
	end
    PlayDiEvent(refPlay.event)
	while not((IsPlayingDiEventAll()) == 0) do
    coroutine.yield(0)
    end
	if advSaveMenu then
	  return ReloadMenu(CutsceneSelect)
	else
	  ResetParams()
    end
  end
end
--pageCount is the number of pages for an island. 3 cutscenes display per page.
--pageRemaining is how many options should appear on the last page.
BasicOptions = {
  [1] = { title = "theater_type_cutscenes", func = CutTypeSelectCutscene },
  [2] = { title = "theater_time", func = CutTypeTime },
  [3] = { title = "theater_weather", func = CutTypeWeather },
  [4] = { title = "theater_animation", func = AnimTypeSelect },
  [5] = { title = "theater_advanced", func =  AdvSelect},
  [6] = { title = "ko9000_171", func = CharSwap },
  Page = { pageCount = 2, pageRemaining = 0 }
}
AdvancedOptions = {
  [1] = { header = "adv_SaveAnim", body = "adv_SaveAnim10", event = "SaveAnim" },
  [2] = { header = "adv_SaveMenu", body = "adv_SaveMenu10", event = "SaveMenuPos" },
  Page = { pageCount = 1, pageRemaining = 2 }
}
CutsceneTable = {
  Kronos = {
    [1] = { title = "theater_select_opening1", event = "ev0010" }, --Opening (Eggman)
    [2] = { title = "theater_select_opening2", event = "ev0020" }, --Opening (Sonic and co.)
    [3] = { title = "theater_select_1010", event = "ev1010"}, --Sonic awakens
    [4] = { title = "theater_select_1020", event = "ev1020" }, --Amy trapped
    [5] = { title = "theater_select_1030", event = "ev1030" }, --Amy freed
    [6] = { title = "theater_select_9010", event = "ev9010" }, --Eggman trapped
    [7] = { title = "theater_select_1040", event = "ev1040" }, --Incident intro
    [8] = { title = "theater_select_1050", event = "ev1050" }, --Incident end
    [9] = { title = "theater_select_1060", event = "ev1060" }, --Lover kodama intro
    [10] = { title = "theater_select_1070", event = "ev1070" }, --Mother kodama seeks child
    [11] = { title = "theater_select_1080", event = "ev1080" }, --Mother finds child, laid to rest
    [12] = { title = "theater_select_1090", event = "ev1090" }, --Sonic annoyed
    [13] = { title = "theater_select_1100", event = "ev1100" }, --Pre-mowing minigame
	[14] = { title = "theater_select_1110", event = "ev1110" }, --Post-mowing minigame
	[15] = { title = "theater_select_1120", event = "ev1120" }, --Eggman tells Sage to get him out
	[16] = { title = "theater_select_1130", event = "ev1130" }, --Sage says she cannot fully control the Titans
	[17] = { title = "theater_select_1140", event = "ev1140" }, --Lover kodama is happy
	[18] = { title = "theater_select_1150", event = "ev1150" }, --Vision of the past
	[19] = { title = "theater_select_1160", event = "ev1160" }, --Amy is depressed
	[20] = { title = "theater_select_qu1500", event = "qu1500" }, --Tomb puzzle intro
	[21] = { title = "theater_select_ga1220", event = "ga1220" }, --Waterfall opens
	[22] = { title = "theater_select_qu1510", event = "qu1510" }, --Post tomb puzzle (Giganto prep)
	[23] = { title = "theater_select_1170", event = "ev1170" }, --Post Giganto, pre Ares
	Page = { pageCount = 8, pageRemaining = 2 }
  },
  Ares = {
	[1] = { title = "theater_select_2010", event = "ev2010" }, --Opening
	[2] = { title = "theater_select_2020", event = "ev2020" }, --Knuckles trapped
	[3] = { title = "theater_select_2030", event = "ev2030" }, --Knuckles freed
	[4] = { title = "theater_select_2040", event = "ev2040" }, --Incident intro
	[5] = { title = "theater_select_2050", event = "ev2050" }, --Incident end
	[6] = { title = "theater_select_2060", event = "ev2060" }, --Sage attacks Sonic
	[7] = { title = "theater_select_qu2500", event = "qu2500" }, --Pond puzzle intro
	[8] = { title = "theater_select_ga2220", event = "ga2220" }, --Draining the oasis
	[9] = { title = "theater_select_qu2510", event = "qu2510" }, --Post oasis drain
	[10] = { title = "theater_select_2070", event = "ev2070" }, --Soldier kodama reveal
	[11] = { title = "theater_select_2080", event = "ev2080" }, --Post soldier minigame success
	[12] = { title = "theater_select_2090", event = "ev2090" }, --Vision of the past
	[13] = { title = "theater_select_2100", event = "ev2100" }, --Sage tells Eggman about Sonic getting beaten
	[14] = { title = "theater_select_2110", event = "ev2110" }, --Eggman expresses respect for Sonic's abilities
	[15] = { title = "theater_select_2120", event = "ev2120" }, --Soldier kodama afraid
	[16] = { title = "theater_select_2130", event = "ev2130" }, --Sonic 3 flashback
	[17] = { title = "theater_select_2135", event = "ev2135" }, --Soldiers laid to rest
	[18] = { title = "theater_select_2140", event = "ev2140" }, --Sonic consoles Knuckles
	[19] = { title = "theater_select_qu2600", event = "qu2600" }, --Billiard puzzle intro
	[20] = { title = "theater_select_ga2210", event = "ga2210" }, --Landslide destruction
	[21] = { title = "theater_select_qu2610", event = "qu2610" }, --Post landslide destruction (Wyvern prep)
	[22] = { title = "theater_select_2150", event = "ev2150" }, --Post Wyvern, pre Chaos
	Page = { pageCount = 8, pageRemaining = 1 }
  },
  Chaos = {
	[1] = { title = "theater_select_3010", event = "ev3010" }, --Opening
	[2] = { title = "theater_select_3020", event = "ev3020" }, --Tails trapped
	[3] = { title = "theater_select_3030", event = "ev3030" }, --Tails freed
	[4] = { title = "theater_select_3040", event = "ev3040" }, --Incident intro
	[5] = { title = "theater_select_3050", event = "ev3050" }, --Incident end
	[6] = { title = "theater_select_3060", event = "ev3060" }, --Vision of the past
	[7] = { title = "theater_select_qu3500", event = "qu3500", hide = "BrokenRobot0" }, --Death egg robot
	[8] = { title = "theater_select_ga3210", event = "ga3210", hide = "BrokenRobot0" }, --Death egg laser fire
	[9] = { title = "theater_select_qu3510", event = "qu3510" }, --Tunnel open, Tails & Sonic convo
	[10] = { title = "theater_select_3070", event = "ev3070" }, --Kodama disciple intro
	[11] = { title = "theater_select_3080", event = "ev3080" }, --Pre item collection minigame
	[12] = { title = "theater_select_3090", event = "ev3090" }, --Post item collection minigame
	[13] = { title = "theater_select_3100", event = "ev3100" }, --Sage confronts Tails
	[14] = { title = "theater_select_3110", event = "ev3110" }, --Sage asks Eggman to team up with Sonic
	[15] = { title = "theater_select_3120", event = "ev3120" }, --Sage rescues Eggman from helicopters
	[16] = { title = "theater_select_3130", event = "ev3130" }, --Sage asks Sonic what his goal is
	[17] = { title = "theater_select_3140", event = "ev3140" }, --Tails expresses frustration ("wildly inconsistent")
	[18] = { title = "theater_select_qe3710", event = "qe3710" }, --Drawbridge intro
	[19] = { title = "theater_select_qe3720", event = "qe3720" }, --Drawbridge finish
	[20] = { title = "theater_select_3150", event = "ev3150" }, --Disciple laid to rest
	[21] = { title = "theater_select_3160", event = "ev3160" }, --Tails says he'll have his own adventures
	[22] = { title = "theater_select_qu3600", event = "qu3600", --Pinball door
	hide = {"VolcanicEruption0A", "VolcanicEruption1B","VolcanicEruption2C","VolcanicEruption3D", "VolcanicEruption4E", "VolcanicEruption5F","VolcanicEruption6G","VolcanicEruption7H","VolcanicEruption8I"} }, 
	[23] = { title = "theater_select_ga3220", event = "ga3220" }, --Pinball interior
	[24] = { title = "theater_select_ga3225", event = "ga3225" }, --Pinball finished, volcano erupts
	[25] = { title = "theater_select_qu3610", event = "qu3610" }, --Boss cloud cleared, Knight shown in crater
	[26] = { title = "theater_select_3170", event = "ev3170" }, --Post Knight, pre Rhea
	Page = { pageCount = 9, pageRemaining = 2 }
  },
  Rhea = {
	[1] = { title = "theater_select_4105", event = "ev4105" }, --Pillars erupting
	[2] = { title = "theater_select_4110", event = "ev4110" }, --The End commands the pillars be destroyed
	[3] = { title = "theater_select_4010", event = "ev4010" }, --"Engines harness power perfectly"
	[4] = { title = "theater_select_4015", event = "ev4015" }, --View of planet
	[5] = { title = "theater_select_4020", event = "ev4020" }, --Sonic limping
	[6] = { title = "theater_select_4030", event = "ev4030" }, --Spaceship fleet
	[7] = { title = "theater_select_4040", event = "ev4040" }, --Ancient elder educates young
	[8] = { title = "theater_select_4050", event = "ev4050" }, --Sonic further corrupts
	[9] = { title = "theater_select_4060", event = "ev4060" }, --Emerald powers Giganto
	[10] = { title = "theater_select_4070", event = "ev4070" }, --Ancients fight The End
	[11] = { title = "theater_select_4080", event = "ev4080" }, --Sonic fully corrupts (red background)
	Page = { pageCount = 4, pageRemaining = 2 }
  },
  Ouranos = {
    [1] = { title = "theater_select_5010", event = "ev5010" }, --Cyber corruption cleansed
	[2] = { title = "theater_select_qu4500", event = "qu4500" }, --Bridge hacking intro
	[3] = { title = "theater_select_ga1210", event = "ga1210", hide = "AncientBridge0" }, --Bridge spawn
	[4] = { title = "theater_select_qu4510", event = "qu4510" }, --Bridge hacking post
	[5] = { title = "theater_select_qu4600", event = "qu4600" }, --Door hacking intro
	[6] = { title = "theater_select_qu4610", event = "qu4610" }, --Door hacking post (6th emerald)
	[7] = { title = "theater_select_5020", event = "ev5020" }, --Eggman gives final emerald
	[8] = { title = "theater_select_5030", event = "ev5030" }, --Supreme beaten
	--[13] = { title = "theater_select_shooting", event = "zev_end_shooting" }, --"He took your home world" Real time, looks wrong
	[9] = { title = "theater_select_5040", event = "ev5040" }, --Sage dies
	[10] = { title = "theater_select_6010", event = "ev6010" }, --Friends freed
	[11] = { title = "theater_select_6020", event = "ev6020" }, --Sonic departs on plane
	[12] = { title = "theater_select_6030", event = "ev6030" }, --Eggman reboots Sage
	Page = { pageCount = 4, pageRemaining = 0}
  },
  Ouranos2 = {
    [1] = { title = "theater_select_1510", event = "ev1510" },
	[2] = { title = "theater_select_1520", event = "ev1520" },
	[3] = { title = "theater_select_ga1810", event = "ga1810" },
	[4] = { title = "theater_select_1530", event = "ev1530" },
	[5] = { title = "theater_select_ga1811", event = "ga1811", hide = {"AirFloorNoID70", "FriendsEmeraldEngine0"} },
	[6] = { title = "theater_select_ga1820", event = "ga1820", hide = {"AirFloorNoID70", "FriendsEmeraldEngine0"} },
	[7] = { title = "theater_select_1550", event = "ev1550" },
	[8] = { title = "theater_select_ga1821", event = "ga1821", hide = {"AirFloorNoID73", "FriendsEmeraldEngine1"} },
	[9] = { title = "theater_select_ga1830", event = "ga1830" },
	[10] = { title = "theater_select_1560", event = "ev1560", hide = {"AirFloorNoID70", "FriendsEmeraldEngine0"} },
	[11] = { title = "theater_select_1570", event = "ev1570", hide = {"AirFloorNoID73", "FriendsEmeraldEngine1"} },
	[12] = { title = "theater_select_1580", event = "ev1580", hide = {"TailsKodamaHacking4", "AirFloorNoID76", "FriendsEmeraldEngine2"} },
	[13] = { title = "theater_select_1590", event = "ev1590", hide = {"TailsKodamaHacking4", "AirFloorNoID76", "FriendsEmeraldEngine2"} },
	[14] = { title = "theater_select_ga1840", event = "ga1840", hide = {"TailsKodamaHacking4", "AirFloorNoID76", "FriendsEmeraldEngine2"} },
	[15] = { title = "theater_select_1610", event = "ev1610", hide = {"ExtraGiantTower0", "KodamaMaster0"} },
	[16] = { title = "theater_select_1630", event = "ev1630", hide = {"ExtraGiantTower1", "KodamaMaster1"} },
	[17] = { title = "theater_select_1650", event = "ev1650", hide = {"ExtraGiantTower2", "KodamaMaster2"} },
	[18] = { title = "theater_select_1670", event = "ev1670", hide = {"ExtraGiantTower3", "KodamaMaster3"} },
	[19] = { title = "theater_select_1680", event = "ev1680", hide = {"ExtraGiantTower3", "KodamaMaster3"} },
	[20] = { title = "theater_select_1690", event = "ev1690" },
	[21] = { title = "theater_select_ga1850", event = "ga1850" },
	[22] = { title = "theater_select_1700", event = "ev1700", hide = "FriendsEmeraldEngine3" },
	[23] = { title = "theater_select_1710", event = "ev1710" },
	[24] = { title = "theater_select_ga1860", event = "ga1860" },
	[25] = { title = "theater_select_1720", event = "ev1720", hide = {"AirFloorNoID82", "FriendsEmeraldEngine4"} },
	[26] = { title = "theater_select_ga1870", event = "ga1870" },
	[27] = { title = "theater_select_1730", event = "ev1730", hide = {"AirFloorNoID79", "FriendsEmeraldEngine5", "TailsKodamaHacking5"} },
	[28] = { title = "theater_select_1740", event = "ev1740", hide = {"AirFloorNoID82", "AirFloorNoID79", "FriendsEmeraldEngine3", "FriendsEmeraldEngine4", "FriendsEmeraldEngine5", "TailsKodamaHacking5"} },
	[29] = { title = "theater_select_1760", event = "ev1760" },
	[30] = { title = "theater_select_1770", event = "ev1770" },
   Page = { pageCount = 10, pageRemaining = 0 }
  }
}
CutsceneTableSide = {
  Kronos = {
	[1] = { title = "theater_side_architecture", event = "sb1000" },
	[2] = { title = "theater_side_ancients", event = "sb1010" },
	[3] = { title = "theater_side_condition", event = "sb1020" },
	[4] = { title = "theater_side_condition2", event = "sb1030" },
	[5] = { title = "theater_side_cyberspace", event = "sb1040" },
	[6] = { title = "theater_side_map", event = "sb1050" },
	[7] = { title = "theater_side_titan", event = "sb1060" },
	[8] = { title = "theater_side_islandpurpose", event = "sb1070" },
	[9] = { title = "theater_side_emeralds", event = "sb1080" },
	[10] = { title = "theater_side_sage", event = "sb1090" },
	Page = { pageCount = 4, pageRemaining = 1 }
  },
  Ares = {
	[1] = { title = "theater_side_architecture", event = "sb2000" },
	[2] = { title = "theater_side_ancients", event = "sb2010" },
	[3] = { title = "theater_side_condition", event = "sb2020" },
	[4] = { title = "theater_side_sage", event = "sb2030" },
	[5] = { title = "theater_side_cyberspace", event = "sb2040" },
	[6] = { title = "theater_side_map", event = "sb2050" },
	[7] = { title = "theater_side_titan", event = "sb2060" },
	[8] = { title = "theater_side_islandpurpose", event = "sb2070" },
	[9] = { title = "theater_side_emeralds", event = "sb2080" },
	[10] = { title = "theater_side_sage", event = "sb2090" },
	Page = { pageCount = 4, pageRemaining = 1 }
  },
  Chaos = {
	[1] = { title = "theater_side_architecture", event = "sb3000" },
	[2] = { title = "theater_side_ancients", event = "sb3010" },
	[3] = { title = "theater_side_condition2Tails", event = "sb3020" },
	[4] = { title = "theater_side_condition", event = "sb3030" },
	[5] = { title = "theater_side_cyberspace", event = "sb3040" },
	[6] = { title = "theater_side_map", event = "sb3050" },
	[7] = { title = "theater_side_titan", event = "sb3060" },
	[8] = { title = "theater_side_islandpurpose", event = "sb3070" },
	[9] = { title = "theater_side_emeralds", event = "sb3080" },
	[10] = { title = "theater_side_sage", event = "sb3090" },
	Page = { pageCount = 4, pageRemaining = 1 }
  },
  Ouranos = {
	[1] = { title = "theater_side_architecture", event = "sb4000" },
	[2] = { title = "theater_side_ancients", event = "sb4010" },
	[3] = { title = "theater_side_familiar", event = "sb4020" },
	[4] = { title = "theater_side_fought", event = "sb4030" },
	[5] = { title = "theater_side_legacy", event = "sb4040" },
	[6] = { title = "theater_side_map", event = "sb4050" },
	[7] = { title = "theater_side_titan", event = "sb4060" },
	[8] = { title = "theater_side_islandpurpose", event = "sb4070" },
	[9] = { title = "theater_side_emeralds", event = "sb4080" },
	[10] = { title = "theater_side_sage", event = "sb4090" },
	Page = { pageCount = 4, pageRemaining = 1 }
  },
  Ouranos2 = {
    [1] = { title = "theater_side_OR1", event = "sb5000" }, --Sn Am, trouble w/o you
	[2] = { title = "theater_side_OR2", event = "sb5001" }, --Am Sg, admirer
	[3] = { title = "theater_side_OR3", event = "sb5002" }, --Am Egg, No Good--
	[4] = { title = "theater_side_OR4", event = "sb5003" }, --Am Knux, Hunting tips
	[5] = { title = "theater_side_OR5", event = "sb5004" }, --Am Tls, Fast searcher
	[6] = { title = "theater_side_OR6", event = "sb5005" }, --Am Sg, Tower Purpose--
	[7] = { title = "theater_side_OR7", event = "sb5006" }, --Am Egg, No Animals
	[8] = { title = "theater_side_OR8", event = "sb5007" }, --Am Egg, Pyramid Terminals
	[9] = { title = "theater_side_OR9", event = "sb5100" }, --Sn Knux, Wasting time--
	[10] = { title = "theater_side_OR10", event = "sb5101" }, --Knux Sg, Echidna power
	[11] = { title = "theater_side_OR11", event = "sb5102" }, --Knux Egg, No time to banter
	[12] = { title = "theater_side_OR12", event = "sb5103" }, --Knux Amy, Cyber Corruption Mysteries--
	[13] = { title = "theater_side_OR13", event = "sb5104" }, --Knux Tls, Emeralds on the move
	[14] = { title = "theater_side_OR14", event = "sb5105" }, --Knux Sg, Ships under Ares
	[15] = { title = "theater_side_OR15", event = "sb5106" }, --Knux Tls, Ares Oasis--
	[16] = { title = "theater_side_OR16", event = "sb5200" }, --Tls Sn, Cool gadget
	[17] = { title = "theater_side_OR17", event = "sb5201" }, --Tls Sg, Powers combined
	[18] = { title = "theater_side_OR18", event = "sb5202" }, --Tls Egg, What I Can Do--
	[19] = { title = "theater_side_OR19", event = "sb5203" }, --Tls Am, Power of Ghosts
	[20] = { title = "theater_side_OR20", event = "sb5204" }, --Tls Knux, The Best Part
	[21] = { title = "theater_side_OR21", event = "sb5205" }, --Tls Sg, Ancient Satellites--
	[22] = { title = "theater_side_OR22", event = "sb5206" }, --Tls Egg, No such thing as magic
	[23] = { title = "theater_side_OR23", event = "sb5300" }, --Sn Sg, To the tower
	[24] = { title = "theater_side_OR24", event = "sb5301" }, --Sn Egg, Spectacular Plan--
	[25] = { title = "theater_side_OR25", event = "sb5302" }, --Sn Am, Damsel in Distress
	[26] = { title = "theater_side_OR26", event = "sb5303" }, --Sn Knux, Leave the emeralds to me
	[27] = { title = "theater_side_OR27", event = "sb5304" }, --Sn Tls, Our own jobs--
	[28] = { title = "theater_side_OR28", event = "sb5305" }, --Sn Sg, Ancient Tribes
	[29] = { title = "theater_side_OR29", event = "sb5306" }, --Sn Egg, Ancient Transportation
	[30] = { title = "theater_side_OR30", event = "sb5400" }, --Sn Am, Koco Secrets--
	[31] = { title = "theater_side_OR31", event = "sb5401" }, --Am Sg, Souls of the Ancients
	[32] = { title = "theater_side_OR32", event = "sb5402" }, --Am Egg, Incorporeal Disturbance
	[33] = { title = "theater_side_OR33", event = "sb5403" }, --Am Knux, Questioning Koco--
	[34] = { title = "theater_side_OR34", event = "sb5404" }, --Am Tls, Corrupted Koco
	[35] = { title = "theater_side_OR35", event = "sb5405" }, --Am Sg, A Mysterious Symbol
	[36] = { title = "theater_side_OR36", event = "sb5406" }, --Am Egg, Mysterious Lights--
	[37] = { title = "theater_side_OR37", event = "sb5407" }, --Am Sg, Koco Towers
	[38] = { title = "theater_side_OR38", event = "sb5500" }, --Knux Sn, Rival hunters
	[39] = { title = "theater_side_OR39", event = "sb5501" }, --Knux Sg, A faraway foe--
	[40] = { title = "theater_side_OR40", event = "sb5502" }, --Knux Egg, Emerald Stealing
	[41] = { title = "theater_side_OR41", event = "sb5503" }, --Knux Am, Your motives
	[42] = { title = "theater_side_OR42", event = "sb5504" }, --Knux Tls, Accessing Cyber Space--
	[43] = { title = "theater_side_OR43", event = "sb5505" }, --Knux Egg, Ares Rings
	[44] = { title = "theater_side_OR44", event = "sb5506" }, --Knux Sg, Secrets of Starfall
	[45] = { title = "theater_side_OR45", event = "sb5600" }, --Tls Sn, Checking in--
	[46] = { title = "theater_side_OR46", event = "sb5601" }, --Tls Sg, Before my body is dry
	[47] = { title = "theater_side_OR47", event = "sb5602" }, --Tls Egg, A formidable foe
	[48] = { title = "theater_side_OR48", event = "sb5603" }, --Tls Am, Worsening corruption--
	[49] = { title = "theater_side_OR49", event = "sb5604" }, --Tls Knux, You Have My Fists
	[50] = { title = "theater_side_OR50", event = "sb5605" }, --Tls Sg, Death Egg Robot
	[51] = { title = "theater_side_OR51", event = "sb5606" }, --Tls Sn, Pinball Secrets--
	[52] = { title = "theater_side_OR52", event = "sb5607" }, --Tls Egg, Eggman's Machines
	[53] = { title = "theater_side_OR53", event = "sb5700" }, --Sn Sg, The Last Tower
	[54] = { title = "theater_side_OR54", event = "sb5701" }, --Sn Egg, Rushing Genius--
	[55] = { title = "theater_side_OR55", event = "sb5702" }, --Sn Am, Take Care of Yourself
	[56] = { title = "theater_side_OR56", event = "sb5703" }, --Sn Knux, Taking a Break
	[57] = { title = "theater_side_OR57", event = "sb5704" }, --Sn Tls, I've Got Your Back--
	[58] = { title = "theater_side_OR58", event = "sb5705" }, --Sn Sg, Illusory Rails
	[59] = { title = "theater_side_OR59", event = "sb5706" }, --Sn Sg, Big's Big Secret
	[60] = { title = "theater_side_OR60", event = "sb5707" }, --Sn Sg, The Giant Pyramid
	Page = { pageCount = 20, pageRemaining = 0 }
  }
}
CutsceneTableBoss = {
  Kronos = {
    [1] = { title = "theater_boss_intro", event = "ga1225" },
	[2] = { title = "theater_boss_transform", event = "bo1120" },
	[3] = { title = "theater_boss_phase", event = "bo1140" },
	[4] = { title = "theater_boss_kill", event = "bo1160" },
	[5] = { title = "theater_boss_fail", event = "bo1180" },
	[6] = { title = "theater_boss_smashGiganto", event = "zev_sp00" }, --Grand Slam
	Page = { pageCount = 2, pageRemaining = 0}
  },
  Ares = {
	[1] = { title = "theater_boss_intro", event = "bo2110" },
	[2] = { title = "theater_boss_wyvernGrab", event = "bo2115" },
	[3] = { title = "theater_boss_transform", event = "bo2120" },
	[4] = { title = "theater_boss_phase", event = "bo2140" },
	[5] = { title = "theater_boss_wyvern00", event = "zev_dragon_finish_00" }, --Beta version of the finale
	[6] = { title = "theater_boss_fail", event = "bo2180" },
	[7] = { title = "theater_boss_QTEwyv", event = "zev_dragon_sp_missile" }, --First missiles
	[8] = { title = "theater_boss_QTE2wyv", event = "zev_dragon_sp_psycho" }, --Finale, pt1 (psycho)
	[9] = { title = "theater_boss_QTE3wyv", event = "zev_dragon_finish_01" }, -- Finale, pt2 (missiles/kill)
	[10] = { title = "theater_boss_smash", event = "zev_dragon_sp_01" }, --Grand Slam
	Page = { pageCount = 4, pageRemaining = 1 }
  },
  Chaos = {
	[1] = { title = "theater_boss_intro", event = "bo3110" },
	[2] = { title = "theater_boss_transform", event = "bo3120" },
	[3] = { title = "theater_boss_phase", event = "bo3140" },
	[4] = { title = "theater_boss_kill", event = "bo3160" },
	[5] = { title = "theater_boss_fail", event = "bo3180" },
	[6] = { title = "theater_boss_QTEkni", event = "zev_knight_shieldride01" }, --Shield ride
	[7] = { title = "theater_boss_QTE2kni", event = "zev_knight_atk_sp01" }, --Sword swing
	[8] = { title = "theater_boss_smash", event = "zev_knight_sonic_sp01" }, --Grand Slam
	Page = { pageCount = 3, pageRemaining = 2 }
  },
  Ouranos = {
	[1] = { title = "theater_boss_intro", event = "bo4110" },
	[2] = { title = "theater_boss_phase", event = "bo4140" },
	[3] = { title = "theater_boss_kill", event = "bo4160" },
	[4] = { title = "theater_boss_fail", event = "bo4180" },
	[5] = { title = "theater_boss_QTEsup", event = "zev_rfl_bitlaser02" }, --Large Bit blast
	[6] = { title = "theater_boss_QTE2sup", event = "zev_rfl_shoot02" }, --Retail QTE (short)
	[7] = { title = "theater_boss_QTE3sup", event = "test_bo2115" }, --Retail QTE (long)
	[8] = { title = "theater_boss_QTE4sup", event = "zev_rfl_shoot01" }, --Unused QTE
	[9] = { title = "theater_boss_QTE5sup", event = "zev_rfl_sp01" }, --Clap/Bite (unused)
	[10] = { title = "theater_boss_QTE6sup", event = "zev_rfl_sp02" }, --Mega Laser (unused)
	[11] = { title = "theater_boss_smash", event = "zev_rfl_sp00" }, --Grand Slam
	Page = { pageCount = 4, pageRemaining = 2 }
  },
  Ouranos2 = {
    [1] = { title = "theater_boss_intro", event = "bo6110", hide = "ExtraGiantTower4" }, --RT
	[2] = { title = "theater_boss_transformNew", event = "bo6120", hide = "ExtraGiantTower4" }, --RT
	[3] = { title = "theater_boss_phaseHalf", event = "bo6125", hide = "ExtraGiantTower4" },
	[4] = { title = "theater_boss_cableBack", event = "bo6130", hide = "ExtraGiantTower4" },
	[5] = { title = "theater_boss_phase", event = "bo6140", hide = "ExtraGiantTower4" }, --RT
	[6] = { title = "theater_boss_altFail", event = "bo6150", hide = "ExtraGiantTower4" },
	[7] = { title = "theater_boss_beastMoon1", event = "bo6160", hide = "ExtraGiantTower4" },
	[8] = { title = "theater_boss_beastMoon2", event = "bo6165", hide = "ExtraGiantTower4" }, --RT
	[9] = { title = "theater_boss_beastMoonFail", event = "bo6170", hide = "ExtraGiantTower4" },
	[10] = { title = "theater_boss_fail", event = "bo6180", hide = "ExtraGiantTower4" },
	[11] = { title = "theater_boss_kill", event = "bo6190", hide = "ExtraGiantTower4" }, --_mov01, _mov02
	[12] = { title = "theater_boss_QTE1beast", event = "zev_sp_riflebeast", hide = "ExtraGiantTower4" }, --Has Realtime
	[13] = { title = "theater_boss_QTE2beast", event = "zev_blow_rifleboss", hide = "ExtraGiantTower4" },
	[14] = { title = "theater_boss_smash", event = "zev_riflebeast_fingersnap", hide = "ExtraGiantTower4" }, --RT
	Page = { pageCount = 5, pageRemaining = 2 }
  }
}
CutsceneTableMisc = {
  Kronos = {
	[1] = { title = "theater_misc_tutohouse", event = "ga1410" }, --Initial enemy encounter in tutorial
	[2] = { title = "theater_misc_bridge", event = "ga1205", hide = "GiantBridge_Daruma" }, --Tutorial bridge spawn
	[3] = { title = "theater_misc_pan", event = "ev1999" }, --Kronos island pan
	[4] = { title = "theater_misc_pan2", event = "ev1999_nx64" }, --Kronos island pan (beta)
	[5] = { title = "theater_misc_encounter2", event = "ev1041" }, --Falling during the Giganto incident
	[6] = { title = "theater_misc_green", event = "qe1080" }, --Green Chaos Emerald dance
	[7] = { title = "theater_misc_cyan", event = "qe1110" }, --Light Blue Chaos Emerald dance
	[8] = { title = "theater_misc_starfall", event = "ga1620" }, --Starfall
	[9] = { title = "theater_misc_0010mov", event = "ev0010_mov" }, --Real-time versions
	[10] = { title = "theater_misc_0020mov", event = "ev0020_mov" }, 
	[11] = { title = "theater_misc_1120mov", event = "ev1010_mov" }, 
	[12] = { title = "theater_misc_1120mov", event = "ev1120_mov" }, 
	[13] = { title = "theater_misc_1130mov", event = "ev1130_mov" }, 
	[14] = { title = "theater_misc_1150mov", event = "ev1150_mov" }, 
	[15] = { title = "theater_misc_1170mov", event = "ev1170_mov" }, 
	[16] = { title = "theater_misc_9010mov", event = "ev9010_mov" }, 
	Page = { pageCount = 6, pageRemaining = 1 }
  },
  Ares = {
	[1] = { title = "theater_misc_green", event = "qe2080" }, --Green Chaos Emerald dance
	[2] = { title = "theater_misc_dance", event = "qe2130" }, --Dance with no emerald
	[3] = { title = "theater_misc_cyan", event = "qe2135" }, --Light Blue Chaos Emerald dance
	[4] = { title = "theater_misc_starfall", event = "ga2620" }, --Starfall
	[5] = { title = "theater_misc_2010mov", event = "ev2010_mov" }, --Real-time versions
	[6] = { title = "theater_misc_2090mov", event = "ev2090_mov" }, 
	[7] = { title = "theater_misc_2100mov", event = "ev2100_mov" }, 
	[8] = { title = "theater_misc_2110mov", event = "ev2110_mov" }, 
	[9] = { title = "theater_misc_2150mov", event = "ev2150_mov" }, 
	Page = { pageCount = 3, pageRemaining = 0 }
  },
  Chaos = {
	[1] = { title = "theater_misc_green", event = "qe3090" }, --Green Chaos Emerald dance
	[2] = { title = "theater_misc_cyan", event = "qe3150" }, --Light Blue Chaos Emerald dance
	[3] = { title = "theater_misc_starfall", event = "ga3620" }, --Starfall
	[4] = { title = "theater_misc_3010mov", event = "ev3010_mov" }, --Real-time versions
	[5] = { title = "theater_misc_3110mov", event = "ev3110_mov" }, 
	[6] = { title = "theater_misc_3120mov", event = "ev3120_mov" }, 
	[7] = { title = "theater_misc_3170mov", event = "ev3170_mov" }, 
	Page = { pageCount = 3, pageRemaining = 1 }
  },
  Rhea = {
	[1] = { title = "theater_misc_tower", event = "ga4610" }, --Deactivating a tower
	[2] = { title = "theater_misc_4040mov", event = "ev4040_mov" }, --Non-prerendered versions of these cutscenes
	[3] = { title = "theater_misc_4060mov", event = "ev4060_mov" },
	[4] = { title = "theater_misc_4070mov01", event = "ev4070_mov01" },
	[5] = { title = "theater_misc_4070mov02", event = "ev4070_mov02" },
	[6] = { title = "theater_misc_4080mov", event = "ev4080_mov" },
	[7] = { title = "theater_misc_4105mov", event = "ev4105_mov" },
	[8] = { title = "theater_misc_4110mov", event = "ev4110_mov" },
	[9] = { title = "theater_misc_starfall", event = "ga4620" },
	Page = { pageCount = 3, pageRemaining = 0 }
  },
  Ouranos = {
	[1] = { title = "theater_misc_5030mov", event = "ev5030_mov" }, --Real time versions
	[2] = { title = "theater_misc_5040mov", event = "ev5040_mov" },
	[3] = { title = "theater_misc_6010mov01", event = "ev6010_mov01" },
	[4] = { title = "theater_misc_6010mov02", event = "ev6010_mov02" },
	[5] = { title = "theater_misc_6020mov", event = "ev6020_mov" },
	[6] = { title = "theater_misc_6030mov", event = "ev6030_mov" },
	[7] = { title = "theater_misc_caterpillar", event = "bo2020" }, --Unused caterpillar cutscene from Wyvern files
	[8] = { title = "theater_misc_starfall", event = "ga4620" },
	Page = { pageCount = 3, pageRemaining = 2 }
  },
  Ouranos2 = {
    [1] = { title = "theater_select_ga1831", event = "ga1831", hide = {"TailsKodamaHacking4", "AirFloorNoID76", "FriendsEmeraldEngine2"} }, --Tails looks at sky
    [2] = { title = "theater_select_ga1721", event = "ga1721", hide = "ExtraGiantTower0" }, --Tower unsealed: 1
    [3] = { title = "theater_select_ga1722", event = "ga1722", hide = "ExtraGiantTower1" }, --Tower unsealed: 2
    [4] = { title = "theater_select_ga1723", event = "ga1723", hide = "ExtraGiantTower2" }, --Tower unsealed: 3
    [5] = { title = "theater_select_ga1724", event = "ga1724", hide = "ExtraGiantTower3" }, --Tower unsealed: 4
    [6] = { title = "theater_select_ga1841", event = "ga1841", hide = {"ExtraGiantTower3", "KodamaMaster3"} }, --Sonic looks at sky. What a hero.
    [7] = { title = "theater_select_ga1851", event = "ga1851", hide = "FriendsEmeraldEngine3" }, --Amy looks at sky. Variety!
    [8] = { title = "theater_select_ga1861", event = "ga1861", hide = {"AirFloorNoID82", "FriendsEmeraldEngine4"} }, --Knuckles looks at sky! Awesome!
    [9] = { title = "theater_select_ga1871", event = "ga1871", hide = {"AirFloorNoID79", "FriendsEmeraldEngine5", "TailsKodamaHacking5"} }, --Tails looks at sky. Repetition!
    [10] = { title = "theater_select_ga1725", event = "ga1725", hide = "ExtraGiantTower4" }, --Tower unsealed: 5
	[11] = { title = "theater_misc_6110mov", event = "bo6110_mov", hide = "ExtraGiantTower4" }, --Realtime boss variants.
	[12] = { title = "theater_misc_6120mov", event = "bo6120_mov", hide = "ExtraGiantTower4" },
	[13] = { title = "theater_misc_6140mov", event = "bo6140_mov", hide = "ExtraGiantTower4" },
	[14] = { title = "theater_misc_6165mov", event = "bo6165_mov", hide = "ExtraGiantTower4" },
	[15] = { title = "theater_misc_6190mov01", event = "bo6190_mov01", hide = "ExtraGiantTower4" },
	[16] = { title = "theater_misc_6190mov02", event = "bo6190_mov02", hide = "ExtraGiantTower4" },
	[17] = { title = "theater_misc_spBeastmov", event = "zev_sp_riflebeast_mov", hide = "ExtraGiantTower4" },
	[18] = { title = "theater_misc_Snapmov", event = "zev_riflebeast_fingersnap_mov", hide = "ExtraGiantTower4" },
    Page = { pageCount = 6, pageRemaining = 0 }
  }
}
--Duration can be a number or a table. Apply a number for each anim loaded if it's a table.
--Dir is used for directional variants and does not support pages. The Dir gets added to the base event. 
--appFirst causes the Appends to happen before the Dirs.
--Appends get added to event, after Dirs. To play the base event, add "".
--Subcat needs a field for page count (4 per page) along with the additional selectable options (this gets added to Event).
--The Appends will be added to the corresponding subcat. ^
--Neutral should only be present if the base event should be selectable along with the dirs/subcats.
--If subIndex is present, accesses Event in the AnimationSubTable then goes to the subIndex.
AnimationTable = {
  Object = {
	[1] = { title = "theater_animation_dashring", event = "DASHRING" },
	[2] = { title = "theater_animation_gliding", event = "", duration = 3, append = {"GLIDING", "FLOAT_LOOP"} },
	[3] = { title = "theater_animation_spring", event = "SPRING", duration = { 1.5, 1 }, append = { "_JUMP", "_LANDING" } },
	[4] = { title = "theater_animation_cloud", event = "CLOUD_JUMP_TOP", duration = 5 },
	[5] = { title = "theater_animation_jumpsel", event = "SELECTJUMP", duration = { 1, 3, 0.5 }, dirs = { "_F", "_U", "_MISS" }, append = { "_START", "_LOOP", "_END" } },
	[6] = { title = "theater_animation_jumpboard", event = "JUMPBOARD", duration = {0.5, 3}, append = {"", "_LOOP"} },
	[7] = { title = "theater_animation_pulley", event = "PULLEY", subcat = {"", "_UP", count = 1}, append = { {"_START", "", "_END"}, {"_START", "", "_END"} }, neutral = true },
	[8] = {title = "theater_animation_polespin", duration = 4, event = "POLESPIN", append = { "_START", "_JUMP_START"} },
	[9] = {title = "theater_animation_box", event = "BOX", subcat = {"_PUSH", "_KICK_BOOST", count = 1}, append = { {subIndex = "PUSH"}, {subIndex = "KICK_BOOST"} } },
	[10] = {title = "theater_animation_impact_object", duration = 2, event = "IMPACT_OBJECT", subcat = { "", "_SP", count = 1}, neutral = true },
	[11] = {title = "theater_animation_operate_console", duration = 2.5, event = "OPERATE_CONSOLE", subcat = { "", "_L", "_R", count = 1}, neutral = true },
	[12] = {title = "theater_animation_cannonball", event = "DOWN_CANNONBALL" },
	[13] = {title = "theater_animation_waterfall", event = "WATERFALL", duration = 3, append = { "_IDLE", "_WALK"} },
	[14] = {title = "theater_animation_take", event = "TAKE", duration = 3, dirs = { "_EMERALD_FIRST", "_EMERALD"} },
	[15] = {title = "theater_animation_bee", event = "BEE_AWAY_RUN_LOOP", duration = 3 },
	[16] = {title = "theater_animation_send", event = "SEND_SIGNAL", duration = 2 },
	Page = { pageCount = 6, pageRemaining = 1 }
  },
  Ability = {
	[1] = { title = "theater_animation_boost", event = "BOOST", duration = 3, subcat = {"", "_AIR", count = 1}, neutral = true },
	[2] = { title = "theater_animation_stomp", event = "STOMP_CONS", duration = 3 },
	[3] = { title = "theater_animation_pursuit", event = "COMBO_PURSUIT", duration = { 0.6, 3 }, append = { "", "_LOOP" } },
	[4] = { title = "theater_animation_sonicboom", event = "COMBO_SONICBOOM", duration = 3 },
	[5] = { title = "theater_animation_crasher", event = "COMBO_CRASHER", duration = { 0.75, 3 }, append = { "_START", "_LOOP" } },
	[6] = { title = "theater_animation_homingshot", event = "COMBO_HOMINGSHOT" },
	[7] = { title = "theater_animation_charge", event = "COMBO_CHARGE", duration = { 0.45, 1.5, 0.5, 0.5 }, append = { "", "_LOOP", "_FINISH", "_END" } },
	[8] = { title = "theater_animation_crossslash", event = "COMBO_CROSSSLASH", duration = { 0.5, 1.5, 1 }, append = { "", "_LOOP", "_END" } },
	[9] = {title = "theater_animation_attack", event = "ATTACK_BOUNCE" },
	[10] = {title = "theater_animation_storm", event = "STORM", duration = 3, subcat = { "", "_DAMAGE", "_STRUGGLE", count = 1}, neutral = true },
	[11] = {title = "theater_animation_behind", event = "BEHIND", dirs = { "_R", "_L"} },
	[12] = {title = "theater_animation_stolen", event = "STOLEN", append = { "_EMERALD", "_EMERALD_LOOP", "_EMERALD_END", "_EMERALD_FALL_DOWN", "_EMERALD_DOWN_RETURN"} },
	[13] = {title = "theater_animation_charger", event = "CHARGER_RAIL_STRUGGLE_LOOP", duration = 3},
	[14] = {title = "theater_animation_debuff", event = "DEBUFF", duration = 3, append = { "_IDLE", "_WALK"} },
	[15] = {title = "theater_animation_stomping", event = "STOMPING", duration = 3, subcat = { "", "_BOUNCE", "_PRESS", count = 1}, append = { {"_START", "", "_END"} }, neutral = true },
	[16] = {title = "theater_animation_sandski", event = "SANDSKI", duration = 3, subcat = {"", "_BLOW", "_DOWN", "_FELL", "_INPUT", count = 2}, append = { {"", "_JUMP", "_JUMP_UD", "_LANDING"}, [4] = {subIndex = "FELL"}, [5] = {subIndex = "INPUT"} }, neutral = true},
	Page = { pageCount = 6, pageRemaining = 1 }
  },
  Traversal = {
	[1] = { title = "theater_animation_runslip", event = "RUN_SLIP", duration = { 1, 3, 0.5 }, dirs = { "_FRONT" }, append = { "", "_LOOP", "_END" }, neutral = true },
	[2] = { title = "theater_animation_grind", event = "GRIND", duration = 3, subcat = {"", "_LAND", "_JUMP", "_STEP_L", "_STEP_R", "_FALL", "_DAMAGE", count = 2}, neutral = true },
	[3] = { title = "theater_animation_brake", event = "BRAKE", duration = 3, dirs = {"_CLIFF", "_NEUTRAL", "_SLOPE" } },
	[4] = { title = "theater_animation_dive", event = "DIVE", duration = 5, subcat = { "", "_DAMAGE", "_FAST", "_IDLE", "_PIPE", count = 2 }, append = { {"_START"}, [3] = {"", "_LOOP", "_END"}, [4] = {"_START", ""} }, neutral = true },
	[5] = {title = "theater_animation_slidedown", event = "SLIDEDOWN", duration = {0.5, 1.5, 0.75}, dirs = {"_R", "_L"}, append = { "_START", "_LOOP", "_END" }, appFirst = true  },
	[6] = {title = "theater_animation_fall", event = "FALL", duration = {3, 3}, append = { "", "_LOOP"} },
	[7] = {title = "theater_animation_slow", duration = 5, event = "SLOW_WALK" },
	[8] = {title = "theater_animation_landing", event = "LANDING", subcat = { "", "_INJURY", "_BATTLE", "_CORRUPTION_WEAK", "_CORRUPTION_STRONG", "_CARRY", count = 2}, neutral = true },
	[9] = {title = "theater_animation_wallstick", duration = 3, event = "WALLSTICK", dirs = { "_L", "_R"}, append = {"", "_LOOP"} },
	[10] = {title = "theater_animation_walljump", duration = {3, 3}, event = "WALLJUMP", append = { "", "_LOOP"} },
	[11] = {title = "theater_animation_running", event = "RUNNING", dirs = { "", "_CARRY", "_CANNONBALL"}, neutral = true },
	[12] = {title = "theater_animation_wall_leave", duration = 2, event = "WALL", append = { "_LEAVE", "_LEAVE_LOOP"} },
	[13] = {title = "theater_animation_sliding", event = "SLIDING_BACKSTEP" },
	Page = { pageCount = 5, pageRemaining = 1 }
  },
  Misc = {
	[1] = { title = "theater_animation_boarding", event = "BOARDING", subcat = {"", "_LOW", "_DAMAGE", "_JUMP", "_FALL", "_TRICK00", "_TRICK01", "_DASHRING", "_JUMPBOARD", "_LAND", "_LAND_BIG", count = 3}, duration = 3, neutral = true },
	[2] = { title = "theater_animation_hang", event = "HANG", duration = 3, subcat = {"01", "02", "03", count = 1 }, append = { {"_SHAKE", "_L", "_SHAKE_L", "_R", "_SHAKE_R"} } },
	[3] = { title = "theater_animation_dead", event = "DEAD", subcat = { "", "WATER_", count = 1 }, duration = {3, 1.5, 3}, append = { {"", "_LOOP"}, {"", "_LOOP", "_AIR"} }, appFirst = {[2] = true}, neutral = true },
	[4] = { title = "theater_animation_damage", event = "DAMAGE", duration = { 0.5, 1.5, 0.75}, subcat = { "", "_LAVA", count = 1 }, append = { {"", "_LAND", "_STANDUP"}, {"", "_LOOP", "_END"} }, neutral = true },
	[5] = { title = "theater_animation_stumble", event = "STUMBLE_RUN", duration = 3 },
	[6] = { title = "theater_animation_battle", event = "BATTLE", duration = { 1.25, 1, 1 }, subcat = {"_DOWN", "_DAMAGE_BLOW", count = 1}, append = { {"", "_LOOP", "_END", "_END_CORRUPTION_WEAK", "_END_CORRUPTION_STRONG"}, {"_FRONT"} } },
	[7] = { title = "theater_animation_parried", event = "PARRIED", duration = 3 },
	[8] = { title = "theater_animationed", event = "GUARD", duration = {2, 1}, subcat = {"ED", "_WALK", "_WAIT", count = 1}, append = { {""}, {"", "_DAMAGE"}, {""} } },
	[9] = { title = "theater_animation_bump", event = "BUMP", subcat = {"_STAGGER", "_JUMP", "_JUMP_RETURN", "_ROLL", "_BIG_ROLL", count = 2}, duration = 3, append = { {subIndex = "BUMP_STAGGER"}, {subIndex = "BUMP_JUMP"}, {subIndex = "BUMP_JUMP_RETURN"}, {subIndex = "BUMP_ROLL"}, {"_F", "_F_END"} } },
	[10] = {title = "theater_animation_awakening", duration = 2, event = "AWAKENING" },
	[11] = {title = "theater_animation_idle", event = "IDLE", duration = 12, subcat = { "_ACT00", "_ACT01", "_INJURY", "_ACT06", "_ACT07", "_ACT08_SV", "_ACT09_SV", "_EMPTY", "_CORRUPTION_WEAK_LOOP", "_CORRUPTION_STRONG_LOOP", count = 3} },
	[12] = {title = "theater_animation_ev", event = "ev", duration = 5, subcat = { "_talk", "_hear", "_idle02", "_idle03", count = 1}, append = { {"", "_oneshot"} } },
	[13] = {title = "theater_animation_event", event = "EVENT_REACTION1", duration = 5 },
	[14] = {title = "theater_animation_begin", event = "BEGIN", subcat = { "_RISE", "_DOWN", count = 1}, duration = 7 },
	Page = { pageCount = 5, pageRemaining = 2 }
  }
}
AnimationSubTable = {
  BUMP = {
    BUMP_JUMP = { title = "theater_animation_reg", event = "BUMP_JUMP", duration = 5, subcat = {"", "_L", "_R", count = 1}, append = { {"_START", "_START_LOOP", "_FALL"} }, neutral = true },
	BUMP_JUMP_RETURN = { title = "theater_animation_reg", event = "BUMP_JUMP_RETURN", duration = 3, subcat = {"_U", "_D", "_L", "_R", count = 1} },
	BUMP_STAGGER = {title = "theater_animation_l", event = "BUMP_STAGGER", subcat = {"_L", "_R", count = 1}},
	BUMP_ROLL = {title = "theater_animation_l", event = "BUMP_ROLL", duration = 3, subcat = {"_L", "_R", count = 1}}
  },
  BOX = {
	PUSH = { title = "theater_animation_push", event = "BOX_PUSH", duration = 3, subcat = {"_L", "_R", count = 1}, append = { {"_START", "_LOOP", "_END"}, {"_START", "_LOOP", "_END"} } },
	KICK_BOOST = { title = "theater_animation_kick", event = "BOX_KICK_BOOST", duration = 3, subcat = {"_L", "_R", count = 1}  }
  },
  SANDSKI = {
	FELL = {title = "theater_animation_fell", event = "SANDSKI_FELL", duration = 3, subcat = {"_INPUT_L", "_INPUT_R", count = 1}, append = { {"", "_LOOP", "_END"}, {"", "_LOOP", "_END"} } },
	INPUT= {title = "theater_animation_input", event = "SANDSKI_INPUT", duration = 3, subcat = {"_L", "_R", count = 1}, append = { {"_GRAB"}, {"_GRAB"} }}
  }
}
MinigameTable = {
  Kronos = {
    [1] = {title = "theater_minigame_koco", event = "KodamaCollect01", warning = true},
	[2] = {title = "theater_minigame_mowing", event = "Mowing"}
  },
  Ares = {
    [1] = {title = "theater_minigame_koco2", event = "KodamaEscort", warning = true},
	[2] = {title = "theater_minigame_koco", event = "KodamaCollect02", warning = true},
	[3] = {title = "theater_minigame_defense", event = "DarumaBattle"}
  },
  Chaos = {
	[1] = {title = "theater_minigame_bolts", event = "CollectItem"},
	[2] = {title = "theater_minigame_dive", event = "DrawBridge"},
	[3] = {title = "theater_minigame_pinball", event = ""}
  }
}
PlayAllTable = {
  "DASHRING",
 "GLIDING",
 "RUN_SLIP_LOOP",
 "RUN_SLIP_END",
 "RUN_SLIP",
 "RUN_SLIP_FRONT_LOOP",
 "RUN_SLIP_FRONT_END",
 "RUN_SLIP_FRONT",
 "SQUAT_LOOP",
 "SQUAT_END",
 "STOMPING",
 "STOMPING_END",
 "SQUAT",
 "STOMPING_BOUNCE",
 "STOMPING_START",
 "STOMP_CONS",
 "STOMPING_PRESS",
 "PULLEY_UP_START",
 "PULLEY_UP",
 "PULLEY_UP_END",
 "PULLEY_UP_TO_FALL",
 "PULLEY",
 "PULLEY_START",
 "PULLEY_END",
 "CLIMBING_L",
 "CLIMBING_R",
 "CLIMBING_DOWN_L",
 "CLIMBING_DOWN_R",
 "CLIMBING_IDLE_R",
 "CLIMBING_IDLE_L",
 "CLIMBING_START",
 "CLIMBING_TO_IDLE_R",
 "CLIMBING_TO_IDLE_L",
 "HANG01",
 "HANG03",
 "HANG01_SHAKE",
 "HANG02",
 "CLIMBING_LEFT_L",
 "CLIMBING_LEFT_R",
 "CLIMBING_RIGHT_R",
 "CLIMBING_RIGHT_L",
 "CLIMBING_LEFT_WIDE_L",
 "CLIMBING_LEFT_WIDE_R",
 "CLIMBING_RIGHT_WIDE_L",
 "CLIMBING_RIGHT_WIDE_R",
 "HANG01_L",
 "HANG01_SHAKE_L",
 "HANG01_R",
 "HANG01_SHAKE_R",
 "CLIMBING_START_L",
 "CLIMBING_START_R",
 "CLIMBING_R_UP",
 "CLIMBING_L_UP",
 "CLIMBING_RESET_R",
 "CLIMBING_RESET_L",
 "CLIMBING_EDGE_STICK",
 "CLIMBING_EDGE_TOP",
 "CLIMBING_STUMBLE_START_R",
 "CLIMBING_STUMBLE_RETURN_R",
 "CLIMBING_STUMBLE_RETURN_L",
 "CLIMBING_STUMBLE_START_L",
 "SLIDEDOWN_START_R",
 "SLIDEDOWN_START_L",
 "SLIDEDOWN_LOOP_L",
 "SLIDEDOWN_LOOP_R",
 "SLIDEDOWN_END_R",
 "SLIDEDOWN_END_L",
 "CLIMBING_FALL",
 "CLIMBING_EDGE_STICK_L",
 "CLIMBING_EDGE_SIDE_L",
 "CLIMBING_EDGE_STICK_R",
 "CLIMBING_EDGE_SIDE_R",
 "CLIMBING_REVEDGE_STICK_R",
 "CLIMBING_REVEDGE_SIDE_R",
 "CLIMBING_REVEDGE_STICK_L",
 "CLIMBING_REVEDGE_SIDE_L",
 "WALL_LEAVE",
 "WALL_LEAVE_LOOP",
 "JUMP_UP",
 "JUMP_START",
 "GRIND",
 "GRIND_LAND",
 "GRIND_JUMP",
 "GRIND_STEP_L",
 "GRIND_STEP_R",
 "GRIND_FALL",
 "GRIND_DAMAGE",
 "DIVE",
 "DIVE_FAST_LOOP",
 "DIVE_FAST_END",
 "DIVE_IDLE_START",
 "DIVE_IDLE",
 "DIVE_START",
 "DIVE_DAMAGE",
 "DIVE_PIPE",
 "DIVE_FAST",
 "JUMPBOARD_LOOP",
 "JUMPBOARD",
 "QUICK_TURN",
 "BRAKE_CLIFF",
 "BRAKE_NEUTRAL",
 "BRAKE_SLOPE",
 "SIDESTEP_LEFT",
 "QUICKSTEP_LEFT",
 "QUICKSTEP_RIGHT",
 "SIDESTEP_RIGHT",
 "COMBO_SMASH",
 "COMBO_SMASH_START",
 "COMBO_SMASH_LOOP",
 "COMBO_PURSUIT",
 "COMBO_PURSUIT_LOOP",
 "COMBO_FINISH_B",
 "COMBO_SMASH_HEAVY",
 "COMBO_FINISH_ACCELE",
 "COMBO_ACCELE_PUNCH05",
 "COMBO_ACCELE_PUNCH01",
 "COMBO_ACCELE_KICK05",
 "COMBO_ACCELE_KICK01",
 "COMBO_SMASH_HEAVY_SHORT",
 "COMBO_FINISH_ACCELE_L",
 "COMBO_FINISH_L",
 "COMBO_FINISH_R",
 "COMBO_FINISH_ACCELE_B",
 "COMBO_CHARGE",
 "COMBO_LOOPKICK_START",
 "COMBO_LOOPKICK",
 "COMBO_CRASHER_START",
 "COMBO_CRASHER_LOOP",
 "COMBO_CHARGE_LOOP",
 "COMBO_CHARGE_END",
 "COMBO_SONICBOOM",
 "COMBO_FINISH_ACCELE_R",
 "COMBO_FINISH_F",
 "COMBO_FINISH_ACCELE_F",
 "COMBO_FINISH",
 "COMBO_CHARGE_FINISH",
 "COMBO_HOMINGSHOT",
 "COMBO_CROSSSLASH",
 "ATTACK_BOUNCE",
 "COMBO_CROSSSLASH_END",
 "COMBO_CROSSSLASH_LOOP",
 "BALL_MOVE",
 "JUMP_BALL",
 "JUMP_BALL_CENTER",
 "DEAD_LOOP",
 "DEAD",
 "WATER_DEAD_AIR",
 "WATER_DEAD_LOOP",
 "WATER_DEAD",
 "DAMAGE_STANDUP",
 "DAMAGE_LAND",
 "DAMAGE",
 "STUMBLE_RUN",
 "BATTLE_DAMAGE",
 "BATTLE_DOWN",
 "BATTLE_DOWN_LOOP",
 "BATTLE_DOWN_END",
 "BATTLE_DAMAGE_BLOW_FRONT",
 "BATTLE_DAMAGE_BLOW_LOOP",
 "BATTLE_DAMAGE_BLOW_LEFT",
 "BATTLE_DAMAGE_BLOW_RIGHT",
 "BATTLE_DAMAGE_BLOW_BACK",
 "BEHIND_R",
 "PARRIED",
 "BEHIND_L",
 "GUARDED_LOOP",
 "GUARDED",
 "BATTLE_DOWN_END_BATTLE",
 "DAMAGE_LAVA",
 "DAMAGE_LAVA_END",
 "DAMAGE_LAVA_LOOP",
 "BATTLE_DOWN_END_CORRUPTION_WEAK",
 "BATTLE_DOWN_END_CORRUPTION_STRONG",
 "AVOID_FRONT",
 "PARRY",
 "PARRY_LOOP",
 "AVOID_RIGHT",
 "AVOID_LEFT",
 "PARRY_MISS",
 "AVOID_BACK",
 "PARRY_AIR",
 "PARRY_LOOP_AIR",
 "PARRY_MISS_AIR",
 "AVOID_FRONT_AIR",
 "AVOID_FRONT_LAND",
 "AVOID_LEFT_AIR",
 "AVOID_RIGHT_AIR",
 "AVOID_BACK_AIR",
 "AVOID_LEFT_LAND",
 "AVOID_RIGHT_LAND",
 "AVOID_BACK_LAND",
 "PARRY_START",
 "PARRY_START_AIR",
 "BUMP_JUMP",
 "BUMP_JUMP_LOOP",
 "BUMP_ROLL_L",
 "BUMP_ROLL_R",
 "BUMP_ROLL_F",
 "BUMP_STAGGER_L",
 "BUMP_STAGGER_R",
 "BUMP_JUMP_L",
 "BUMP_JUMP_L_LOOP",
 "BUMP_JUMP_R_LOOP",
 "BUMP_JUMP_R",
 "BUMP_BIG_ROLL_F",
 "BUMP_BIG_ROLL_F_END",
 "BUMP_BIG_ROLL_L_END",
 "BUMP_BIG_ROLL_L",
 "BUMP_BIG_ROLL_R_END",
 "BUMP_BIG_ROLL_R",
 "BUMP_JUMP_RETURN_U",
 "BUMP_JUMP_RETURN_D",
 "BUMP_JUMP_RETURN_L",
 "BUMP_JUMP_RETURN_R",
 "BUMP_JUMP_FALL",
 "BUMP_JUMP_START_LOOP",
 "BUMP_JUMP_START",
 "GUARD_WALK_DAMAGE",
 "GUARD_WALK",
 "GUARD_WAIT",
 "TAKE_EMERALD_FIRST",
 "TAKE_EMERALD",
 "WALL_DASH",
 "WALL_RUNNING",
 "BOARDING",
 "BOARDING_LOW",
 "BOARDING_DAMAGE",
 "BOARDING_JUMP",
 "BOARDING_JUMP_LOOP",
 "BOARDING_FALL",
 "BOARDING_TRICK00_START",
 "BOARDING_TRICK00",
 "BOARDING_TRICK01",
 "BOARDING_DASHRING",
 "BOARDING_JUMPBOARD",
 "BOARDING_TRICK01_START",
 "BOARDING_DASHRING_START",
 "BOARDING_JUMPBOARD_START",
 "BOARDING_LAND",
 "BOARDING_LAND_BIG",
 "IDLE_ACT00",
 "IDLE_ACT01",
 "IDLE01",
 "IDLE01_START",
 "IDLE_INJURY",
 "IDLE_ACT06",
 "IDLE_ACT07",
 "IDLE_ACT08_SV",
 "IDLE_ACT09_SV",
 "IDLE_BATTLE_LOOP",
 "LANDING_INJURY",
 "LANDING",
 "LANDING_BATTLE",
 "LANDING_CORRUPTION_STRONG",
 "LANDING_CORRUPTION_WEAK",
 "STAND",
 "IDLE_EMPTY",
 "IDLE_CORRUPTION_STRONG_LOOP",
 "IDLE_CORRUPTION_WEAK_LOOP",
 "SLIDING_LOOP",
 "SLIDING_IDLE",
 "SLIDING_BACKSTEP",
 "BEGIN_RISE",
 "BEGIN_DOWN",
 "SPRING_JUMP",
 "SPRING_LANDING",
 "CLOUD_JUMP_TOP",
 "WATERFALL_WALK",
 "WATERFALL_IDLE",
 "OPERATE_CONSOLE",
 "OPERATE_CONSOLE_L",
 "OPERATE_CONSOLE_R",
 "IMPACT_OBJECT",
 "SEND_SIGNAL",
 "IMPACT_OBJECT_SP",
 "POLESPIN_START",
 "POLESPIN_LOOP",
 "POLESPIN_JUMP_START",
 "POLESPIN_JUMP_LOOP",
 "SELECTJUMP_F_START",
 "SELECTJUMP_F_LOOP",
 "SELECTJUMP_F_END",
 "SELECTJUMP_U_START",
 "SELECTJUMP_U_LOOP",
 "SELECTJUMP_U_END",
 "SELECTJUMP_MISS_START",
 "SELECTJUMP_MISS_LOOP",
 "SELECTJUMP_MISS_END",
 "DRIFT",
 "EVENT_REACTION1",
 "ev_talk",
 "ev_hear",
 "ev_talk_oneshot",
 "ev_idle02",
 "ev_idle03",
 "RUNNING",
 "RUNNING_BATTLE",
 "FALL",
 "FALL_LOOP",
 "BOOST_AIR",
 "SLOW_WALK",
 "RUN",
 "WALK",
 "DASH",
 "BOOST",
 "JUMP_TRICK_U0",
 "JUMP_TRICK_FALL",
 "JUMP_TRICK_U1",
 "JUMP_TRICK_U2",
 "JUMP_TRICK_R0",
 "JUMP_TRICK_L0",
 "JUMP_TRICK_L1",
 "JUMP_TRICK_L2",
 "JUMP_TRICK_R1",
 "JUMP_TRICK_R2",
 "JUMP_TRICK_D0",
 "JUMP_TRICK_D1",
 "JUMP_TRICK_D2",
 "JUMP_TRICK_FINISH_F",
 "JUMP_TRICK_FINISH_B",
 "DEBUFF_IDLE",
 "DEBUFF_WALK",
 "WALLSTICK_R_LOOP",
 "WALLSTICK_R",
 "WALLSTICK_L",
 "WALLSTICK_L_LOOP",
 "WALLJUMP",
 "WALLJUMP_LOOP",
 "STRUGGLE_GRB_LOOP",
 "BOX_PUSH_L_START",
 "BOX_PUSH_L_LOOP",
 "BOX_PUSH_L_END",
 "BOX_PUSH_R_START",
 "BOX_PUSH_R_LOOP",
 "BOX_PUSH_R_END",
 "BOX_KICK_BOOST_L",
 "BOX_KICK_BOOST_R",
 "FLOAT_LOOP",
 "SANDSKI",
 "SANDSKI_BLOW",
 "SANDSKI_DOWN",
 "SANDSKI_JUMP",
 "SANDSKI_JUMP_UD",
 "SANDSKI_LANDING",
 "SANDSKI_L_END",
 "SANDSKI_R_END",
 "SANDSKI_FELL_R",
 "SANDSKI_FELL_L",
 "SANDSKI_FELL_INPUT_L_LOOP",
 "SANDSKI_FELL_INPUT_L_END",
 "SANDSKI_FELL_INPUT_R",
 "SANDSKI_FELL_INPUT_R_LOOP",
 "SANDSKI_FELL_INPUT_R_END",
 "SANDSKI_FELL_INPUT_L",
 "SANDSKI_INPUT_R_GRAB",
 "SANDSKI_INPUT_L_GRAB",
 "BEE_AWAY_RUN_LOOP",
 "RUNNING_CARRY",
 "STAND_CARRY",
 "JUMP_CARRY",
 "JUMP_CARRY_LOOP",
 "JUMP_CARRY_TOP",
 "JUMP_CARRY_DOWN_LOOP",
 "LANDING_CARRY",
 "DOWN_CANNONBALL",
 "STAND_CANNONBALL",
 "RUNNING_CANNONBALL",
 "STORM",
 "STORM_DAMAGE",
 "STORM_STRUGGLE",
 "STOLEN_EMERALD",
 "STOLEN_EMERALD_LOOP",
 "STOLEN_EMERALD_END",
 "STOLEN_EMERALD_FALL_LOOP",
 "STOLEN_EMERALD_FALL_DOWN",
 "STOLEN_EMERALD_DOWN_LOOP",
 "STOLEN_EMERALD_DOWN_RETURN",
 "HOOP_RAIL_JUMP_LOOP",
 "CHARGER_RAIL_STRUGGLE_LOOP",
 "UPDOWNPOLE_START",
 "UPDOWNPOLE_LOOP",
 "UPDOWNPOLE_F_LOOP",
 "UPDOWNPOLE_B_LOOP",
 "UPDOWNPOLE_DAMAGE",
 "AWAKENING"
}
---------------------------------------------------------------------