GLOBAL.UpvalueHacker = GLOBAL.require "tools/UpvalueHacker" -- debug

local oasisSeason = GetModConfigData("OasisSeason")
local FreezeLake = GetModConfigData("FreezeLake")
local FreezeLakeM = GetModConfigData("FreezeLakeMos")
local SandStorm = GetModConfigData("Sandstorm")

local Prefabs = GLOBAL.Prefabs
local UpvalueHacker = GLOBAL.require "tools/UpvalueHacker"
local COLLISION = GLOBAL.COLLISION

local function EmptyLake(inst, skipanim)
	if skipanim then
		inst.AnimState:PlayAnimation("dry_idle")
    else
        inst.AnimState:PlayAnimation("dry_pre")
        inst.AnimState:PushAnimation("dry_idle", false)
    end

    inst.components.fishable:Freeze()

    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.ITEMS)

    inst:RemoveTag("watersource")
    inst:AddTag("NOCLICK")

	inst.isfilled = false
end

local function FillLake(inst, skipanim)
    if skipanim then
        inst.AnimState:PlayAnimation("idle", true)
    else
        inst.AnimState:PlayAnimation("dry_pst")
        inst.AnimState:PushAnimation("idle", true)
    end

    inst.components.fishable:Unfreeze()

    inst.Physics:CollidesWith(COLLISION.CHARACTERS)
    inst.Physics:CollidesWith(COLLISION.GIANTS)

    inst:AddTag("watersource")
    inst:RemoveTag("NOCLICK")

	inst.isfilled = true
end

local function ShouldFillUp(season)
	return oasisSeason == 2 and (season ~= "winter") or oasisSeason == 3
end

local function OnSeasonChanged(inst, data, skipanim)
	local _season = type(data) == "table" and data.season or data
	local active = ShouldFillUp(_season)

    if active and not inst.isfilled then
		local SpawnOasisBugs = UpvalueHacker.GetUpvalue(Prefabs.oasislake.fn, "OnInit", "OnSandstormChanged", "SpawnOasisBugs")
		local SpawnSucculents = UpvalueHacker.GetUpvalue(Prefabs.oasislake.fn, "OnInit", "OnSandstormChanged", "SpawnSucculents")
        FillLake(inst, skipanim)
		SpawnOasisBugs(inst)
        SpawnSucculents(inst)
    elseif not active and inst.isfilled then
		EmptyLake(inst, skipanim)
    end
end

local function OnInitOasis(inst)
    inst.task = nil
	inst:RemoveAllEventCallbacks()
	inst:WatchWorldState("season", function(src, data) OnSeasonChanged(inst, data) end, GLOBAL.TheWorld)
	OnSeasonChanged(inst, GLOBAL.TheWorld.state.season, true) 
end

local function OnInitPonds(inst)
	inst.task = nil
	inst:StopAllWatchingWorldStates()
	local OnIsDay = UpvalueHacker.GetUpvalue(Prefabs.pond.fn, "OnInit", "OnIsDay")
    inst:WatchWorldState("isday", OnIsDay)
    OnIsDay(inst, GLOBAL.TheWorld.state.isday)

	inst.frozen = false
    inst.AnimState:PlayAnimation("idle"..inst.pondtype, true)
    inst.components.childspawner:StartSpawning()
    inst.components.fishable:Unfreeze()

	inst.Physics:SetCollisionGroup(COLLISION.OBSTACLES)
    inst.Physics:ClearCollisionMask()
    inst.Physics:CollidesWith(COLLISION.WORLD)
    inst.Physics:CollidesWith(COLLISION.ITEMS)
    inst.Physics:CollidesWith(COLLISION.CHARACTERS)

    inst:AddTag("watersource")
end

--------------------------------------------------------------------------------------------------------------------
local function ChangeOasisLake(inst)	
	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	if oasisSeason ~= 1 then
		inst.isfilled = false
		inst.task = inst:DoTaskInTime(1, OnInitOasis)
	end
end

local function ChangeLake(inst)
	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	if not FreezeLake then
		inst.task = inst:DoTaskInTime(1, OnInitPonds)
	end
end

local function ChangeLakeMos(inst)
	if not GLOBAL.TheWorld.ismastersim then
		return
	end

	if not FreezeLakeM then
		inst.task = inst:DoTaskInTime(1, OnInitPonds)
	end
end

AddPrefabPostInit("oasislake", ChangeOasisLake)
AddPrefabPostInit("pond", ChangeLake)
AddPrefabPostInit("pond_mos", ChangeLakeMos)

AddPrefabPostInit("forest", function(inst)
	if SandStorm ~= 1 then
		-- Since it's not able to get values' reference, I had no option except for replacing every case where _sandstormactive is used to a new class variable's.

		local sandstorms = inst.components.sandstorms
		sandstorms._active = false -- This is now act like _sandstormactive.

		local _sandstormactive = sandstorms._active

		function sandstorms:IsInSandstorm(ent)
			return _sandstormactive
				and ent.components.areaaware ~= nil
				and ent.components.areaaware:CurrentlyInTag("sandstorm")
		end

		function sandstorms:GetSandstormLevel(ent)
			if _sandstormactive and
				ent.components.areaaware ~= nil and
				ent.components.areaaware:CurrentlyInTag("sandstorm") then
				local oasislevel = sandstorms:CalcOasisLevel(ent)
				return oasislevel < 1
					and math.clamp(sandstorms:CalcSandstormLevel(ent) - oasislevel, 0, 1)
					or 0
			end
			--TODO: entities without areaaware need to know if they're inside the sandstorm
			return 0
		end

		function sandstorms:IsSandstormActive()
			return _sandstormactive
		end


		local ToggleSandStorm, ShouldActivateSandstorm
		for k, v in pairs(inst.event_listening.seasontick[inst]) do
			local reference = UpvalueHacker.GetUpvalue(v, "ToggleSandstorm")

			if reference ~= nil then 
				ShouldActivateSandstorm = UpvalueHacker.GetUpvalue(reference, "ShouldActivateSandstorm")
				ToggleSandStorm = reference
				break
			end
		end

		if ToggleSandStorm ~= nil then
			ToggleSandStorm = function()
				if _sandstormactive and (SandStorm ~= 0 and ShouldActivateSandstorm() and (SandStorm == 2 and not inst.components.worldstate.data.iswinter) or SandStorm == 3) then
					_sandstormactive = not _sandstormactive
					inst:PushEvent("ms_sandstormchanged", _sandstormactive)
				end
			end
		end
	end
end)