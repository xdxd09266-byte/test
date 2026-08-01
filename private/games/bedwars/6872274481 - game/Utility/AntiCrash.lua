local AntiCrash = vape.Categories.Utility:CreateModule({
	Name = 'AntiCrash',
	Function = function(callback)
		if callback then
			local net = replicatedStorage.rbxts_include.node_modules["@rbxts"].net.out._NetManaged

			local blockList = {
				"ProjectileLaunchClient",
				"ProjectileLaunch",
				"ProjectileHit",
				"ProjectileImpact"
			}

			for _, name in blockList do
				local remote = net:FindFirstChild(name)
				if remote and remote:IsA("RemoteEvent") then
					local ok, cons = pcall(getconnections, remote.OnClientEvent)
					if ok then
						for _, conn in cons do
							conn:Disconnect()
						end
					end
				end
			end

			vape:CreateNotification('AntiCrash', 'Blocked projectile crash exploits', 3)
		end
	end,
	Tooltip = 'Blocks incoming projectile crash data from the server'
})
