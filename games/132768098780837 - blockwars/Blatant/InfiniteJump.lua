local InfiniteJump
local VelocitySlider
local up = false

InfiniteJump = vape.Categories.Blatant:CreateModule({
	Name = 'InfiniteJump',
	Function = function(callback)
		if callback then
			if not ACDisabler.Enabled then
				ACDisabler:Toggle()
			end

			InfiniteJump:Clean(runService.PreSimulation:Connect(function()
				if entitylib.isAlive and up then
					local root = entitylib.character.RootPart
					root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, VelocitySlider.Value, root.AssemblyLinearVelocity.Z)
				end
			end))

			InfiniteJump:Clean(inputService.InputBegan:Connect(function(input)
				if not inputService:GetFocusedTextBox() then
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = true
					end
				end
			end))

			InfiniteJump:Clean(inputService.InputEnded:Connect(function(input)
				if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
					up = false
				end
			end))

			if inputService.TouchEnabled then
				pcall(function()
					local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
					InfiniteJump:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
						up = jumpButton.ImageRectOffset.X == 146
					end))
				end)
			end
		else
			up = false
		end
	end,
	Tooltip = 'Jump infinitely with vertical velocity while holding Space. Automatically enables the anticheat bypass.'
})

VelocitySlider = InfiniteJump:CreateSlider({
	Name = 'Velocity',
	Min = 10,
	Max = 150,
	Default = 50,
	Suffix = ' velocity'
})
