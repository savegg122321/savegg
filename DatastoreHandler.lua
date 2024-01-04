--[[

DS_ERR_000 - Profile not found.
DS_ERR_001 - Profile released.

]]

-- Variables
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ProfileService = require(ServerStorage:WaitForChild("Scripts")["Utilities"]["Services"]:FindFirstChild("ProfileService"))
local debug = require(game.ServerStorage:WaitForChild("Scripts")["Utilities"]["Tools"]:FindFirstChild("savegg's tools")).debug.new()

debug:SetName("Data Handler")
debug:Toggle(script:GetAttribute("Debug")) -- TURN DEBUG MODE ON OR OFF

local Templates = require(script:WaitForChild("Templates"))
local Manager = require(script:WaitForChild("Manager"))
local Settings = require(script:WaitForChild("Settings"))

local DatastoreHandler = {}
local ProfileStore = ProfileService.GetProfileStore(Settings.MAIN_DATASTORE_NAME, Templates)

-- Functions
function PlayerAdded(_PLR : Player)
	debug:StartTimer()
	
	debug:Log(2, "Player's joining...")
	local _DATA_KEY = Settings.DATA_KEY_FORMAT .. _PLR.UserId
	local _PROFILE = ProfileStore:LoadProfileAsync(_DATA_KEY)
	debug:Log(1, ("Successfully loaded %s's profile."):format(_PLR.Name))
	
	if not _PROFILE then
		debug:Log(3, ("Error while loading profile! Got nil."))
		
		_PLR:Kick([[Error encountered while trying to load the data, 
		please try again shortly. 
		If the error persists, contact the developer team.
		CODE : DS_ERR_000]])
		
		return
	end
	
	_PROFILE:AddUserId(_PLR.UserId)
	_PROFILE:Reconcile()
	_PROFILE:ListenToRelease(function()
		debug:Log(1, "Profile Released.")
		
		Manager:Remove(_PLR)
		
		_PLR:Kick([[You were kicked from the game due to data issue, 
		please try to rejoin again shortly. 
		If the error persists, contact the developer team.
		CODE : DS_ERR_001]])
	end)
	
	if _PLR:IsDescendantOf(Players) then
		
		Manager:Add(_PLR, _PROFILE)
		
		Manager:MakeDataFolder(_PLR, Settings.DATA_FOLDER_NAME)
		
		debug:Log(2, "Data is successfully loaded.")
		
		_PLR:SetAttribute("DataLoaded", true)
		
		debug:Log(2, ("Took a total of %.2f seconds to load data."):format(debug:StopTimer()))
	else
		_PROFILE:Release()
	end
end

function PlayerRemoving(_PLR : Player)
	debug:Log(2, "Player's leaving...")
	local _PROFILE = Manager:GetProfile(_PLR)
	
	if not _PROFILE then return end
	
	_PROFILE:Release()
end

function DatastoreHandler.Init()
	-- Handle case that player joins the server before Data-Handler script is loaded.
	debug:Log(2, "Initializing data handler...")
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerAdded, player)
	end
	
	-- Make connections
	debug:Log(2, "Making connections...")
	Players.PlayerAdded:Connect(PlayerAdded)
	Players.PlayerRemoving:Connect(PlayerRemoving)
	
	debug:Log(2, "Successfully init the data handler.")
	script:SetAttribute("IsServiceReady", true)
end

return DatastoreHandler
