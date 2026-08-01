local Fly
run(function()
	local Value
	local VerticalValue
	local SpeedLimit
	local FloatMode
	local AutoSteer
	local Keys
	local up, down = 0, 0
	local seat, seatConnection

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			if callback then
				up, down = 0, 0

				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						local moveDirection = entitylib.character.Humanoid.MoveDirection
						local mode = FloatMode.Value

						if mode == 'Vehicle' then
							if not seat or not seat.Parent then
								seat = Instance.new('VehicleSeat')
								seat.Anchored = false
								seat.CanCollide = false
								seat.Transparency = 1
								seat.CFrame = root.CFrame
								seat.Parent = workspace
								seat:Sit(entitylib.character.Humanoid)
							end

							local vel = moveDirection * Value.Value
							seat.Velocity = Vector3.new(vel.X, (up + down) * VerticalValue.Value, vel.Z)
						elseif mode == 'CFrame' then
							local targetY = root.Position.Y + ((up + down) * VerticalValue.Value * dt)
							local destination = moveDirection * Value.Value * dt
							root.CFrame += Vector3.new(destination.X, targetY - root.Position.Y, destination.Z)
							root.Velocity *= Vector3.new(1, 0, 1)
						elseif mode == 'Velocity' then
							local vel = moveDirection * Value.Value
							root.AssemblyLinearVelocity = Vector3.new(vel.X, (up + down) * VerticalValue.Value + 2.25, vel.Z)
						end
					end
				end))

				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						local divided = Keys.Value:split('/')
						if input.KeyCode == Enum.KeyCode[divided[1]] then
							up = 1
						elseif input.KeyCode == Enum.KeyCode[divided[2]] then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					local divided = Keys.Value:split('/')
					if input.KeyCode == Enum.KeyCode[divided[1]] then
						up = 0
					elseif input.KeyCode == Enum.KeyCode[divided[2]] then
						down = 0
					end
				end))

				Fly:Clean(entitylib.character:GetPropertyChangedSignal('Parent'):Connect(function()
					pcall(function() seat:Destroy() end)
				end))
			else
				if seat then
					pcall(function() seat:Destroy() end)
					seat = nil
				end

				if entitylib.isAlive then
					entitylib.character.Humanoid.WalkSpeed = 16
					entitylib.character.RootPart.Velocity = Vector3.zero
				end
			end
		end,
		ExtraText = function()
			return FloatMode.Value
		end,
		Tooltip = 'Undetected fly for PCD.'
	})

	FloatMode = Fly:CreateDropdown({
		Name = 'Mode',
		List = {'Vehicle', 'CFrame', 'Velocity'},
		Function = function()
			if seat then
				pcall(function() seat:Destroy() end)
				seat = nil
			end
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = 'Vehicle - Creates a hidden seat (mimics car physics, safest)\nCFrame - Gentle position adjustment\nVelocity - Body velocity based movement'
	})

	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 50,
		Default = 25,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 30,
		Default = 10,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	Keys = Fly:CreateDropdown({
		Name = 'Keys',
		List = {'Space/LeftShift', 'Space/LeftControl', 'E/Q', 'Space/Q'},
		Default = 1,
		Tooltip = 'Key combination for up/down movement'
	})
end)
