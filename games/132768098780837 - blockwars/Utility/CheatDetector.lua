local Detector
local SpeedSlider
local flagged = {}
local highlights = {}

local function flagPlayer(plr)
	if flagged[plr] then return end
	flagged[plr] = true
	vape:CreateNotification('Cheat Detector', plr.Name..' is cheating (speed)', 5, 'alert')
end

local function clearPlayer(plr)
	flagged[plr] = nil
	local hl = highlights[plr]
	if hl then
		hl:Destroy()
		highlights[plr] = nil
	end
end

local function clearAll()
	local keys = {}
	for plr in highlights do
		table.insert(keys, plr)
	end
	for _, plr in keys do
		clearPlayer(plr)
	end
	table.clear(flagged)
end

local function refreshHighlight(plr, hue)
	local char = plr.Character
	if not char then
		clearPlayer(plr)
		return
	end
	local hl = highlights[plr]
	if not hl or hl.Parent ~= char then
		if hl then
			hl:Destroy()
		end
		hl = Instance.new('Highlight')
		hl.FillTransparency = 0.35
		hl.OutlineTransparency = 0
		hl.Parent = char
		highlights[plr] = hl
	end
	hl.FillColor = Color3.fromHSV(hue % 1, 1, 1)
end

Detector = vape.Categories.Utility:CreateModule({
	Name = 'Cheat Detector',
	Function = function(callback)
		if callback then
			local samples = {}

			Detector:Clean(runService.Heartbeat:Connect(function()
				local hue = tick() % 1
				for plr in flagged do
					refreshHighlight(plr, hue + plr.UserId % 10 / 10)
				end
			end))

			Detector:Clean(playersService.PlayerRemoving:Connect(clearPlayer))

			Detector:Clean(bw.RemoteIndex.Victory_Show.OnClientEvent:Connect(clearAll))

			task.spawn(function()
				repeat
					task.wait(0.4)
					if not Detector.Enabled then break end
					local now = tick()
					for _, ent in entitylib.List do
						local plr = ent.Player
						if not plr or plr == lplr or not ent.RootPart or flagged[plr] then
							continue
						end
						local pos = ent.RootPart.Position * Vector3.new(1, 0, 1)
						local sample = samples[plr]
						if sample then
							local speed = (pos - sample.pos).Magnitude / (now - sample.time)
							if speed > SpeedSlider.Value then
								local streak = sample.streak + 1
								if streak >= 3 then
									flagPlayer(plr)
								else
									samples[plr] = {pos = pos, time = now, streak = streak}
								end
							else
								samples[plr] = {pos = pos, time = now, streak = 0}
							end
						else
							samples[plr] = {pos = pos, time = now, streak = 0}
						end
					end
				until not Detector.Enabled
				table.clear(samples)
			end)
		else
			clearAll()
		end
	end,
	Tooltip = 'Detects players moving faster than physically possible (sustained speed above the threshold) and highlights them in rainbow for the rest of the match.'
})
SpeedSlider = Detector:CreateSlider({
	Name = 'Speed threshold',
	Min = 25,
	Max = 100,
	Default = 40,
	Suffix = ' studs/s'
})
