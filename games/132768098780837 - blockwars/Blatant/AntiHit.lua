local AntiHit
local RangeSlider
local SpeedSlider
local BounceSlider
local DepthSlider

local function getIgnore()
	local ignore = {gameCamera, entitylib.character.Character}
	for _, ent in entitylib.List do
		if ent.Character then
			table.insert(ignore, ent.Character)
		end
	end
	return ignore
end

local function getDiveY(root, params)
	-- top surface of the map
	local top = workspace:Raycast(root.Position + Vector3.new(0, 50, 0), Vector3.new(0, -400, 0), params)
	local topY = top and top.Position.Y or root.Position.Y

	-- walk down looking for a pocket that fully fits the character
	local probe = topY - 3
	while probe > topY - 60 do
		local up = workspace:Raycast(Vector3.new(root.Position.X, probe + 2, root.Position.Z), Vector3.new(0, 8, 0), params)
		local down = workspace:Raycast(Vector3.new(root.Position.X, probe - 2, root.Position.Z), Vector3.new(0, -8, 0), params)

		local ceilingY = up and up.Position.Y or probe + 10
		local floorY = down and down.Position.Y or probe - 10

		if ceilingY > probe + 3.5 and floorY < probe - 2.5 then
			return probe, ceilingY, floorY
		end
		probe -= 2
	end

	return topY - DepthSlider.Value, math.huge, -math.huge
end

local function hasMelee(char)
	for _, child in char:GetChildren() do
		if child:IsA('Tool') and child:GetAttribute('WeaponType') then
			return true
		end
	end
	return false
end

local function threatNear(me)
	for _, ent in entitylib.List do
		if not ent.Targetable or not ent.RootPart or not ent.Character then
			continue
		end
		if (ent.RootPart.Position - me).Magnitude > RangeSlider.Value then
			continue
		end
		if hasMelee(ent.Character) then
			return true
		end
	end
	return false
end

AntiHit = vape.Categories.Blatant:CreateModule({
	Name = 'Anti Hit',
	Function = function(callback)
		if callback then
			local under = false
			local original, anchor, ceiling, floor, goingUp
			local lastBounce = 0

			AntiHit:Clean(function()
				if under then
					pcall(function()
						local root = entitylib.isAlive and entitylib.character.RootPart
						if root then
							root.CFrame = original
							root.AssemblyLinearVelocity = Vector3.zero
						end
					end)
				end
				under = false
			end)

			AntiHit:Clean(runService.Heartbeat:Connect(function()
				if not entitylib.isAlive then
					under = false
					return
				end

				local root = entitylib.character.RootPart
				local threatened = threatNear(root.Position)

				if threatened and not under then
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = getIgnore()
					local diveY, cY, fY = getDiveY(root, params)
					original = root.CFrame
					anchor, ceiling, floor = diveY, cY, fY
					goingUp, lastBounce = true, 0
					root.CFrame = CFrame.new(original.Position.X, anchor, original.Position.Z) * original.Rotation
					root.AssemblyLinearVelocity = Vector3.zero
					under = true
				end

				if under then
					if MethodSlider.Value == 'Up/Down' then
						local interval = 1 / math.max(SpeedSlider.Value, 0.1)
						if os.clock() - lastBounce >= interval then
							lastBounce = os.clock()
							local bounce = math.min(BounceSlider.Value, ceiling - anchor - 3.5, anchor - floor - 2.5)
							bounce = math.max(bounce, 0.5)
							local ny = goingUp and (anchor + bounce) or (anchor - bounce)
							root.CFrame = CFrame.new(original.Position.X, ny, original.Position.Z) * original.Rotation
							root.AssemblyLinearVelocity = Vector3.zero
							goingUp = not goingUp
						end
					end

					if not threatened then
						root.CFrame = original
						root.AssemblyLinearVelocity = Vector3.zero
						under = false
					end
				end
			end))
		end
	end,
	Tooltip = 'When enemies with melee weapons are near, sinks into an air pocket under the map and either stays under or teleports up and down (see Method) so server-side hitchecks miss. Disabling snaps you back up.'
})

MethodSlider = AntiHit:CreateDropdown({
	Name = 'Method',
	List = {'Up/Down', 'Under Map'},
	Default = 'Up/Down'
})
RangeSlider = AntiHit:CreateSlider({
	Name = 'Range',
	Min = 6,
	Max = 24,
	Default = 13,
	Suffix = 'studs'
})
SpeedSlider = AntiHit:CreateSlider({
	Name = 'Speed',
	Min = 1,
	Max = 10,
	Default = 5,
	Suffix = 'tps/s'
})
BounceSlider = AntiHit:CreateSlider({
	Name = 'Bounce',
	Min = 1,
	Max = 8,
	Default = 4,
	Suffix = 'studs'
})
DepthSlider = AntiHit:CreateSlider({
	Name = 'Depth',
	Min = 5,
	Max = 30,
	Default = 12,
	Suffix = 'studs'
})
