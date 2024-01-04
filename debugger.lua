--!strict
_G.Global_Debug_Enabled = script.Parent:GetAttribute("GlobalDebugEnabled")

warn("[ Debugger ] Current Global Debug Status is : " .. tostring(_G.Global_Debug_Enabled))

script.Parent:GetAttributeChangedSignal("GlobalDebugEnabled"):Connect(function()
	_G.Global_Debug_Enabled = script.Parent:GetAttribute("GlobalDebugEnabled")
	
	warn("[ Debugger ] Current Global Debug Status has changed to : " .. tostring(_G.Global_Debug_Enabled))
end)

local Queue = require(script.Parent:FindFirstChild("Queue"))

local Debug = {}
Debug.__index = Debug

type StackLevel = {
	number : "For debug level 3 only."
}

function Debug.new()
	local self = setmetatable({}, Debug)
	
	self.NAME = nil
	self.ENABLED = true
	self.LEVEL = {
		["1"] = print,
		["2"] = warn,
		["3"] = error,
	}
	self.USING_CALLBACK = false
	
	self.TimerList = Queue.new()
	return self
end

function Debug:Toggle(bool: boolean)
	if typeof(bool) ~= "boolean" then
		warn("[ Debug Toggle Error ] BOOLEAN EXPECTED! GOT : " .. tostring(typeof(bool)))
	end
	self.ENABLED = bool
end

function Debug:SetName(name: string)
	self.NAME = tostring(name)
end

function Debug:GetCallback(bool: boolean)
	if typeof(bool) ~= "boolean" then
		warn("[ Debug Callback Toggle Error ] BOOLEAN EXPECTED! GOT : " .. tostring(typeof(bool)))
	end
	self.USING_CALLBACK = bool
end

function Debug:Log(DebugLevel: number, Message: string, StackLevel : StackLevel)
	if not _G.Global_Debug_Enabled then return end
	
	if not self.ENABLED then return end
	
	if not self.LEVEL[tostring(DebugLevel)] then
		warn("[ Debug Error ] You type the \"DebugLevel\" wrong!")
		warn("[ Debug Error ] Please make sure you only type {1, 2, 3}")
		return 
	end
	local Header
	if self.NAME == nil then
		Header = "[ DEBUGGER ] "
	else
		Header = ("[ %s DEBUGGER ] "):format(self.NAME)
	end
	
	self.LEVEL[tostring(DebugLevel)](Header .. tostring(Message))
	
	if self.USING_CALLBACK then
		print("--------------- [ Callback ] ---------------")
		print(debug.traceback())
	end
end

function Debug:StartTimer()
	if not _G.Global_Debug_Enabled then return end
	
	if not self.ENABLED then return end
	
	self.TimerList:push(tick())
end

function Debug:StopTimer()
	if not _G.Global_Debug_Enabled then return 0 end
	
	if not self.ENABLED then return 0 end
	
	local CurrentTime = tick()
	local TotalTime = CurrentTime - self.TimerList:peek()
	self.TimerList:pop()
	
	return TotalTime
end

function Debug:Destroy()
	
	self.TimerList:Destroy()
	
	table.clear(self)
	table.freeze(self)
	
	setmetatable(self, nil)

	return true
end

setmetatable(Debug, {
	__index = function(tabl, method)
		error("Attempt to call the method::%s (missing method in object)"):format(tostring(method))
	end,
	__newindex = function(tabl, method, value)
		error("Attempt to assign the method::%s (missing method in object)"):format(tostring(method))
	end,
})

return Debug
