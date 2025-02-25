--[[
   Copyright (c) The OpenRA Developers and Contributors
   This file is part of OpenRA, which is free software. It is made
   available to you under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of
   the License, or (at your option) any later version. For more
   information, see COPYING.
]]
MissleSubs = { MSub1, MSub2, MSub3, MSub4 }
VolkovEntryPath = { LSTEntry.Location, LZ.Location }
VolkovandFriend = { "volk", "delphi" }
InsertionTransport = "lst.reinforcement"
SamSites = { Sam1, Sam2, Sam3, Sam4, Sam5, Sam6, Sam7, Sam8, Sam9, Sam10, Sam11, Sam12 }
PrimaryTargets = { BioLab, Silo1, Silo2 }
TimerTicks = DateTime.Minutes(8)

Shocktroopers = { Shok1, Shok2, Shok3, Shok4 }

InnerPatrolPaths =
{
	{ InnerPatrol2.Location, InnerPatrol3.Location, InnerPatrol4.Location, InnerPatrol1.Location },
	{ InnerPatrol3.Location, InnerPatrol2.Location, InnerPatrol1.Location, InnerPatrol4.Location },
	{ InnerPatrol4.Location, InnerPatrol1.Location, InnerPatrol2.Location, InnerPatrol3.Location },
	{ InnerPatrol1.Location, InnerPatrol4.Location, InnerPatrol3.Location, InnerPatrol2.Location }
}

OuterPatrols =
{
	{ TeamOne1, TeamOne2, TeamOne3 },
	{ TeamTwo1, TeamTwo2, TeamTwo3 },
	{ TeamThree1, TeamThree2, TeamThree3 },
	{ TeamFour1, TeamFour2, TeamFour3 },
	{ TeamFive1, TeamFive2, TeamFive3 }
}

OuterPatrolPaths =
{
	{ OuterPatrol1.Location, OuterPatrol2.Location, OuterPatrol3.Location, OuterPatrol4.Location, OuterPatrol5.Location, OuterPatrol6.Location, OuterPatrol7.Location },
	{ OuterPatrol5.Location, OuterPatrol4.Location, OuterPatrol3.Location, OuterPatrol2.Location, OuterPatrol1.Location, OuterPatrol7.Location, OuterPatrol6.Location },
	{ OuterPatrol6.Location, OuterPatrol7.Location, OuterPatrol1.Location, OuterPatrol2.Location, OuterPatrol3.Location, OuterPatrol4.Location, OuterPatrol5.Location },
	{ OuterPatrol3.Location, OuterPatrol4.Location, OuterPatrol5.Location, OuterPatrol6.Location, OuterPatrol7.Location, OuterPatrol1.Location, OuterPatrol2.Location },
	{ OuterPatrol3.Location, OuterPatrol2.Location, OuterPatrol1.Location, OuterPatrol7.Location, OuterPatrol6.Location, OuterPatrol5.Location, OuterPatrol4.Location }
}

GroupPatrol = function(units, waypoints, delay)
	local i = 1
	local stop = false

	Utils.Do(units, function(unit)
		Trigger.OnIdle(unit, function()
			if stop then
				return
			end
			if unit.Location == waypoints[i] then
				local bool = Utils.All(units, function(actor) return actor.IsIdle end)
				if bool then
					stop = true
					i = i + 1
					if i > #waypoints then
						i = 1
					end
					Trigger.AfterDelay(delay, function() stop = false end)
				end
			else
				unit.AttackMove(waypoints[i])
			end
		end)
	end)
end

StartPatrols = function()
	for i = 1, 5 do
		GroupPatrol(OuterPatrols[i], OuterPatrolPaths[i], DateTime.Seconds(3))
	end

	for i = 1, 4 do
		Trigger.AfterDelay(DateTime.Seconds(3* (i - 1)), function()
			Trigger.OnIdle(Shocktroopers[i], function()
				Shocktroopers[i].Patrol(InnerPatrolPaths[i])
			end)
		end)
	end
end

LabInfiltrated = false
SetupTriggers = function()
	Trigger.OnAllKilled(SamSites, function()
		USSR.MarkCompletedObjective(KillSams)
		SendInBombers()
	end)

	Trigger.OnInfiltrated(BioLab, function()
		Media.DisplayMessage(UserInterface.GetFluentMessage("plans-stolen-erase-data"), UserInterface.GetFluentMessage("scientist"))
		Trigger.AfterDelay(DateTime.Seconds(5), function()
			USSR.MarkCompletedObjective(InfiltrateLab)
			LabInfiltrated = true
			SendInBombers()
		end)
	end)

	Trigger.OnKilled(BioLab, function()
		if not LabInfiltrated then
			USSR.MarkFailedObjective(InfiltrateLab)
		end
	end)

	Trigger.OnAllKilled(PrimaryTargets, function()
		USSR.MarkCompletedObjective(DestroyFacility)
		USSR.MarkCompletedObjective(VolkovSurvive)
	end)

	Trigger.OnAllKilled(MissleSubs, function()
		if not VolkovArrived then
			USSR.MarkFailedObjective(KillPower)
		end
	end)
end

SendInBombers = function()
	if LabInfiltrated and USSR.IsObjectiveCompleted(KillSams) then
		local proxy = Actor.Create("powerproxy.parabombs", false, { Owner = USSR })
		proxy.TargetAirstrike(TacticalNuke1.CenterPosition, Angle.SouthWest)
		proxy.TargetAirstrike(TacticalNuke2.CenterPosition, Angle.SouthWest)
		proxy.TargetAirstrike(TacticalNuke3.CenterPosition, Angle.SouthWest)
		proxy.Destroy()
	end
end


SendInVolkov = function()
	if not VolkovArrived then
		USSR.MarkCompletedObjective(KillPower)
		Media.PlaySpeechNotification(USSR, "ReinforcementsArrived")
		local teamVolkov = Reinforcements.ReinforceWithTransport(USSR, InsertionTransport, VolkovandFriend, VolkovEntryPath, { VolkovEntryPath[1] })[2]
		VolkovArrived = true
		Trigger.OnKilled(teamVolkov[1], function()
			USSR.MarkFailedObjective(VolkovSurvive)
		end)
		Trigger.OnAddedToWorld(teamVolkov[1], function(a)
			Media.DisplayMessage(UserInterface.GetFluentMessage("software-update-failed-manual-targets"), UserInterface.GetFluentMessage("volkov"))
		end)

		Trigger.OnAddedToWorld(teamVolkov[2], function(b)
			Trigger.OnKilled(b, function()
				if not LabInfiltrated then
					USSR.MarkFailedObjective(InfiltrateLab)
				end
			end)
		end)
	end
end

Ticked = TimerTicks
Tick = function()
	if Turkey.PowerState ~= "Normal" then
		SendInVolkov()
	end

	if Ticked > 0 then
		if (Ticked % DateTime.Seconds(1)) == 0 then
			Timer = UserInterface.GetFluentMessage("missiles-launch-in", { ["time"] = Utils.FormatTime(Ticked) })
			UserInterface.SetMissionText(Timer, TimerColor)
		end
		Ticked = Ticked - 1
	elseif Ticked == 0 then
		UserInterface.SetMissionText(UserInterface.GetFluentMessage("too-late"), USSR.Color)
		Turkey.MarkCompletedObjective(LaunchMissles)
	end
end

WorldLoaded = function()
	USSR = Player.GetPlayer("USSR")
	Turkey = Player.GetPlayer("Turkey")

	InitObjectives(USSR)

	LaunchMissles = AddPrimaryObjective(Turkey, "")
	KillPower = AddPrimaryObjective(USSR, "kill-power")
	InfiltrateLab = AddPrimaryObjective(USSR, "infiltrate-bio-weapons-lab-scientist")
	DestroyFacility = AddPrimaryObjective(USSR, "destroy-bio-weapons-lab-missile-silos")
	KillSams = AddSecondaryObjective(USSR, "destroy-all-sam-sites-strategic-bombers")
	VolkovSurvive = AddPrimaryObjective(USSR, "volkov-survive")

	Trigger.AfterDelay(DateTime.Minutes(3), function()
		Media.PlaySpeechNotification(USSR, "WarningFiveMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(5), function()
		Media.PlaySpeechNotification(USSR, "WarningThreeMinutesRemaining")
	end)
	Trigger.AfterDelay(DateTime.Minutes(7), function()
		Media.PlaySpeechNotification(USSR, "WarningOneMinuteRemaining")
	end)

	StartPatrols()
	SetupTriggers()
	Camera.Position = DefaultCameraPosition.CenterPosition
	TimerColor = Turkey.Color
end
