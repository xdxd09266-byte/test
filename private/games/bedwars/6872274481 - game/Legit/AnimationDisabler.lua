local AnimationDisabler
local animConnections
local controllerBackups
local animHook

local FUNCTION = function() end

local function stopAllTracks(char)
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	local tracks = animator:GetPlayingAnimationTracks()
	if tracks then
		for _, track in pairs(tracks) do
			pcall(function() track:Stop() end)
		end
	end
end

local function hookAnimator(char)
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end
	if animHook then
		animHook:Disconnect()
	end
	animHook = animator.AnimationPlayed:Connect(function(track)
		pcall(function() track:Stop() end)
	end)
end

local function removeAnimate(char)
	local animate = char:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		animate:Destroy()
	end
end

local function blockAnimationRemotes()
	local rmt = game.ReplicatedStorage.rbxts_include.node_modules["@rbxts"].net.out._NetManaged.ForcePlayAnimation
	if rmt then
		for _, conn in pairs(getconnections(rmt.OnClientEvent)) do
			conn:Disconnect()
		end
	end
end

local function noopControllers()
	for _, ctrlName in pairs({"SwordController", "ScytheController"}) do
		local ctrl = bedwars[ctrlName]
		if not ctrl then continue end
		controllerBackups[ctrl] = {}
		for _, methodName in pairs({"playAnimation", "playLocalAnimation", "playSwordEffect"}) do
			if typeof(ctrl[methodName]) == "function" then
				controllerBackups[ctrl][methodName] = ctrl[methodName]
				ctrl[methodName] = FUNCTION
			end
		end
	end
end

local function restoreControllers()
	for ctrl, methods in pairs(controllerBackups) do
		for name, fn in pairs(methods) do
			ctrl[name] = fn
		end
	end
	table.clear(controllerBackups)
end

AnimationDisabler = vape.Legit:CreateModule({
	Name = 'Animation Disabler',
	Function = function(callback)
		if callback then
			animConnections = {}
			controllerBackups = {}

			blockAnimationRemotes()

			if entitylib.isAlive then
				removeAnimate(entitylib.character.Character)
				stopAllTracks(entitylib.character.Character)
				hookAnimator(entitylib.character.Character)
			end
			AnimationDisabler:Clean(entitylib.Events.LocalAdded:Connect(function(char)
				removeAnimate(char)
				stopAllTracks(char)
				hookAnimator(char)
			end))
			noopControllers()
		else
			if animHook then
				animHook:Disconnect()
				animHook = nil
			end
			for _, conn in pairs(animConnections or {}) do
				conn:Disconnect()
			end
			animConnections = nil
			restoreControllers()
		end
	end,
	Tooltip = 'Disables character animations including server-forced ones'
})
