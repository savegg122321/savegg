local DialogueService = {}
DialogueService.__index = DialogueService

---- Variables ----

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServiceFolder = ServerStorage:WaitForChild("Scripts", 5) or nil
if ServiceFolder then ServiceFolder = ServiceFolder.Utilities.Services end

local ToolsFolder = ServerStorage:WaitForChild("Scripts", 5) or nil
if ToolsFolder then ToolsFolder = ToolsFolder.Utilities.Tools end


---- Service Classes ----

local RandomService = require(ServiceFolder:WaitForChild("RandomService", 5)) or nil
local Tools = require(ToolsFolder["savegg's tools"])

local debug = Tools.debug.new()
debug:SetName("Dialogue")
debug:Toggle(true)
debug:GetCallback(false)


---- Self-Used Services ----

local Manager = require(script.Manager)
local Settings = require(script.Settings)
local TextAnimator = require(script.TextAnimator)

local DialogueTemplate = script:WaitForChild("DialogueTemplate")

local DialogueMaterialsFolder = ReplicatedStorage:WaitForChild("DialogueMaterials")
if not DialogueMaterialsFolder then
	debug:Log(2, "DialogueMaterials Folder not found! Please contact developer to check the code.")
end


--[[
	State List :
	
	- Idle 			-> 		When dialogue does nothing or didn't start
	- Texting		->		When dialogue text is displaying / playing animation
	- Skip			->		When dialogue got skipped by user
	- Answer		->		When dialogue is waiting for user to answer the question
	- Hold			->		When dialogue is on yield situation in dialogue story line.
	- Ready			->		When dialogue is ready for next text
	- Next			->		When dialogue is processing next dialogue
	- Done			->		When dialogue is doing its thing successfully
	- Interrupt		->		When dialogue got interrupted (Ex. Player died, Player leave, Unexpected error)
]]
local Idle, Texting, Skip, Answer, Hold, Ready, Next, Done, Interrupt = "Idle", "Texting", "Skip", "Answer", "Hold", "Ready", "Next", "Done", "Interrupt"


---- Custom Data Types ----

type Function = {
	Function : Function
}


---- Local Function To Handle Dialogue Story Line ----

local function __requireModule(Module : ModuleScript)
	assert(Module:IsA("ModuleScript"), "Can't require an instance of type " .. typeof(Module))
	return require(Module)
end


---- Local Function To Init New Events ----

local function __init__Events(Script)
	local EventList = {}
	for _, dialogueSection in Script do
		if dialogueSection.Event then
			table.insert(EventList, dialogueSection.Event)
		end
		if dialogueSection.Choices then
			local ChoicesEvent = __init__Events(dialogueSection.Choices)
			if ChoicesEvent[1] then
				table.insert(EventList, unpack(ChoicesEvent))
			end
		end
	end
	return EventList
end

---- Local Function To Init New Button Connection ----

local function __init__ButtonConnect(Button : GuiButton, Callback)
	return Button.MouseButton1Click:Connect(Callback)
end


---- Get Dialogue Object ----

function DialogueService.register(_NPC : Instance, _DialogueStory : ModuleScript)
	local self = setmetatable({}, DialogueService)

	self.Owner = if typeof(_NPC) ~= "Instance" then nil else _NPC

	self.ID = RandomService.Random_UID(10, Manager:getList())

	Manager:set(self)

	self.DialogueScript = __requireModule(_DialogueStory)
	self.DialogueIndex = 1

	self.Player = nil
	self.CurrentPlayerSpeed = 0
	self.Gui = nil

	self.ContinueButton = nil
	self.ChoicesButton = {}

	self.Events = {}

	self.Listeners = {}
	self.__handleConnections = {}

	self.CurrentNPCName = ""
	self.State = Idle
	
	self.CameraPoint = nil

	debug:Log(1, ("New dialogue of ID::%s created!"):format(self.ID or ""))
	return self
end

function DialogueService:init()
	if not self.Player then 
		debug:Log(2, "Player cannot be founded. Please do self:setPlayer()")
		return false
	end

	local _Player : Player = self.Player

	self.CurrentPlayerSpeed = _Player.Character.Humanoid.WalkSpeed

	if not _Player.PlayerGui:FindFirstChild(Settings.DialogueGuiName) then
		self:setupGui()
	end

	local EventsList = __init__Events(self.DialogueScript)

	for _, Event in EventsList do
		self:__newEvent(Event)
	end

	local unexpectedHandler = self.__handleConnections
	if not unexpectedHandler["OnPlayerDied"] then
		local diedConnection = _Player.Character.Humanoid.Died:Connect(function()
			debug:Log(2,("Player died! Interrupt current dialogue ID::%s"):format(self.ID))
			self.State = Interrupt
		end)
		unexpectedHandler["OnPlayerDied"] = diedConnection
		debug:Log(2, "Player died connection created.")
	end
	if not unexpectedHandler["OnPlayerLeave"] then
		local leaveConnection = _Player:GetPropertyChangedSignal("Parent"):Connect(function()
			debug:Log(2, ("Player is leaved! Destroy current dialogue ID::%s"):format(self.ID))
			self.State = Interrupt
			self:Destroy()
		end)
		unexpectedHandler["OnPlayerLeave"] = leaveConnection
		debug:Log(2, "Player leave connection created.")
	end

	self.State = Idle

	debug:Log(1, ("Init the dialogue for ID::%s"):format(self.ID))
	return true
end

function DialogueService:setupGui()
	self.State = Interrupt

	local oldGui = self.Player.PlayerGui:FindFirstChild(Settings.DialogueGuiName)
	if oldGui then oldGui:Destroy() end

	local newGui = DialogueTemplate:Clone()
	newGui.Name = Settings.DialogueGuiName
	newGui.Enabled = true

	self.Gui = newGui
	self.ContinueButton = newGui.Main["ContinueBtn"]

	newGui.Parent = self.Player.PlayerGui

	self.State = Idle
end

function DialogueService:setPlayer(_Player : Player)
	if not _Player then
		debug:Log(2, "Argument _Player can't be missed.")
		return false
	end

	if not Players:FindFirstChild(tostring(_Player)) then
		debug:Log(2, ("Attempt to find _Player. Player expected, got %s"):format(typeof(_Player)))
		return false
	end

	self.Player = _Player

	debug:Log(1, ("Sucessfully set player for dialogue ID::%s"):format(self.ID))
	return true
end

function DialogueService:setCameraPoint(CameraPoint : Instance)
	if not CameraPoint then
		debug:Log(2, "Argument CameraPoint can't be missed.")
		return false
	end
	
	if CameraPoint.ClassName ~= "Part" then
		debug:Log(2, "Attempt to setup CameraPoint. BasePart expected, got::" .. CameraPoint.ClassName)
		return
	end
	
	self.CameraPoint = CameraPoint
end

function DialogueService:startDialogue()
	spawn(function()
		if self.State ~= Idle then
			debug:Log(2, "Dialogue is currently running.")
			return
		end

		local Gui = self.Gui

		if not Gui then
			debug:Log(2, "Gui is not setup yet! Use self:setupGui() first.")
			return
		end
		local pressEsound = script.clicksound4
		pressEsound:Play()
		local MainFrame = Gui.Main
		local DialogueLabel = MainFrame.TextSection
		local NameLabel = MainFrame.NameBackground.TextSection
		local ChoicesSection = MainFrame.ChoicesSection

		-- Making connection for Continue Button
		local __buttonConnectionCooldown = false
		self.ContinueButton = __init__ButtonConnect(self.ContinueButton, function()
			if not __buttonConnectionCooldown then
				__buttonConnectionCooldown = true

				if self.State == Texting then
					self.State = Skip
					TextAnimator.Brake()
				elseif self.State == Ready then
					self.State = Next
				end

				-- Cooldown button
				task.wait(Settings.ContinueCooldown)
				__buttonConnectionCooldown = false
			end
		end)
		
		-- Check if setting is using zoom camera
		local DialogueRemote : RemoteEvent
		if Settings.ZoomInCamera then
			debug:Log(2, "ZoomInCamera is enabled!")

			if not self.CameraPoint then
				debug:Log(2, "CameraPoint is not setup yet! Please use self:setCameraPoint()")
				Gui:Destroy()
				return
			end

			local IsClientSetupCheck = DialogueMaterialsFolder.IsClientSetup.Value

			if not IsClientSetupCheck then
				debug:Log(2, "Client-side for camera zoom is not setup yet!")
				Gui:Destroy()
				return
			end

			if not self.Owner.Head then
				debug:Log(2, "NPC Head not found! Please name the reference point on npc to \"Head\"")
				Gui:Destroy()
				return
			end

			DialogueRemote = DialogueMaterialsFolder.DialogueRemote
			DialogueRemote:FireClient(self.Player, true, self.CameraPoint, self.Owner.Head)
		end

		-- Check if setting want player to be freezed or not
		if Settings.FreezePlayer then
			self.Player.Character.Humanoid.WalkSpeed = 0

			self:onEndedConnect(function()
				self.Player.Character.Humanoid.WalkSpeed = self.CurrentPlayerSpeed
			end)
		end

		debug:Log(1, "Start displaying dialogue!")

		-- Repeat displaying the dialogue text
		repeat
			self.State = Texting

			local Index = self.DialogueIndex

			-- Check if dialogue is ended
			if Index == -1 then
				self.State = Done
				continue
			end

			-- All dialogue properties
			local CurrentDialogue = self.DialogueScript[Index]
			local CurrentName = CurrentDialogue.Name
			local CurrentMessage = CurrentDialogue.Message
			local CurrentEvent = CurrentDialogue.Event
			local CurrentChoices = CurrentDialogue.Choices
			local IsEnded = CurrentDialogue.Ended
			local HoldDuration = CurrentDialogue.Hold

			-- Checking NPC name
			if not CurrentName then
				self.CurrentNPCName = self.Owner.Name
			elseif CurrentName then
				if CurrentName:match("#") then
					self.CurrentNPCName = self:__formatName("#PLAYER", CurrentName)
				else
					self.CurrentNPCName = CurrentName
				end
			end
			NameLabel.Text = self.CurrentNPCName

			-- Checking displaying text
			if CurrentMessage:match("#") then
				CurrentMessage = self:__formatName("#PLAYER", CurrentMessage)
			end

			-- Dialogue Texting Animator
			TextAnimator.Animate(DialogueLabel, CurrentMessage, Settings.TextDisplayDelay)

			-- Trigger Event (If Exist)
			if CurrentEvent then
				if not self.Events[CurrentEvent] then
					debug:Log(2, ("Error! Couldn't find event::%s"):format(CurrentEvent))
					debug:Log(2, " This is an unexpected situation, please check the code immediately.")
					self.State = Interrupt
					continue
				end
				self.Events[CurrentEvent]:Fire()
			end

			-- Check if current dialogue is triggering ending event
			if IsEnded then
				task.wait(Settings.DialogueEndedHoldTime)
				self.State = Interrupt
				continue
			end

			-- Check if current dialogue contains choices
			if CurrentChoices then
				self.State = Answer

				local ChoiceTemplate = ChoicesSection:FindFirstChild("Template")

				for _index, _choice in pairs(CurrentChoices) do
					local temp = ChoiceTemplate:Clone()
					temp.Name = "Answer" .. tostring(_index)

					local event = _choice.Event

					-- Set text and connection for answer button

					-- Checking displaying text
					if _choice.Message:match("#") then
						_choice.Message = self:__formatName("#PLAYER", _choice.Message)
					end

					local answerBtn = temp.ChoiceBtn
					answerBtn.Text = _choice.Message
					__init__ButtonConnect(answerBtn, function()
						self.DialogueIndex = _choice.Goto - 1 -- To make self:__nextDialogue() work correctly

						-- In case user put event to answer choices
						if event then
							self.Events[event]:Fire()
						end

						-- Destroy all answer choices after user has answered
						for _, answerList in pairs(ChoicesSection:GetChildren()) do
							if answerList.ClassName == "Frame" and answerList.Name ~= "Template" then
								answerList:Destroy()
							end
						end

						self.State = Next
					end)

					self.ChoicesButton[Index] = temp

					temp.Parent = ChoicesSection
					temp.Visible = true
				end
			else
				-- Set dialogue state to Ready (Put in else because of choices)
				self.State = Ready
			end

			-- Check if user is input hold or not
			if HoldDuration then
				self.State = Hold
				task.wait(HoldDuration)
				self.State = Ready
			end

			-- Wait until state is Next (User press continue button)
			repeat
				task.wait()
			until self.State == Next

			-- Go to next dialogue
			self:__nextDialogue()
		until self.State == Done or self.State == Interrupt

		if self.State == Done then
			debug:Log(1, "Dialogue finished!")
		elseif self.State == Interrupt then
			debug:Log(2, "Dialogue got interrupted. Stop displaying.")
		else
			debug:Log(2, ("Got an unexpected dialogue State::%s"):format(self.State))
		end

		Gui:Destroy()
		
		if DialogueRemote then
			DialogueRemote:FireClient(self.Player, false)
		end

		task.wait(.001) -- Yield script for connection to check
		self.State = Idle
	end)
end

function DialogueService:__nextDialogue()
	local TotalDialogue = #self.DialogueScript
	local CurrentDialogue = self.DialogueIndex

	if CurrentDialogue < TotalDialogue then
		self.DialogueIndex += 1
	else
		self.DialogueIndex = -1
	end

	return self.DialogueIndex
end

function DialogueService:__formatName(Pattern : string, Text : string)
	return Text:gsub(Pattern, self.Player.Name)
end

function DialogueService:__newEvent(ConnectionID : string)
	if self.Events[ConnectionID] then
		debug:Log(2, ("Event ID::%s already exist."):format(ConnectionID))
	end
	local Bindable = Instance.new("BindableEvent")

	self.Events[ConnectionID] = Bindable
	self.Listeners[ConnectionID] = Bindable.Event

	debug:Log(1, ("Create connection::%s on dialogue ID::%s"):format(ConnectionID, self.ID))
end

function DialogueService:onEventConnect(ConnectionID : string, Callback : Function)
	if typeof(Callback) ~= "function" then
		debug:Log(2, ("Callback Function can't be : %s"):format(typeof(Callback)))
		return false
	end

	local event = self.Listeners[ConnectionID]

	if not event then
		debug:Log(2, ("Attempt to get connection of ID::%s (Not Found)"):format(tostring(ConnectionID)))
		return false
	end

	if typeof(event) == "RBXScriptConnection" then
		debug:Log(2, ("Event::%s is already connect to other method, please disconnect first."):format(ConnectionID))
		return false
	end

	local newConnection = event:Connect(Callback)
	self.Listeners[ConnectionID] = newConnection

	debug:Log(1, ("Make event connection for event::%s"):format(ConnectionID))

	return true
end


function DialogueService:onEndedWait()
	return (function()
		repeat
			task.wait()
		until self.State == Done or self.State == Interrupt
	end)()
end

function DialogueService:onEndedConnect(callBack, ...)
	return task.spawn(function(...)
		repeat
			task.wait()
		until self.State == Done or self.State == Interrupt
		callBack(...)
	end, ...)
end

function DialogueService:onCompletedWait()
	return (function()
		repeat
			task.wait()
		until self.State == Done
	end)()
end

function DialogueService:onCompletedConnect(callBack, ...)
	return task.spawn(function(...)
		repeat
			task.wait()
		until self.State == Done
		callBack(...)
	end, ...)
end

function DialogueService:destroy()
	for _, events in pairs(self.Listeners) do
		if typeof(events) == "RBXScriptConnection" then
			events:Disconnect()
		end
	end
	debug:Log(2, ("Event listeners for dialogue ID::%s disconnected."):format(self.ID))

	for _, events in pairs(self.__handleConnections) do
		if typeof(events) == "RBXScriptConnection" then
			events:Disconnect()
		end
	end
	debug:Log(2, ("Unexpected event listeners for dialogue ID::%s disconnected."):format(self.ID))

	if typeof(self.ContinueButton) == "RBXScriptConnection" then
		self.ContinueButton:Disconnect()
	end
	debug:Log(2, ("Continue Button for dialogue ID::%s disconnected."):format(self.ID))

	debug:Log(2, ("Dialogue ID::%s destroyed"):format(self.ID))
	Manager:remove(self.ID)

	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)

	return true
end

--setmetatable(DialogueService, {
--	__index = function(tabl, method)
--		debug:Log(3, ("Attempt to call the method::%s (missing method in object)"):format(tostring(method)))
--	end,
--	__newindex = function(tabl, method, value)
--		debug:Log(3, ("Attempt to assign the method::%s (missing method in object)"):format(tostring(method)))
--	end,
--})

if RunService:IsServer() then
	return DialogueService
else
	return debug:Log(3, "DialogueService can't be required from client-side.")
end
