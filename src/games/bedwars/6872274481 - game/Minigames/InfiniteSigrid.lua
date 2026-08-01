local InfiniteSigrid
run(function()
	local rbxts = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include")
	local Flamework = require(rbxts.node_modules["@flamework"].core.out).Flamework
	local AbilityController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController")
	local CooldownController = Flamework.resolveDependency("@easy-games/game-core:client/controllers/cooldown/cooldown-controller@CooldownController")
	local AbilityId = require(game:GetService("ReplicatedStorage").TS.ability["ability-id"]).AbilityId
	local AbilityState = require(rbxts.node_modules["@easy-games"]["game-core"].out).AbilityState
	local KnitClient = require(rbxts.node_modules["@easy-games"].knit.src).KnitClient

	InfiniteSigrid = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteSigrid',
		Function = function(callback)
			if callback then
				InfiniteSigrid:Clean(runService.Heartbeat:Connect(function()
					-- 1. Lock Elk Ability States to READY
					pcall(function()
						local ctrl = AbilityController or (bedwars and bedwars.AbilityController)
						if ctrl then
							for _, id in ipairs({
								AbilityId.ELK_ANTLER_UPPERCUT,
								AbilityId.ELK_SUMMON,
								AbilityId.ELK_DISMISS
							}) do
								local ab = ctrl:getEnabledAbility(id)
								if ab then
									ctrl:setAbilityState(ab, AbilityState.READY)
								end
							end
						end
					end)

					-- 2. Freeze Cooldown Timers
					pcall(function()
						local cdCtrl = CooldownController or (bedwars and bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.CooldownController)
						if cdCtrl and cdCtrl.cooldownMap then
							for key, cdData in pairs(cdCtrl.cooldownMap) do
								local strKey = string.lower(tostring(key))
								if string.find(strKey, "elk") or string.find(strKey, "sigrid") then
									cdData.expire = os.clock() + 999999
									cdData.startTime = os.clock()
								end
							end
						end
					end)

					-- 3. Override Controller & Freeze UI Charge Bar
					pcall(function()
						local elkCtrl = KnitClient.Controllers.ElkMasterController or (bedwars and bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.ElkMasterController)
						if elkCtrl then
							if elkCtrl.chargeSpeed and elkCtrl.chargeSpeed > 0 then
								elkCtrl.chargeSpeed = 50
							end

							if elkCtrl.chargeMaidMap and lplr then
								local maid = elkCtrl.chargeMaidMap[lplr]
								if maid then
									if not rawget(maid, "_patchedDoCleaning") then
										rawset(maid, "_patchedDoCleaning", true)
										rawset(maid, "DoCleaning", function() end)
									end
								end
							end
						end

						-- Lock ActionBar ProgressBar visually to full scale
						if lplr and lplr:FindFirstChild("PlayerGui") then
							local gui = lplr.PlayerGui:FindFirstChild("ActionBarScreenGui")
							if gui then
								local bar = gui:FindFirstChild("ActionBar") and gui.ActionBar:FindFirstChild("ProgressBarContainer") and gui.ActionBar.ProgressBarContainer:FindFirstChild("ProgressBar")
								if bar then
									bar.Size = UDim2.new(1, 0, 1, 0)
								end
							end
						end
					end)
				end))
			end
		end,
		Tooltip = 'Keeps the Sigrid Elk charge bar continuously full and infinite'
	})
end)
