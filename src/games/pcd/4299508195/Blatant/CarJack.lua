local CarJack
run(function()
	local AutoDrive
	local AutoThrottle
	local Mode
	local Range
	local hijackLoop, driveLoop

	local function getNearestCar()
		if not workspace.Cars then return nil end
		local root = entitylib.isAlive and entitylib.character.RootPart
		if not root then return nil end

		local nearest, nearestDist = nil, Range.Value
		for _, car in pairs(workspace.Cars:GetChildren()) do
			local seat = car:FindFirstChild("DriveSeat", true) or car:FindFirstChildWhichIsA("VehicleSeat")
			if seat then
				local dist = (seat.Position - root.Position).Magnitude
				if dist < nearestDist then
					nearest = {car = car, seat = seat}
					nearestDist = dist
				end
			end
		end
		return nearest
	end

	local function getCarByOwner(name)
		if not workspace.Cars then return nil end
		local car = workspace.Cars:FindFirstChild(name)
		if not car then return nil end
		local seat = car:FindFirstChild("DriveSeat", true) or car:FindFirstChildWhichIsA("VehicleSeat")
		if not seat then return nil end
		return {car = car, seat = seat}
	end

	local function hijack(carData)
		if not carData then return false end
		local hum = entitylib.isAlive and entitylib.character.Humanoid
		if not hum then return false end
		hum.Sit = true
		carData.seat:Sit(hum)
		return hum.Sit
	end

	local function startAutoDrive()
		if driveLoop then driveLoop:Disconnect() end
		driveLoop = runService.Heartbeat:Connect(function()
			for _, car in pairs(workspace.Cars:GetChildren()) do
				local seat = car:FindFirstChild("DriveSeat", true) or car:FindFirstChildWhichIsA("VehicleSeat")
				if seat and seat.Occupant and seat.Occupant.Parent == lplr.Character then
					seat.Throttle = AutoThrottle.Value
					seat.Steer = 0
				end
			end
		end)
	end

	CarJack = vape.Categories.Blatant:CreateModule({
		Name = 'CarJack',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Auto' then
					hijackLoop = runService.Heartbeat:Connect(function()
						if entitylib.isAlive and entitylib.character.Humanoid and not entitylib.character.Humanoid.Sit then
							local carData = getNearestCar()
							if carData then
								hijack(carData)
							end
						end
					end)
				end

				if AutoDrive.Enabled then
					startAutoDrive()
				end

				CarJack:Clean(hijackLoop or runService.Heartbeat:Connect(function() end))
				CarJack:Clean(driveLoop or runService.Heartbeat:Connect(function() end))
			else
				if hijackLoop then hijackLoop:Disconnect() end
				if driveLoop then driveLoop:Disconnect() end
				hijackLoop, driveLoop = nil, nil
			end
		end,
		Tooltip = 'Steal cars from other players.'
	})

	Mode = CarJack:CreateDropdown({
		Name = 'Mode',
		List = {'Manual', 'Auto'},
		Tooltip = 'Manual - Hijack nearest car once on toggle\nAuto - Continuously hijack nearest empty seat'
	})

	Range = CarJack:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 200,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AutoThrottle = CarJack:CreateSlider({
		Name = 'Throttle',
		Min = -1,
		Max = 1,
		Decimal = 100,
		Default = 1,
		Suffix = function(val)
			return tostring(math.floor(val * 100)) .. '%'
		end
	})

	AutoDrive = CarJack:CreateToggle({
		Name = 'Auto Drive',
		Default = true,
		Tooltip = 'Automatically floor the throttle after hijacking'
	})
end)
