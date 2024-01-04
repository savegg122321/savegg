local Signals = {}
Signals.__index = Signals

type callBackFunction = {
	Function
}

type parametersList = {
	parameters : string
}

function Signals.new()
	local self = setmetatable({}, Signals)
	
	self.bindable = Instance.new("BindableEvent")
	
	self.argumentList = {}
	self.argumentCount = 0
	
	self.currentEvents = {}
	
	return self
end

function Signals:fire()
	return self.bindable:Fire()
end

function Signals:wrap(callBack : callBackFunction, ... : parametersList)
	task.spawn(function(...)
		assert(typeof(callBack) == "function", ("Attempt to call a %s type instead of function"):format(typeof(callBack)))

		self.argumentCount = #{...} or 0
		self.argumentList = {...}

		local results = {pcall(callBack, table.unpack(self.argumentList))}

		if results[1] then
			self.bindable:Fire(results)
		else
			self.bindable:Fire(nil)
		end

		return
	end, ...)
end

function Signals:connect(callBack : callBackFunction)
	assert(typeof(callBack) == "function", ("Attempt to connect a %s type instead of function"):format(typeof(callBack)))
	
	table.insert(self.currentEvents, self.bindable.Event:Connect(callBack))
end

function Signals:wait()
	return self.bindable.Event:Wait()
end

function Signals:getEvents(index : number)
	return self.currentEvents[index] or {}
end

function Signals:destroy()
	for _, events in pairs(self.currentEvents) do
		events:Disconnect()
	end
	
	setmetatable(self, nil)
	table.clear(self)
	table.freeze(self)
	
	return true
end

return Signals
