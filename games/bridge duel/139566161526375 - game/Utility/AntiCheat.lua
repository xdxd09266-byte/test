local api = shared.vape

local AntiCheat = {Enabled = false}
AntiCheat = api.Categories.Utility:CreateModule({
	Name = "AntiCheatDisabler",
	Function = function(callback)
		if callback then
			local RS = game:GetService("ReplicatedStorage")

			-- Kill the FingerprintClient script threads
			local fingerprintScript = game.Players.LocalPlayer.PlayerScripts:FindFirstChild("FingerprintClient")
			if fingerprintScript then
				fingerprintScript.Disabled = true
				fingerprintScript:Destroy()
			end

			-- Disconnect all OnClientEvent listeners so server cant request new fingerprints
			local remote = RS:FindFirstChild("FingerprintRemote")
			if remote then
				if getconnections then
					for _, conn in pairs(getconnections(remote.OnClientEvent)) do
						pcall(function() conn:Disconnect() end)
					end
					for _, conn in pairs(getconnections(remote.OnServerEvent)) do
						pcall(function() conn:Disconnect() end)
					end
				end
				remote:Destroy()
			end

			-- Kill the Fingerprint module so nothing can re-require it
			local fingerprintModule = RS:FindFirstChild("Fingerprint")
			if fingerprintModule then
				fingerprintModule:Destroy()
			end

			-- Swap out FingerprintRemote references in any surviving closures
			if getgc then
				local fakeRemote = Instance.new("RemoteEvent")
				for _, obj in pairs(getgc(true)) do
					if type(obj) == "table" then
						for k, v in pairs(obj) do
							if typeof(v) == "Instance" and v:IsA("RemoteEvent") then
								pcall(function()
									if v.Name == "FingerprintRemote" then
										obj[k] = fakeRemote
									end
								end)
							end
						end
					end
				end
			end

			api.CreateNotification("AntiCheatDisabler", "Fingerprint tracking destroyed. Privacy protected.", 5)
		end
	end,
	Tooltip = "Disables Bridge Duel's fingerprint tracking\nProtects your privacy and prevents alt-banning."
})
