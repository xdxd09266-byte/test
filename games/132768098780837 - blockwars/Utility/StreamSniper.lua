local StreamSniper
local WhitelistList
local NotifyJoin
local AutoQueueToggle
local track
local tracked = {}
local notified = {}
local resolvedIds = {}
local resolvedEntries = {}
local resolvedNames = {}
local failedAt = {}
local httpService = cloneref(game:GetService('HttpService'))
local headers = {
	['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
}

local function persistCache()
	pcall(function()
		writefile('weedhack/streamsniper_cache.txt', httpService:JSONEncode(resolvedEntries))
	end)
end

local function loadCache()
	pcall(function()
		if isfile and isfile('weedhack/streamsniper_cache.txt') then
			local data = httpService:JSONDecode(readfile('weedhack/streamsniper_cache.txt'))
			if type(data) == 'table' then
				for k, v in data do
					resolvedEntries[k] = v
					if type(v) == 'number' then
						resolvedIds[v] = true
					end
				end
			end
		end
	end)
end

local function fetchUser(id)
	local ok, res = pcall(function()
		return game:HttpGet('https://users.roblox.com/v1/users/'..id, true, headers)
	end)
	if ok and res then
		local ok2, data = pcall(function()
			return httpService:JSONDecode(res)
		end)
		if ok2 and type(data) == 'table' and data.id then
			resolvedIds[data.id] = true
			if data.name then
				resolvedNames[data.id] = data.name
			end
			return data
		end
	end
	return nil
end

local function isWhitelisted(plr)
	local name = plr.Name:lower()
	local display = plr.DisplayName:lower()
	for _, v in WhitelistList.ListEnabled do
		local entry = tostring(v)
		local low = entry:lower()
		if low == name or low == display then
			return true
		end
		local id = tonumber(entry)
		if id and id == plr.UserId then
			return true
		end
	end
	return resolvedIds[plr.UserId] == true
end

local function resolveEntries(notify)
	local pending = {}
	for _, v in WhitelistList.ListEnabled do
		local entry = tostring(v)
		if resolvedEntries[entry] ~= nil then continue end
		local id = tonumber(entry)
		if id then
			resolvedEntries[entry] = id
			if not fetchUser(id) then
				resolvedIds[id] = true
			end
		else
			if (failedAt[entry] or 0) + 60 < os.clock() then
				table.insert(pending, entry)
			end
		end
	end

	if #pending == 0 then
		if notify then
			vape:CreateNotification('Stream Sniper', 'Whitelist active', 3)
		end
		return
	end

	task.spawn(function()
		local resolved = 0
		for _, entry in pending do
			if resolvedEntries[entry] ~= nil then continue end
			local ok, res = pcall(function()
				return game:HttpGet('https://users.roblox.com/v1/users/search?keyword='..httpService:UrlEncode(entry)..'&limit=10', true, headers)
			end)
			local low = entry:lower()
			if ok and res then
				local ok2, data = pcall(function()
					return httpService:JSONDecode(res)
				end)
				if ok2 and type(data) == 'table' and data.data then
					for _, user in data.data do
						local uname = (user.name or ''):lower()
						local dname = (user.displayName or ''):lower()
						if uname == low or dname == low then
							resolvedEntries[entry] = user.id
							resolvedIds[user.id] = true
							resolvedNames[user.id] = user.name
							resolved += 1
							break
						end
					end
				end
			end
			if resolvedEntries[entry] == nil then
				failedAt[entry] = os.clock()
			end
			task.wait(1.5)
		end
		persistCache()
		for _, plr in playersService:GetPlayers() do
			if plr ~= lplr then
				track(plr, true)
			end
		end
		if notify and resolved > 0 then
			vape:CreateNotification('Stream Sniper', 'Whitelist resolved '..resolved..' users', 4)
		end
	end)
end

local function canQueue()
	if lplr:GetAttribute('Searching') then
		return false
	end
	if workspace:GetAttribute('ServerType') == 'Lobby' then
		return true
	end
	local ok, state = pcall(function()
		return bw.RemoteIndex.Matchmaking_Request:InvokeServer('status')
	end)
	if not ok or type(state) ~= 'table' then
		return false
	end
	local st = state.state
	if st == 'searching' or st == 'matched' or st == 'partyAlive' or st == 'partyMember' then
		return false
	end
	return true
end

local function queueFor(plr)
	if not canQueue() then return end
	local ok, state = pcall(function()
		return bw.RemoteIndex.Matchmaking_Request:InvokeServer('queue')
	end)
	if not ok then return end
	if type(state) == 'table' and state.state == 'searching' then
		vape:CreateNotification('Stream Sniper', 'Auto-queued to match '..plr.Name, 5)
	end
end

track = function(plr, force)
	if plr == lplr then return end
	if not isWhitelisted(plr) then
		if not tracked[plr] then
			resolveEntries(false)
		end
		return
	end
	if tracked[plr] and not force then return end
	if not notified[plr] then
		notified[plr] = true
		if NotifyJoin.Enabled then
			vape:CreateNotification('Stream Sniper', plr.Name..' joined the server', 5)
		end
	end
	if not tracked[plr] then
		tracked[plr] = plr:GetAttributeChangedSignal('Searching'):Connect(function()
			if plr:GetAttribute('Searching') then
				if NotifyJoin.Enabled then
					vape:CreateNotification('Stream Sniper', plr.Name..' is searching', 5)
				end
				if AutoQueueToggle.Enabled and isWhitelisted(plr) then
					queueFor(plr)
				end
			end
		end)
		StreamSniper:Clean(tracked[plr])
	end
	if AutoQueueToggle.Enabled and plr:GetAttribute('Searching') then
		queueFor(plr)
	end
end

StreamSniper = vape.Categories.Utility:CreateModule({
	Name = 'Stream Sniper',
	Function = function(callback)
		if callback then
			loadCache()
			resolveEntries(true)
			StreamSniper:Clean(playersService.PlayerAdded:Connect(track))
			StreamSniper:Clean(playersService.PlayerRemoving:Connect(function(plr)
				if tracked[plr] then
					tracked[plr]:Disconnect()
					tracked[plr] = nil
				end
			end))
			for _, plr in playersService:GetPlayers() do
				if plr ~= lplr then
					track(plr)
				end
			end
		else
			table.clear(tracked)
			table.clear(notified)
		end
	end,
	Tooltip = 'Fetches whitelisted users from the Roblox Users API (usernames, display names or user IDs all work). Notifies when they join or start searching, and auto-queues when they queue if you are in the lobby or at the end screen.'
})
NotifyJoin = StreamSniper:CreateToggle({Name = 'Notify join', Default = true})
AutoQueueToggle = StreamSniper:CreateToggle({Name = 'Auto queue', Default = true})
WhitelistList = StreamSniper:CreateTextList({
	Name = 'Whitelist',
	Default = {},
	Tooltip = 'Add usernames, display names or user IDs',
	Function = function()
		if not WhitelistList then return end
		table.clear(resolvedEntries)
		table.clear(resolvedIds)
		table.clear(resolvedNames)
		resolveEntries(false)
	end
})
