local DamageService = {}
DamageService.__index = DamageService

---- Variables Section ----

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Replicated_Shared = ReplicatedStorage:WaitForChild("Shared")

local ToolsFolder = ServerStorage:WaitForChild("Scripts")["Utilities"]["Tools"]
local ServiceFolder = ServerStorage:WaitForChild("Scripts")["Utilities"]["Services"]

local MonsterService = require(ServiceFolder:WaitForChild("MonstersService"))
local RandomService = require(ServiceFolder:WaitForChild("RandomService"))

local ProfileManager = require(ServerStorage:WaitForChild("Scripts")["MainSystem"]["DataSystem"]["DatastoreHandler"]["Manager"])

local Roact = require(Replicated_Shared:WaitForChild("Roact"))
local debug = require(ToolsFolder:WaitForChild("savegg's tools")).debug.new()

local RegisteredDamageID = {}

debug:SetName("Damage")
debug:Toggle(false)

---- Functions Section ----

local function FindCharacterHumanoid(_Character : Instance, Timeout : number) -- Refactor -> Done
	if _Character == nil or _Character == "" then return "" end
	
	if not _Character:IsA("Instance") then
		debug:Log(2, "Error! FindCharacterHumanoid function accept parameter Instance type only!")
	end
	
	local foundChar = _Character:WaitForChild("Humanoid", Timeout)
	
	debug:Log(1, foundChar ~= nil and "Found character for : " .. tostring(_Character) or "Couldn't find character for : " .. tostring(_Character))
	return foundChar
end

-- Here's where you can modify all of damage calculation
local function CalculateDamage(Attack, Defense, IsOwnerATrap)
	if not IsOwnerATrap then
		local totalValue = Attack * (100 / (100  + Defense)) -- Damage calculation formula

		if totalValue < 0 then
			totalValue = 0
		end
		
		return totalValue
	else
		return Attack
	end
end

function DamageService.Register(Owner : Instance)
	debug:Log(2, "Attempting to register DAMAGE for " .. Owner.Name)
	local self = setmetatable({}, DamageService)
	
	self.Owner = if Owner:IsA("Player") then Owner.Character else Owner
	self.OwnerProperties = {}

	self:Init(1)
	
	self.Target = ""
	self.TargetProperties = {}
	
	self.ID = RandomService.Random_UID(10, RegisteredDamageID)
	RegisteredDamageID[self.ID] = self
	
	debug:Log(1, "Successfully registered DAMAGE for " .. Owner.Name)
	return self
end

--[[

1 -> Owner
2 -> Target

]]

function DamageService:Init(Input : number | {"1 -> Owner, 2 -> Target"}) -- Refactor / beautify -> Testing
	debug:Log(2, ("Initializing properties for : " .. (Input == 1 and "Owner..." or "Target...")))
	local PropertiesTable
	local OperationTarget = Input == 1 and "Owner" or "Target"
	
	if self[OperationTarget] ~= "" then
		PropertiesTable = self[OperationTarget.."Properties"]
		
		local OperationModel : Instance = self[OperationTarget]
		local isObjectAPlayer = Players:GetPlayerFromCharacter(OperationModel)

		PropertiesTable["Name"] = if isObjectAPlayer then isObjectAPlayer.Name else OperationModel:GetAttribute("Name") or ""
		PropertiesTable["Type"] = if isObjectAPlayer then "Player" else OperationModel:GetAttribute("Type") or ""
		PropertiesTable["ID"] = if isObjectAPlayer then isObjectAPlayer.UserId else OperationModel:GetAttribute("ID")
		PropertiesTable["Parent"] = if PropertiesTable["Type"] == "Player" then
			Players:GetPlayerFromCharacter(OperationModel)
			else
			OperationModel
		PropertiesTable["Model"] = OperationModel
		
		PropertiesTable["Humanoid"] = FindCharacterHumanoid(OperationModel, 5)
		assert(PropertiesTable["Humanoid"], "Couldn't find humanoid for " .. PropertiesTable.Parent.Name)
		
		PropertiesTable["Data"] = if PropertiesTable.Type == "Monster" then 
			self:GetMonsterData(Input)
			elseif PropertiesTable.Type == "Player" then
			self:GetPlayerData(Input)
			else
			""
	else
		self[OperationTarget.."Properties"] = {}
	end

	debug:Log(1, "Successfully initializing object properties.")
	return PropertiesTable
end

function DamageService:GetObjectProperties(Input : number | {"1 -> Owner, 2 -> Target"})
	local ObjectOwner = Input == 1 and "Owner" or "Target"
	local ObjectProperties = self[tostring(ObjectOwner).. "Properties"]

	if ObjectProperties then
		return ObjectProperties
	else
		debug:Log(2, "Error! Couldn't get properties for " .. ObjectOwner .. " ! Plesae check if there's a typo in the system!")
	end
end

function DamageService:GetPlayerData(Input : number | {"1 -> Owner, 2 -> Target"}) -- Rewrite (Handle more unexpected case.)
	local ObjectProperties = self:GetObjectProperties(Input)

	if not ObjectProperties then return end

	local Player : Instance = ObjectProperties.Parent
	
	if Player and Player:IsA("Player") then
		local StatsFolder = Player:WaitForChild("MainStats", 5)
		if StatsFolder then
			return StatsFolder
		end
	end
end

function DamageService:GetMonsterData(Input : number | {"1 -> Owner, 2 -> Target"}) -- Rewrite (Handle more unexpected case.)
	local ObjectName
	local ObjectProperties = self:GetObjectProperties(Input)
	if ObjectProperties then
		ObjectName = ObjectProperties.Name
	end

	local Data
	local rawData = MonsterService:GetMonsterInfo(ObjectName)

	if rawData then
		Data = rawData.Data
	end

	return Data or {}
end

function DamageService:SetTarget(Enemy : Instance | nil)
	if Enemy ~= nil then
		self.Target = if Enemy:IsA("Player") then Enemy.Character else Enemy
	else
		self.Target = ""
	end
	
	self:Init(2)
	
	debug:Log(1, "Set the target for .. " .. self.Owner.Name .. " to : " .. (self.Target ~= nil and self.Target.Name or "nil"))
	return
end

function DamageService:GetTarget()
	return self.Target or nil
end

function DamageService:GetTotalDamage()
	local OwnerProperties = self.OwnerProperties
	local TargetProperties = self.TargetProperties

	if not OwnerProperties.Model then debug:Log(2, "Error! Couldn't find properties for owner!") return end
	if not TargetProperties.Model then debug:Log(2, "Error! Couldn't find properties for target!") return end

	if not OwnerProperties.Data then
		debug:Log(2, "Error! Couldn't find data for owner!")
		return
	end

	if not TargetProperties.Data then
		debug:Log(2, "Error! Couldn't find data for target!")
		return
	end

	local Attack = (if OwnerProperties.Type == "Player" then
		OwnerProperties.Data.Attack.Value
		else
		OwnerProperties.Data.Stats.Attack) or 0

	local Defense = (if TargetProperties.Type == "Player" then
		TargetProperties.Data.Defense.Value
		else
		TargetProperties.Data.Stats.Defense) or 0
	
	return CalculateDamage(Attack, Defense, OwnerProperties.Type == "Trap")
end

function DamageService:TakeDamage()
	local Humanoid : Humanoid = self.TargetProperties["Humanoid"]

	local FinalDamage = self:GetTotalDamage()
	
	if Humanoid and Humanoid.Health > 0 then
		Humanoid:TakeDamage(FinalDamage)
		debug:Log(1, ("%s has dealt %s damage to %s"):format(self.Owner.Name, FinalDamage, self.Target.Name))
	end
end

function DamageService:Destroy()
	table.clear(self)
	table.freeze(self)

	setmetatable(self, nil)

	return true
end


-- Debug Function

function DamageService:FORCE_ChangeProperty(Input : number, Property : string, newData : any)
	local PropertyTableParent = Input == 1 and self.Owner or self.Target
	local PropertyTable = self[tostring(PropertyTableParent.Name).."Properties"]

	if not PropertyTable then return end
	
end

return DamageService
