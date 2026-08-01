local run = function(func)
	func()
end
local cloneref = cloneref or function(obj)
	return obj
end
local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local playersService = cloneref(game:GetService('Players'))
local replicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local runService = cloneref(game:GetService('RunService'))
local inputService = cloneref(game:GetService('UserInputService'))
local tweenService = cloneref(game:GetService('TweenService'))
local httpService = cloneref(game:GetService('HttpService'))
local textChatService = cloneref(game:GetService('TextChatService'))
local collectionService = cloneref(game:GetService('CollectionService'))
local contextActionService = cloneref(game:GetService('ContextActionService'))
local guiService = cloneref(game:GetService('GuiService'))
local coreGui = cloneref(game:GetService('CoreGui'))
local starterGui = cloneref(game:GetService('StarterGui'))

local isnetworkowner = identifyexecutor and table.find({'AWP', 'Nihon'}, ({identifyexecutor()})[1]) and isnetworkowner or function()
	return true
end
local gameCamera = workspace.CurrentCamera
local lplr = playersService.LocalPlayer
local assetfunction = getcustomasset


local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local sessioninfo = vape.Libraries.sessioninfo
local uipallet = vape.Libraries.uipallet
local tween = vape.Libraries.tween
local color = vape.Libraries.color
local whitelist = vape.Libraries.whitelist
local prediction = vape.Libraries.prediction
local getfontsize = vape.Libraries.getfontsize
local getcustomasset = vape.Libraries.getcustomasset

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

local function addBlur(parent)
	local blur = Instance.new('ImageLabel')
	blur.Name = 'Blur'
	blur.Size = UDim2.new(1, 89, 1, 52)
	blur.Position = UDim2.fromOffset(-48, -31)
	blur.BackgroundTransparency = 1
	blur.Image = getcustomasset('newvape/assets/new/blur.png')
	blur.ScaleType = Enum.ScaleType.Slice
	blur.SliceCenter = Rect.new(52, 31, 261, 502)
	blur.Parent = parent
	return blur
end

local function collection(tags, module, customadd, customremove)
	tags = typeof(tags) ~= 'table' and {tags} or tags
	local objs, connections = {}, {}

	for _, tag in tags do
		table.insert(connections, collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
			if customadd then
				customadd(objs, v, tag)
				return
			end
			table.insert(objs, v)
		end))
		table.insert(connections, collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
			if customremove then
				customremove(objs, v, tag)
				return
			end
			v = table.find(objs, v)
			if v then
				table.remove(objs, v)
			end
		end))

		for _, v in collectionService:GetTagged(tag) do
			if customadd then
				customadd(objs, v, tag)
				continue
			end
			table.insert(objs, v)
		end
	end

	local cleanFunc = function(self)
		for _, v in connections do
			v:Disconnect()
		end
		table.clear(connections)
		table.clear(objs)
		table.clear(self)
	end
	if module then
		module:Clean(cleanFunc)
	end
	return objs, cleanFunc
end

local function getBestArmor(slot)
	local closest, mag = nil, 0

	for _, item in store.inventory.inventory.items do
		local meta = item and bedwars.ItemMeta[item.itemType] or {}

		if meta.armor and meta.armor.slot == slot then
			local newmag = (meta.armor.damageReductionMultiplier or 0)

			if newmag > mag then
				closest, mag = item, newmag
			end
		end
	end

	return closest
end

local function getBow()
	local bestBow, bestBowSlot, bestBowDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local bowMeta = bedwars.ItemMeta[item.itemType].projectileSource
		if bowMeta and table.find(bowMeta.ammoItemTypes, 'arrow') then
			local bowDamage = bedwars.ProjectileMeta[bowMeta.projectileType('arrow')].combat.damage or 0
			if bowDamage > bestBowDamage then
				bestBow, bestBowSlot, bestBowDamage = item, slot, bowDamage
			end
		end
	end
	return bestBow, bestBowSlot
end

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getRoactRender(func)
	return debug.getupvalue(debug.getupvalue(debug.getupvalue(func, 3).render, 2).render, 1)
end

local function getSword()
	local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local swordMeta = bedwars.ItemMeta[item.itemType].sword
		if swordMeta then
			local swordDamage = swordMeta.damage or 0
			if swordDamage > bestSwordDamage then
				bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
			end
		end
	end
	return bestSword, bestSwordSlot
end

local function getTool(breakType)
	local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
	for slot, item in store.inventory.inventory.items do
		local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
		if toolMeta then
			local toolDamage = toolMeta[breakType] or 0
			if toolDamage > bestToolDamage then
				bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
			end
		end
	end
	return bestTool, bestToolSlot
end

local function getWool()
	for _, wool in (inv or store.inventory.inventory.items) do
		if wool.itemType:find('wool') then
			return wool and wool.itemType, wool and wool.amount
		end
	end
end

local function getStrength(plr)
	if not plr.Player then
		return 0
	end

	local strength = 0
	for _, v in (store.inventories[plr.Player] or {items = {}}).items do
		local itemmeta = bedwars.ItemMeta[v.itemType]
		if itemmeta and itemmeta.sword and itemmeta.sword.damage > strength then
			strength = itemmeta.sword.damage
		end
	end

	return strength
end

local function getPlacedBlock(pos)
	if not pos then
		return
	end
	local roundedPosition = bedwars.BlockController:getBlockPosition(pos)
	return bedwars.BlockController:getStore():getBlockAt(roundedPosition), roundedPosition
end

local function getBlocksInPoints(s, e)
	local blocks, list = bedwars.BlockController:getStore(), {}
	for x = s.X, e.X do
		for y = s.Y, e.Y do
			for z = s.Z, e.Z do
				local vec = Vector3.new(x, y, z)
				if blocks:getBlockAt(vec) then
					table.insert(list, vec * 3)
				end
			end
		end
	end
	return list
end

local function getNearGround(range)
	range = Vector3.new(3, 3, 3) * (range or 10)
	local localPosition, mag, closest = entitylib.character.RootPart.Position, 60
	local blocks = getBlocksInPoints(bedwars.BlockController:getBlockPosition(localPosition - range), bedwars.BlockController:getBlockPosition(localPosition + range))

	for _, v in blocks do
		if not getPlacedBlock(v + Vector3.new(0, 3, 0)) then
			local newmag = (localPosition - v).Magnitude
			if newmag < mag then
				mag, closest = newmag, v + Vector3.new(0, 3, 0)
			end
		end
	end

	table.clear(blocks)
	return closest
end

local function getShieldAttribute(char)
	local returned = 0
	for name, val in char:GetAttributes() do
		if name:find('Shield') and type(val) == 'number' and val > 0 then
			returned += val
		end
	end
	return returned
end

local function getSpeed()
	local multi, increase, modifiers = 0, true, bedwars.SprintController:getMovementStatusModifier():getModifiers()

	for v in modifiers do
		local val = v.constantSpeedMultiplier and v.constantSpeedMultiplier or 0
		if val and val > math.max(multi, 1) then
			increase = false
			multi = val - (0.06 * math.round(val))
		end
	end

	for v in modifiers do
		multi += math.max((v.moveSpeedMultiplier or 0) - 1, 0)
	end

	if multi > 0 and increase then
		multi += 0.16 + (0.02 * math.round(multi))
	end

	return 20 * (multi + 1)
end

local function getTableSize(tab)
	local ind = 0
	for _ in tab do
		ind += 1
	end
	return ind
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function isFriend(plr, recolor)
	if vape.Categories.Friends.Options['Use friends'].Enabled then
		local friend = table.find(vape.Categories.Friends.ListEnabled, plr.Name) and true
		if recolor then
			friend = friend and vape.Categories.Friends.Options['Recolor visuals'].Enabled
		end
		return friend
	end
	return nil
end

local function isTarget(plr)
	return table.find(vape.Categories.Targets.ListEnabled, plr.Name) and true
end

local function notif(...) return
	vape:CreateNotification(...)
end

local function removeTags(str)
	str = str:gsub('<br%s*/>', '\n')
	return (str:gsub('<[^<>]->', ''))
end

local function roundPos(vec)
	return Vector3.new(math.round(vec.X / 3) * 3, math.round(vec.Y / 3) * 3, math.round(vec.Z / 3) * 3)
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function waitForChildOfType(obj, name, timeout, prop)
	local check, returned = tick() + timeout
	repeat
		returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
		if returned and returned.Name ~= 'UpperTorso' or check < tick() then
			break
		end
		task.wait()
	until false
	return returned
end

local frictionTable, oldfrict = {}, {}
local frictionConnection
local frictionState

local function modifyVelocity(v)
	if v:IsA('BasePart') and v.Name ~= 'HumanoidRootPart' and not oldfrict[v] then
		oldfrict[v] = v.CustomPhysicalProperties or 'none'
		v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	end
end

local function updateVelocity(force)
	local newState = getTableSize(frictionTable) > 0
	if frictionState ~= newState or force then
		if frictionConnection then
			frictionConnection:Disconnect()
		end
		if newState then
			if entitylib.isAlive then
				for _, v in entitylib.character.Character:GetDescendants() do
					modifyVelocity(v)
				end
				frictionConnection = entitylib.character.Character.DescendantAdded:Connect(modifyVelocity)
			end
		else
			for i, v in oldfrict do
				i.CustomPhysicalProperties = v ~= 'none' and v or nil
			end
			table.clear(oldfrict)
		end
	end
	frictionState = newState
end

local kitorder = {
	hannah = 5,
	spirit_assassin = 4,
	dasher = 3,
	jade = 2,
	regent = 1
}

local sortmethods = {
	Damage = function(a, b)
		return a.Entity.Character:GetAttribute('LastDamageTakenTime') < b.Entity.Character:GetAttribute('LastDamageTakenTime')
	end,
	Threat = function(a, b)
		return getStrength(a.Entity) > getStrength(b.Entity)
	end,
	Kit = function(a, b)
		return (a.Entity.Player and kitorder[a.Entity.Player:GetAttribute('PlayingAsKit')] or 0) > (b.Entity.Player and kitorder[b.Entity.Player:GetAttribute('PlayingAsKit')] or 0)
	end,
	Health = function(a, b)
		return a.Entity.Health < b.Entity.Health
	end,
	Angle = function(a, b)
		local selfrootpos = entitylib.character.RootPart.Position
		local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		local angle = math.acos(localfacing:Dot(((a.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		local angle2 = math.acos(localfacing:Dot(((b.Entity.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
		return angle < angle2
	end
}

run(function()
	local oldstart = entitylib.start
	local function customEntity(ent)
		if ent:HasTag('inventory-entity') and not ent:HasTag('Monster') then
			return
		end

		entitylib.addEntity(ent, nil, ent:HasTag('Drone') and function(self)
			local droneplr = playersService:GetPlayerByUserId(self.Character:GetAttribute('PlayerUserId'))
			return not droneplr or lplr:GetAttribute('Team') ~= droneplr:GetAttribute('Team')
		end or function(self)
			return lplr:GetAttribute('Team') ~= self.Character:GetAttribute('Team')
		end)
	end

	entitylib.start = function()
		oldstart()
		if entitylib.Running then
			for _, ent in collectionService:GetTagged('entity') do
				customEntity(ent)
			end
			table.insert(entitylib.Connections, collectionService:GetInstanceAddedSignal('entity'):Connect(customEntity))
			table.insert(entitylib.Connections, collectionService:GetInstanceRemovedSignal('entity'):Connect(function(ent)
				entitylib.removeEntity(ent)
			end))
		end
	end

	entitylib.addPlayer = function(plr)
		if plr.Character then
			entitylib.refreshEntity(plr.Character, plr)
		end
		entitylib.PlayerConnections[plr] = {
			plr.CharacterAdded:Connect(function(char)
				entitylib.refreshEntity(char, plr)
			end),
			plr.CharacterRemoving:Connect(function(char)
				entitylib.removeEntity(char, plr == lplr)
			end),
			plr:GetAttributeChangedSignal('Team'):Connect(function()
				for _, v in entitylib.List do
					if v.Targetable ~= entitylib.targetCheck(v) then
						entitylib.refreshEntity(v.Character, v.Player)
					end
				end

				if plr == lplr then
					entitylib.start()
				else
					entitylib.refreshEntity(plr.Character, plr)
				end
			end)
		}
	end

	entitylib.addEntity = function(char, plr, teamfunc)
		if not char then return end
		entitylib.EntityThreads[char] = task.spawn(function()
			local hum, humrootpart, head
			if plr then
				hum = waitForChildOfType(char, 'Humanoid', 10)
				humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
				head = char:WaitForChild('Head', 10) or humrootpart
			else
				hum = {HipHeight = 0.5}
				humrootpart = waitForChildOfType(char, 'PrimaryPart', 10, true)
				head = humrootpart
			end
			local updateobjects = plr and plr ~= lplr and {
				char:WaitForChild('ArmorInvItem_0', 5),
				char:WaitForChild('ArmorInvItem_1', 5),
				char:WaitForChild('ArmorInvItem_2', 5),
				char:WaitForChild('HandInvItem', 5)
			} or {}

			if hum and humrootpart then
				local entity = {
					Connections = {},
					Character = char,
					Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char),
					Head = head,
					Humanoid = hum,
					HumanoidRootPart = humrootpart,
					HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
					Jumps = 0,
					JumpTick = tick(),
					Jumping = false,
					LandTick = tick(),
					MaxHealth = char:GetAttribute('MaxHealth') or 100,
					NPC = plr == nil,
					Player = plr,
					RootPart = humrootpart,
					TeamCheck = teamfunc
				}

				if plr == lplr then
					entity.AirTime = tick()
					entitylib.character = entity
					entitylib.isAlive = true
					entitylib.Events.LocalAdded:Fire(entity)
					table.insert(entitylib.Connections, char.AttributeChanged:Connect(function(attr)
						vapeEvents.AttributeChanged:Fire(attr)
					end))
				else
					entity.Targetable = entitylib.targetCheck(entity)

					for _, v in entitylib.getUpdateConnections(entity) do
						table.insert(entity.Connections, v:Connect(function()
							entity.Health = (char:GetAttribute('Health') or 100) + getShieldAttribute(char)
							entity.MaxHealth = char:GetAttribute('MaxHealth') or 100
							entitylib.Events.EntityUpdated:Fire(entity)
						end))
					end

					for _, v in updateobjects do
						table.insert(entity.Connections, v:GetPropertyChangedSignal('Value'):Connect(function()
							task.delay(0.1, function()
								if bedwars.getInventory then
									store.inventories[plr] = bedwars.getInventory(plr)
									entitylib.Events.EntityUpdated:Fire(entity)
								end
							end)
						end))
					end

					if plr then
						local anim = char:FindFirstChild('Animate')
						if anim then
							pcall(function()
								anim = anim.jump:FindFirstChildWhichIsA('Animation').AnimationId
								table.insert(entity.Connections, hum.Animator.AnimationPlayed:Connect(function(playedanim)
									if playedanim.Animation.AnimationId == anim then
										entity.JumpTick = tick()
										entity.Jumps += 1
										entity.LandTick = tick() + 1
										entity.Jumping = entity.Jumps > 1
									end
								end))
							end)
						end

						task.delay(0.1, function()
							if bedwars.getInventory then
								store.inventories[plr] = bedwars.getInventory(plr)
							end
						end)
					end
					table.insert(entitylib.List, entity)
					entitylib.Events.EntityAdded:Fire(entity)
				end

				table.insert(entity.Connections, char.ChildRemoved:Connect(function(part)
					if part == humrootpart or part == hum or part == head then
						if part == humrootpart and hum.RootPart then
							humrootpart = hum.RootPart
							entity.RootPart = hum.RootPart
							entity.HumanoidRootPart = hum.RootPart
							return
						end
						entitylib.removeEntity(char, plr == lplr)
					end
				end))
			end
			entitylib.EntityThreads[char] = nil
		end)
	end

	entitylib.getUpdateConnections = function(ent)
		local char = ent.Character
		local tab = {
			char:GetAttributeChangedSignal('Health'),
			char:GetAttributeChangedSignal('MaxHealth'),
			{
				Connect = function()
					ent.Friend = ent.Player and isFriend(ent.Player) or nil
					ent.Target = ent.Player and isTarget(ent.Player) or nil
					return {Disconnect = function() end}
				end
			}
		}

		if ent.Player then
			table.insert(tab, ent.Player:GetAttributeChangedSignal('PlayingAsKit'))
		end

		for name, val in char:GetAttributes() do
			if name:find('Shield') and type(val) == 'number' then
				table.insert(tab, char:GetAttributeChangedSignal(name))
			end
		end

		return tab
	end

	entitylib.targetCheck = function(ent)
		if ent.TeamCheck then
			return ent:TeamCheck()
		end
		if ent.NPC then return true end
		if isFriend(ent.Player) then return false end
		if not select(2, whitelist:get(ent.Player)) then return false end
		return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
	end
	vape:Clean(entitylib.Events.LocalAdded:Connect(updateVelocity))
end)
entitylib.start()

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationType = require(replicatedStorage.TS.animation['animation-type']).AnimationType,
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out['shared'].util['animation-util']).AnimationUtil,
		AppController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController,
		BedBreakEffectMeta = require(replicatedStorage.TS.locker['bed-break-effect']['bed-break-effect-meta']).BedBreakEffectMeta,
		BedwarsKitMeta = require(replicatedStorage.TS.games.bedwars.kit['bedwars-kit-meta']).BedwarsKitMeta,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BowConstantsTable = debug.getupvalue(Knit.Controllers.ProjectileController.enableBeam, 8),
		ClickHold = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.ui.lib.util['click-hold']).ClickHold,
		Client = Client,
		ClientConstructor = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts'].net.out.client),
		ClientDamageBlock = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.shared.remotes).BlockEngineRemotes.Client,
		CombatConstant = require(replicatedStorage.TS.combat['combat-constant']).CombatConstant,
		DefaultKillEffect = (function()
			local path = lplr.PlayerScripts.TS.controllers:FindFirstChild('global') and lplr.PlayerScripts.TS.controllers.global:FindFirstChild('locker') and lplr.PlayerScripts.TS.controllers.global.locker:FindFirstChild('kill-effect') and lplr.PlayerScripts.TS.controllers.global.locker['kill-effect'].effects:FindFirstChild('default-kill-effect')
			if path then return require(path) end
			local legacy = lplr.PlayerScripts.TS.controllers:FindFirstChild('game') and lplr.PlayerScripts.TS.controllers.game:FindFirstChild('locker') and lplr.PlayerScripts.TS.controllers.game.locker:FindFirstChild('kill-effect') and lplr.PlayerScripts.TS.controllers.game.locker['kill-effect'].effects:FindFirstChild('default-kill-effect')
			if legacy then return require(legacy) end
			return {}
		end)(),
		GameAnimationUtil = require(replicatedStorage.TS.animation['animation-util']).GameAnimationUtil,
		getIcon = function(item, showinv)
			local itemmeta = bedwars.ItemMeta[item.itemType]
			return itemmeta and showinv and itemmeta.image or ''
		end,
		getInventory = function(plr)
			local suc, res = pcall(function()
				return InventoryUtil.getInventory(plr)
			end)
			return suc and res or {
				items = {},
				armor = {}
			}
		end,
		HudAliveCount = require(lplr.PlayerScripts.TS.controllers.global['top-bar'].ui.game['hud-alive-player-counts']).HudAlivePlayerCounts,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		KillEffectMeta = require(replicatedStorage.TS.locker['kill-effect']['kill-effect-meta']).KillEffectMeta,
		KillFeedController = Flamework.resolveDependency('client/controllers/game/kill-feed/kill-feed-controller@KillFeedController'),
		Knit = Knit,
		KnockbackUtil = require(replicatedStorage.TS.damage['knockback-util']).KnockbackUtil,
		MageKitUtil = require(replicatedStorage.TS.games.bedwars.kit.kits.mage['mage-kit-util']).MageKitUtil,
		NametagController = Knit.Controllers.NametagController,
		PartyController = Flamework.resolveDependency('@easy-games/lobby:client/controllers/party-controller@PartyController'),
		ProjectileMeta = require(replicatedStorage.TS.projectile['projectile-meta']).ProjectileMeta,
		QueryUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil,
		QueueCard = require(lplr.PlayerScripts.TS.controllers.global.queue.ui['queue-card']).QueueCard,
		QueueMeta = require(replicatedStorage.TS.game['queue-meta']).QueueMeta,
		Roact = require(replicatedStorage['rbxts_include']['node_modules']['@rbxts']['roact'].src),
		RuntimeLib = require(replicatedStorage['rbxts_include'].RuntimeLib),
		SoundList = require(replicatedStorage.TS.sound['game-sound']).GameSound,
		SoundManager = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).SoundManager,
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		TeamUpgradeMeta = debug.getupvalue(require(replicatedStorage.TS.games.bedwars['team-upgrade']['team-upgrade-meta']).getTeamUpgradeMetaForQueue, 6),
		UILayers = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers,
		VisualizerUtils = require(lplr.PlayerScripts.TS.lib.visualizer['visualizer-utils']).VisualizerUtils,
		WeldTable = require(replicatedStorage.TS.util['weld-util']).WeldUtil,
		WinEffectMeta = require(replicatedStorage.TS.locker['win-effect']['win-effect-meta']).WinEffectMeta,
		ZapNetworking = require(lplr.PlayerScripts.TS.lib.network)
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	local remoteNames = {
		AfkStatus = pcall(function() return debug.getproto(Knit.Controllers.AfkController.KnitStart, 1) end),
		AttackEntity = Knit.Controllers.SwordController and Knit.Controllers.SwordController.sendServerRequest,
		BeePickup = Knit.Controllers.BeeNetController and Knit.Controllers.BeeNetController.trigger,
		CannonAim = pcall(function() return debug.getproto(Knit.Controllers.CannonController.startAiming, 5) end),
		CannonLaunch = Knit.Controllers.CannonHandController and Knit.Controllers.CannonHandController.launchSelf,
		ConsumeBattery = pcall(function() return debug.getproto(Knit.Controllers.BatteryController.onKitLocalActivated, 1) end),
		ConsumeItem = pcall(function() return debug.getproto(Knit.Controllers.ConsumeController.onEnable, 1) end),
		ConsumeSoul = Knit.Controllers.GrimReaperController and Knit.Controllers.GrimReaperController.consumeSoul,
		ConsumeTreeOrb = pcall(function() return debug.getproto(Knit.Controllers.EldertreeController.createTreeOrbInteraction, 1) end),
		DepositPinata = pcall(function() return debug.getproto(debug.getproto(Knit.Controllers.PiggyBankController.KnitStart, 2), 5) end),
		DragonBreath = pcall(function() return debug.getproto(Knit.Controllers.VoidDragonController.onKitLocalActivated, 5) end),
		DragonEndFly = pcall(function() return debug.getproto(Knit.Controllers.VoidDragonController.flapWings, 1) end),
		DragonFly = Knit.Controllers.VoidDragonController and Knit.Controllers.VoidDragonController.flapWings,
		DropItem = Knit.Controllers.ItemDropController and Knit.Controllers.ItemDropController.dropItemInHand,
		EquipItem = pcall(function() return debug.getproto(require(replicatedStorage.TS.entity.entities['inventory-entity']).InventoryEntity.equipItem, 4) end),
		FireProjectile = pcall(function() return debug.getupvalue(Knit.Controllers.ProjectileController.launchProjectileWithValues, 2) end),
		GroundHit = Knit.Controllers.FallDamageController and Knit.Controllers.FallDamageController.KnitStart,
		GuitarHeal = Knit.Controllers.GuitarController and Knit.Controllers.GuitarController.performHeal,
		HannahKill = pcall(function() return debug.getproto(Knit.Controllers.HannahController.registerExecuteInteractions, 1) end),
		HarvestCrop = pcall(function() return debug.getproto(debug.getproto(Knit.Controllers.CropController.KnitStart, 4), 1) end),
		KaliyahPunch = pcall(function() return debug.getproto(Knit.Controllers.DragonSlayerController.onKitLocalActivated, 1) end),
		MageSelect = pcall(function() return debug.getproto(Knit.Controllers.MageController.registerTomeInteraction, 1) end),
		MinerDig = pcall(function() return debug.getproto(Knit.Controllers.MinerController.setupMinerPrompts, 1) end),
		PickupItem = Knit.Controllers.ItemDropController and Knit.Controllers.ItemDropController.checkForPickup,
		PickupMetal = pcall(function() return debug.getproto(Knit.Controllers.HiddenMetalController.onKitLocalActivated, 4) end),
		ReportPlayer = pcall(function() return require(lplr.PlayerScripts.TS.controllers.global.report['report-controller']).default.reportPlayer end),
		ResetCharacter = pcall(function() return debug.getproto(Knit.Controllers.ResetController.createBindable, 1) end),
		SpawnRaven = pcall(function() return debug.getproto(Knit.Controllers.RavenController.KnitStart, 1) end),
		SummonerClawAttack = Knit.Controllers.SummonerClawHandController and Knit.Controllers.SummonerClawHandController.attack,
		WarlockTarget = pcall(function() return debug.getproto(Knit.Controllers.WarlockStaffController.KnitStart, 2) end)
	}

	local function dumpRemote(tab)
		if type(tab) ~= 'function' then return '' end
		local constants = pcall(function() return debug.getconstants(tab) end) and debug.getconstants(tab) or {}
		local ind
		for i, v in constants do
			if v == 'Client' then
				ind = i
				break
			end
		end
		return ind and constants[ind + 1] or ''
	end

	for i, v in remoteNames do
		local func = type(v) == 'boolean' and nil or (typeof(v) == 'function' and v or nil)
		local remote = dumpRemote(func)
		remotes[i] = remote
	end

	OldBreak = bedwars.BlockController.isBlockBreakable

	Client.Get = function(self, remoteName)
		local call = OldGet(self, remoteName)

		if remoteName == remotes.AttackEntity then
			return {
				instance = call.instance,
				SendToServer = function(_, attackTable, ...)
					local suc, plr = pcall(function()
						return playersService:GetPlayerFromCharacter(attackTable.entityInstance)
					end)

					local selfpos = attackTable.validate.selfPosition.value
					local targetpos = attackTable.validate.targetPosition.value
					store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
					store.attackReachUpdate = tick() + 1

					if Reach.Enabled or HitBoxes.Enabled then
						attackTable.validate.raycast = attackTable.validate.raycast or {}
						attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
					end

					if suc and plr then
						if not select(2, whitelist:get(plr)) then return end
					end

					return call:SendToServer(attackTable, ...)
				end
			}
		elseif remoteName == 'StepOnSnapTrap' and TrapDisabler.Enabled then
			return {SendToServer = function() end}
		end

		return call
	end

	bedwars.BlockController.isBlockBreakable = function(self, breakTable, plr)
		local obj = bedwars.BlockController:getStore():getBlockAt(breakTable.blockPosition)

		if obj and obj.Name == 'bed' then
			for _, plr in playersService:GetPlayers() do
				if obj:GetAttribute('Team'..(plr:GetAttribute('Team') or 0)..'NoBreak') and not select(2, whitelist:get(plr)) then
					return false
				end
			end
		end

		return OldBreak(self, breakTable, plr)
	end

	local cache, blockhealthbar = {}, {blockHealth = -1, breakingBlockPosition = Vector3.zero}
	store.blockPlacer = bedwars.BlockPlacer.new(bedwars.BlockEngine, 'wool_white')

	local function getBlockHealth(block, blockpos)
		local blockdata = bedwars.BlockController:getStore():getBlockData(blockpos)
		return (blockdata and (blockdata:GetAttribute('1') or blockdata:GetAttribute('Health')) or block:GetAttribute('Health'))
	end

	local function getBlockHits(block, blockpos)
		if not block then return 0 end
		local breaktype = bedwars.ItemMeta[block.Name].block.breakType
		local tool = store.tools[breaktype]
		tool = tool and bedwars.ItemMeta[tool.itemType].breakBlock[breaktype] or 2
		return getBlockHealth(block, bedwars.BlockController:getBlockPosition(blockpos)) / tool
	end

	--[[
		Pathfinding using a luau version of dijkstra's algorithm
		Source: https://stackoverflow.com/questions/39355587/speeding-up-dijkstras-algorithm-to-solve-a-3d-maze
	]]
	local function calculatePath(target, blockpos)
		if cache[blockpos] then
			return unpack(cache[blockpos])
		end
		local visited, unvisited, distances, air, path = {}, {{0, blockpos}}, {[blockpos] = 0}, {}, {}

		for _ = 1, 10000 do
			local _, node = next(unvisited)
			if not node then break end
			table.remove(unvisited, 1)
			visited[node[2]] = true

			for _, side in sides do
				side = node[2] + side
				if visited[side] then continue end

				local block = getPlacedBlock(side)
				if not block or block:GetAttribute('NoBreak') or block == target then
					if not block then
						air[node[2]] = true
					end
					continue
				end

				local curdist = getBlockHits(block, side) + node[1]
				if curdist < (distances[side] or math.huge) then
					table.insert(unvisited, {curdist, side})
					distances[side] = curdist
					path[side] = node[2]
				end
			end
		end

		local pos, cost = nil, math.huge
		for node in air do
			if distances[node] < cost then
				pos, cost = node, distances[node]
			end
		end

		if pos then
			cache[blockpos] = {
				pos,
				cost,
				path
			}
			return pos, cost, path
		end
	end

	bedwars.placeBlock = function(pos, item)
		if getItem(item) then
			store.blockPlacer.blockType = item
			return store.blockPlacer:placeBlock(bedwars.BlockController:getBlockPosition(pos))
		end
	end

	bedwars.breakBlock = function(block, effects, anim, customHealthbar)
		if lplr:GetAttribute('DenyBlockBreak') or not entitylib.isAlive or InfiniteFly.Enabled then return end
		local handler = bedwars.BlockController:getHandlerRegistry():getHandler(block.Name)
		local cost, pos, target, path = math.huge

		for _, v in (handler and handler:getContainedPositions(block) or {block.Position / 3}) do
			local dpos, dcost, dpath = calculatePath(block, v * 3)
			if dpos and dcost < cost then
				cost, pos, target, path = dcost, dpos, v * 3, dpath
			end
		end

		if pos then
			if (entitylib.character.RootPart.Position - pos).Magnitude > 30 then return end
			local dblock, dpos = getPlacedBlock(pos)
			if not dblock then return end

			if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.4 then
				local breaktype = bedwars.ItemMeta[dblock.Name].block.breakType
				local tool = store.tools[breaktype]
				if tool then
					switchItem(tool.tool)
				end
			end

			if blockhealthbar.blockHealth == -1 or dpos ~= blockhealthbar.breakingBlockPosition then
				blockhealthbar.blockHealth = getBlockHealth(dblock, dpos)
				blockhealthbar.breakingBlockPosition = dpos
			end

			bedwars.ClientDamageBlock:Get('DamageBlock'):CallServerAsync({
				blockRef = {blockPosition = dpos},
				hitPosition = pos,
				hitNormal = Vector3.FromNormalId(Enum.NormalId.Top)
			}):andThen(function(result)
				if result then
					if result == 'cancelled' then
						store.damageBlockFail = tick() + 1
						return
					end

					if effects then
						local blockdmg = (blockhealthbar.blockHealth - (result == 'destroyed' and 0 or getBlockHealth(dblock, dpos)))
						customHealthbar = customHealthbar or bedwars.BlockBreaker.updateHealthbar
						customHealthbar(bedwars.BlockBreaker, {blockPosition = dpos}, blockhealthbar.blockHealth, dblock:GetAttribute('MaxHealth'), blockdmg, dblock)
						blockhealthbar.blockHealth = math.max(blockhealthbar.blockHealth - blockdmg, 0)

						if blockhealthbar.blockHealth <= 0 then
							bedwars.BlockBreaker.breakEffect:playBreak(dblock.Name, dpos, lplr)
							bedwars.BlockBreaker.healthbarMaid:DoCleaning()
							blockhealthbar.breakingBlockPosition = Vector3.zero
						else
							bedwars.BlockBreaker.breakEffect:playHit(dblock.Name, dpos, lplr)
						end
					end

					if anim then
						local animation = bedwars.AnimationUtil:playAnimation(lplr, bedwars.BlockController:getAnimationController():getAssetId(1))
						bedwars.ViewmodelController:playAnimation(15)
						task.wait(0.3)
						animation:Stop()
						animation:Destroy()
					end
				end
			end)

			if effects then
				return pos, path, target
			end
		end
	end

	for _, v in Enum.NormalId:GetEnumItems() do
		table.insert(sides, Vector3.FromNormalId(v) * 3)
	end

	local function updateStore(new, old)
		if new.Bedwars ~= old.Bedwars then
			store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
		end

		if new.Game ~= old.Game then
			store.matchState = new.Game.matchState
			store.queueType = new.Game.queueType or 'bedwars_test'
		end

		if new.Inventory ~= old.Inventory then
			local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
			local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
			store.inventory = newinv

			if newinv ~= oldinv then
				vapeEvents.InventoryChanged:Fire()
			end

			if newinv.inventory.items ~= oldinv.inventory.items then
				vapeEvents.InventoryAmountChanged:Fire()
				store.tools.sword = getSword()
				for _, v in {'stone', 'wood', 'wool'} do
					store.tools[v] = getTool(v)
				end
			end

			if newinv.inventory.hand ~= oldinv.inventory.hand then
				local currentHand, toolType = new.Inventory.observedInventory.inventory.hand, ''
				if currentHand then
					local handData = bedwars.ItemMeta[currentHand.itemType]
					toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow'
				end

				store.hand = {
					tool = currentHand and currentHand.tool,
					amount = currentHand and currentHand.amount or 0,
					toolType = toolType
				}
			end
		end
	end

	local storeChanged = bedwars.Store.changed:connect(updateStore)
	updateStore(bedwars.Store:getState(), {})

	for _, event in {'MatchEndEvent', 'EntityDeathEvent', 'BedwarsBedBreak', 'BalloonPopped', 'AngelProgress', 'GrapplingHookFunctions'} do
		if not vape.Connections then return end
		bedwars.Client:WaitFor(event):andThen(function(connection)
			vape:Clean(connection:Connect(function(...)
				vapeEvents[event]:Fire(...)
			end))
		end)
	end

	vape:Clean(bedwars.ZapNetworking.EntityDamageEventZap.On(function(...)
		vapeEvents.EntityDamageEvent:Fire({
			entityInstance = ...,
			damage = select(2, ...),
			damageType = select(3, ...),
			fromPosition = select(4, ...),
			fromEntity = select(5, ...),
			knockbackMultiplier = select(6, ...),
			knockbackId = select(7, ...),
			disableDamageHighlight = select(13, ...)
		})
	end))

	for _, event in {'PlaceBlockEvent', 'BreakBlockEvent'} do
		vape:Clean(bedwars.ZapNetworking[event..'Zap'].On(function(...)
			local data = {
				blockRef = {
					blockPosition = ...,
				},
				player = select(5, ...)
			}
			for i, v in cache do
				if ((data.blockRef.blockPosition * 3) - v[1]).Magnitude <= 30 then
					table.clear(v[3])
					table.clear(v)
					cache[i] = nil
				end
			end
			vapeEvents[event]:Fire(data)
		end))
	end

	store.blocks = collection('block', gui)
	store.shop = collection({'BedwarsItemShop', 'TeamUpgradeShopkeeper'}, gui, function(tab, obj)
		table.insert(tab, {
			Id = obj.Name,
			RootPart = obj,
			Shop = obj:HasTag('BedwarsItemShop'),
			Upgrades = obj:HasTag('TeamUpgradeShopkeeper')
		})
	end)
	store.enchant = collection({'enchant-table', 'broken-enchant-table'}, gui, nil, function(tab, obj, tag)
		if obj:HasTag('enchant-table') and tag == 'broken-enchant-table' then return end
		obj = table.find(tab, obj)
		if obj then
			table.remove(tab, obj)
		end
	end)

	local kills = sessioninfo:AddItem('Kills')
	local beds = sessioninfo:AddItem('Beds')
	local wins = sessioninfo:AddItem('Wins')
	local games = sessioninfo:AddItem('Games')

	local mapname = 'Unknown'
	sessioninfo:AddItem('Map', 0, function()
		return mapname
	end, false)

	task.delay(1, function()
		games:Increment()
	end)

	task.spawn(function()
		pcall(function()
			repeat task.wait() until store.matchState ~= 0 or vape.Loaded == nil
			if vape.Loaded == nil then return end
			mapname = workspace:WaitForChild('Map', 5):WaitForChild('Worlds', 5):GetChildren()[1].Name
			mapname = string.gsub(string.split(mapname, '_')[2] or mapname, '-', '') or 'Blank'
		end)
	end)

	vape:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
		if bedTable.player and bedTable.player.UserId == lplr.UserId then
			beds:Increment()
		end
	end))

	vape:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winTable)
		if (bedwars.Store:getState().Game.myTeam or {}).id == winTable.winningTeamId or lplr.Neutral then
			wins:Increment()
		end
	end))

	vape:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
		local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not killed or not killer then return end

		if killed ~= lplr and killer == lplr then
			kills:Increment()
		end
	end))

	task.spawn(function()
		repeat
			if entitylib.isAlive then
				entitylib.character.AirTime = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and tick() or entitylib.character.AirTime
			end

			for _, v in entitylib.List do
				v.LandTick = math.abs(v.RootPart.Velocity.Y) < 0.1 and v.LandTick or tick()
				if (tick() - v.LandTick) > 0.2 and v.Jumps ~= 0 then
					v.Jumps = 0
					v.Jumping = false
				end
			end
			task.wait()
		until vape.Loaded == nil
	end)

	pcall(function()
		if getthreadidentity and setthreadidentity then
			local old = getthreadidentity()
			setthreadidentity(2)

			bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
			bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
			bedwars.Shop.getShopItem('iron_sword', lplr)

			setthreadidentity(old)
			store.shopLoaded = true
		else
			task.spawn(function()
				repeat
					task.wait(0.1)
				until vape.Loaded == nil or bedwars.AppController:isAppOpen('BedwarsItemShopApp')

				bedwars.Shop = require(replicatedStorage.TS.games.bedwars.shop['bedwars-shop']).BedwarsShop
				bedwars.ShopItems = debug.getupvalue(debug.getupvalue(bedwars.Shop.getShopItem, 1), 2)
				store.shopLoaded = true
			end)
		end
	end)

	vape:Clean(function()
		Client.Get = OldGet
		bedwars.BlockController.isBlockBreakable = OldBreak
		store.blockPlacer:disable()
		for _, v in vapeEvents do
			v:Destroy()
		end
		for _, v in cache do
			table.clear(v[3])
			table.clear(v)
		end
		table.clear(store.blockPlacer)
		table.clear(vapeEvents)
		table.clear(bedwars)
		table.clear(store)
		table.clear(cache)
		table.clear(sides)
		table.clear(remotes)
		storeChanged:disconnect()
		storeChanged = nil
	end)
end)

for _, v in {'AntiRagdoll', 'TriggerBot', 'SilentAim', 'AutoRejoin', 'Rejoin', 'Disabler', 'Timer', 'ServerHop', 'MouseTP', 'MurderMystery'} do
	vape:Remove(v)
end

local AntiFallDirection
run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiFall',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Material = Enum.Material[Material.Value]
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if vape.Modules.Fly.Enabled or vape.Modules.InfiniteFly.Enabled or vape.Modules.LongJump.Enabled then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = Vector3.new(top.X, pos.Y, top.Z)
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
			end
		end,
		Tooltip = 'Help\'s you with your Parkinson\'s\nPrevents you from falling into the void.'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
		end,
	Tooltip = 'Normal - Smoothly moves you towards the nearest safe point\nVelocity - Launches you upward after touching\nCollide - Allows you to walk on the part'
	})
	local materials = {'ForceField'}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.Material = Enum.Material[val]
			end
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Color',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				AntiFallPart.Transparency = 1 - o
			end
		end
	})
end)

run(function()
	local AntiHit = {
	    Name = "AntiHit",
	    Description = "Spoofs your position on the server to prevent getting hit.",
	    Type = "Blatant",
	    Enabled = false
	}
	
	local RunService = game:GetService("RunService")
	local Players = game:GetService("Players")
	local lplr = Players.LocalPlayer
	
	local heartbeatConnection
	local renderConnection
	local realCFrame
	
	local offset = Vector3.new(0, 25, 0) -- Adjust the offset to be high enough
	
	function AntiHit.OnEnable()
	    heartbeatConnection = RunService.Heartbeat:Connect(function()
	        local char = lplr.Character
	        if char and char:FindFirstChild("HumanoidRootPart") then
	            local hrp = char.HumanoidRootPart
	            realCFrame = hrp.CFrame
	            -- Move position up right before physics replicate to server
	            hrp.CFrame = hrp.CFrame + offset
	            hrp.Velocity = Vector3.new(0, -100, 0) -- Confuse prediction
	        end
	    end)
	
	    renderConnection = RunService.RenderStepped:Connect(function()
	        local char = lplr.Character
	        if char and char:FindFirstChild("HumanoidRootPart") and realCFrame then
	            -- Restore position so we don't see it on our screen
	            char.HumanoidRootPart.CFrame = realCFrame
	        end
	    end)
	end
	
	function AntiHit.OnDisable()
	    if heartbeatConnection then
	        heartbeatConnection:Disconnect()
	        heartbeatConnection = nil
	    end
	    if renderConnection then
	        renderConnection:Disconnect()
	        renderConnection = nil
	    end
	    realCFrame = nil
	end
	
	return AntiHit
	
end)

run(function()
	local FastBreak
	local Time
	
	FastBreak = vape.Categories.Blatant:CreateModule({
		Name = 'FastBreak',
		Function = function(callback)
			if callback then
				repeat
					bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
					task.wait(0.1)
				until not FastBreak.Enabled
			else
				bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
			end
		end,
		Tooltip = 'Decreases block hit cooldown'
	})
	Time = FastBreak:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)

local Fly
local LongJump
run(function()
	local Value
	local VerticalValue
	local WallCheck
	local PopBalloons
	local TP
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local up, down, old = 0, 0

	Fly = vape.Categories.Blatant:CreateModule({
		Name = 'Fly',
		Function = function(callback)
			frictionTable.Fly = callback or nil
			updateVelocity()
			if callback then
				up, down, old = 0, 0, bedwars.BalloonController.deflateBalloon
				bedwars.BalloonController.deflateBalloon = function() end
				local tpTick, tpToggle, oldy = tick(), true

				if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
					bedwars.BalloonController:inflateBalloon()
				end
				Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
					if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
						bedwars.BalloonController:inflateBalloon()
					end
				end))
				Fly:Clean(runService.PreSimulation:Connect(function(dt)
					if entitylib.isAlive and not InfiniteFly.Enabled and isnetworkowner(entitylib.character.RootPart) then
						local flyAllowed = (lplr.Character:GetAttribute('InflatedBalloons') and lplr.Character:GetAttribute('InflatedBalloons') > 0) or store.matchState == 2
						local mass = (1.5 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
						local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
						local velo = getSpeed()
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
						rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
						rayCheck.CollisionGroup = root.CollisionGroup

						if WallCheck.Enabled then
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end

						if not flyAllowed then
							if tpToggle then
								local airleft = (tick() - entitylib.character.AirTime)
								if airleft > 2 then
									if not oldy then
										local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
										if ray and TP.Enabled then
											tpToggle = false
											oldy = root.Position.Y
											tpTick = tick() + 0.11
											root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
										end
									end
								end
							else
								if oldy then
									if tpTick < tick() then
										local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
										root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
										tpToggle = true
										oldy = nil
									else
										mass = 0
									end
								end
							end
						end

						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, mass, 0)
					end
				end))
				Fly:Clean(inputService.InputBegan:Connect(function(input)
					if not inputService:GetFocusedTextBox() then
						if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
							up = 1
						elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
							down = -1
						end
					end
				end))
				Fly:Clean(inputService.InputEnded:Connect(function(input)
					if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
						up = 0
					elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
						down = 0
					end
				end))
				if inputService.TouchEnabled then
					pcall(function()
						local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
							up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				bedwars.BalloonController.deflateBalloon = old
				if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
					for _ = 1, 3 do
						bedwars.BalloonController:deflateBalloon()
					end
				end
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Makes you go zoom.'
	})
	Value = Fly:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = 'Vertical Speed',
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	PopBalloons = Fly:CreateToggle({
		Name = 'Pop Balloons',
		Default = true
	})
	TP = Fly:CreateToggle({
		Name = 'TP Down',
		Default = true
	})
end)

run(function()
	local Mode
	local Expand
	local objects, set = {}
	
	local function createHitbox(ent)
		if ent.Targetable and ent.Player then
			local hitbox = Instance.new('Part')
			hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
			hitbox.Position = ent.RootPart.Position
			hitbox.CanCollide = false
			hitbox.Massless = true
			hitbox.Transparency = 1
			hitbox.Parent = ent.Character
			local weld = Instance.new('Motor6D')
			weld.Part0 = hitbox
			weld.Part1 = ent.RootPart
			weld.Parent = hitbox
			objects[ent] = hitbox
		end
	end
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
		Name = 'HitBoxes',
		Function = function(callback)
			if callback then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
					set = true
				else
					HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
					HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
						if objects[ent] then
							objects[ent]:Destroy()
							objects[ent] = nil
						end
					end))
					for _, ent in entitylib.List do
						createHitbox(ent)
					end
				end
			else
				if set then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
					set = nil
				end
				for _, part in objects do
					part:Destroy()
				end
				table.clear(objects)
			end
		end,
		Tooltip = 'Expands attack hitbox'
	})
	Mode = HitBoxes:CreateDropdown({
		Name = 'Mode',
		List = {'Sword', 'Player'},
		Function = function()
			if HitBoxes.Enabled then
				HitBoxes:Toggle()
				HitBoxes:Toggle()
			end
		end,
		Tooltip = 'Sword - Increases the range around you to hit entities\nPlayer - Increases the players hitbox'
	})
	Expand = HitBoxes:CreateSlider({
		Name = 'Expand amount',
		Min = 0,
		Max = 14.4,
		Default = 14.4,
		Decimal = 10,
		Function = function(val)
			if HitBoxes.Enabled then
				if Mode.Value == 'Sword' then
					debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
				else
					for _, part in objects do
						part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
					end
				end
			end
		end,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

local InfiniteJump
local VelocitySlider

run(function()
	local up = false

	InfiniteJump = vape.Categories.Blatant:CreateModule({
		Name = 'InfiniteJump',
		Function = function(callback)
			if callback then
				up = false
				InfiniteJump:Clean(runService.PreSimulation:Connect(function(dt)
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
		Tooltip = 'Jump infinitely.'
	})
	
	VelocitySlider = InfiniteJump:CreateSlider({
		Name = 'Velocity',
		Min = 10,
		Max = 150,
		Default = 50,
		Suffix = ' velocity'
	})
end)


run(function()
	vape.Categories.Blatant:CreateModule({
		Name = 'KeepSprint',
		Function = function(callback)
			debug.setconstant(bedwars.SprintController.startSprinting, 5, callback and 'blockSprinting' or 'blockSprint')
			bedwars.SprintController:stopSprinting()
		end,
		Tooltip = 'Lets you sprint with a speed potion.'
	})
end)

local Attacking
run(function()
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local ChargeTime
	local UpdateRate
	local AngleSlider
	local MaxTargets
	local Mouse
	local Swing
	local GUI
	local InstaKill
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local Particles, Boxes = {}, {}
	local SSRotations
	local hitCounter, lastHitTick = 0, tick()
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote = {SendToServer = function() end, FireServer = function() end}
	task.spawn(function()
		repeat
			local remoteName = remotes.AttackEntity
			if not remoteName or remoteName == '' then remoteName = 'SwordHit' end
			local res, obj = pcall(function()
				return bedwars.Client:Get(remoteName)
			end)
			if res and obj then
				AttackRemote = obj
			else
				local netManaged = game:GetService("ReplicatedStorage"):FindFirstChild("rbxts_include")
					and game:GetService("ReplicatedStorage").rbxts_include:FindFirstChild("node_modules")
					and game:GetService("ReplicatedStorage").rbxts_include.node_modules:FindFirstChild("@rbxts")
					and game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"]:FindFirstChild("net")
					and game:GetService("ReplicatedStorage").rbxts_include.node_modules["@rbxts"].net.out:FindFirstChild("_NetManaged")
				local rawRemote = netManaged and netManaged:FindFirstChild("SwordHit")
				if rawRemote then
					AttackRemote = rawRemote
				end
			end
			task.wait(0.5)
		until AttackRemote and (typeof(AttackRemote.SendToServer) == 'function' or typeof(AttackRemote.FireServer) == 'function' or (typeof(AttackRemote) == 'Instance' and AttackRemote:IsA('RemoteEvent')))
	end)

	local function getAttackData()
		if Mouse.Enabled then
			if not inputService:IsMouseButtonPressed(0) then return false end
		end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if Limit.Enabled then
			if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
		end

		if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'Killaura',
		Function = function(callback)
			if callback then
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit.Enabled
					end)
				end

				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
					local fake = {
						Controllers = {
							ViewmodelController = {
								isVisible = function()
									return not Attacking
								end,
								playAnimation = function(...)
									if not Attacking then
										bedwars.ViewmodelController:playAnimation(select(2, ...))
									end
								end
							}
						}
					}
					pcall(function()
						local func = oldSwing or bedwars.SwordController.playSwordEffect
						for i = 1, 20 do
							local name, val = debug.getupvalue(func, i)
							if not name then break end
							if name == 'KnitClient' or (type(val) == 'table' and val.Controllers) then
								debug.setupvalue(func, i, fake)
								break
							end
						end
					end)
					pcall(function()
						local func = bedwars.ScytheController.playLocalAnimation
						for i = 1, 20 do
							local name, val = debug.getupvalue(func, i)
							if not name then break end
							if name == 'KnitClient' or (type(val) == 'table' and val.Controllers) then
								debug.setupvalue(func, i, fake)
								break
							end
						end
					end)

					task.spawn(function()
						local started = false
						repeat
							if Attacking then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end
								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
								end

								for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
										C0 = armC0 * v.CFrame
									})
									AnimTween:Play()
									AnimTween.Completed:Wait()
									first = false
									if (not Killaura.Enabled) or (not Attacking) then break end
								end
							elseif started then
								started = false
								AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
									C0 = armC0
								})
								AnimTween:Play()
							end

							if not started then
								task.wait(1 / UpdateRate.Value)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				repeat
					local attacked, sword, meta = {}, getAttackData()
					Attacking = false
					store.KillauraTarget = nil
					if sword then
						local plrs = entitylib.AllPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = sortmethods[Sort.Value]
						})

						if #plrs > 0 then
							switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)

							for _, v in plrs do
								local delta = (v.RootPart.Position - selfpos)
								local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

								table.insert(attacked, {
									Entity = v,
									Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
								})
								targetinfo.Targets[v] = tick() + 1

								if not Attacking then
									Attacking = true
									store.KillauraTarget = v
									if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + (meta.sword.respectAttackSpeedForEffects and meta.sword.attackSpeed or 0.11)
										pcall(function()
											bedwars.SwordController:playSwordEffect(meta, false)
										end)
										if meta and meta.displayName and meta.displayName:find(' Scythe') then
											pcall(function()
												bedwars.ScytheController:playLocalAnimation()
											end)
										end

										if vape.ThreadFix then
											setthreadidentity(8)
										end
									end
								end

								local actualRoot = v.Character.PrimaryPart
								if actualRoot then
									local targetPos = actualRoot.Position
									local camPos = gameCamera.CFrame.Position
									local fakeSelfPos = selfpos
									local reachDist = delta.Magnitude

									local dir = (targetPos - camPos).Unit
									local wallCamPos = camPos
									if targetPos and camPos and (targetPos - camPos).Magnitude > 20 then
										wallCamPos = targetPos - dir * 1.5
									end
									if reachDist > 18 then
										fakeSelfPos = targetPos - (selfpos - targetPos).Unit * 18
									end

									bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
									store.attackReach = (reachDist * 100) // 1 / 100
									store.attackReachUpdate = tick() + 1

									local attackData = {
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = wallCamPos},
												cursorDirection = {value = dir}
											},
											targetPosition = {value = targetPos},
											selfPosition = {value = fakeSelfPos}
										}
									}

									local sendSuccess = false
									hitCounter = hitCounter + 1
									local hitCount = InstaKill and InstaKill.Enabled and 50 or 1
									for _ = 1, hitCount do
										if typeof(AttackRemote) == 'table' and typeof(AttackRemote.SendToServer) == 'function' then
											sendSuccess = pcall(function() AttackRemote:SendToServer(attackData) end)
										elseif typeof(AttackRemote) == 'Instance' then
											sendSuccess = pcall(function() AttackRemote:FireServer(attackData) end)
										elseif typeof(AttackRemote) == 'table' and typeof(AttackRemote.instance) == 'Instance' then
											sendSuccess = pcall(function() AttackRemote.instance:FireServer(attackData) end)
										end
									end
								end
							end
						end
					end

					for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
						if v.Adornee then
							v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
							v.Transparency = 1 - attacked[i].Check.Opacity
						end
					end

					for i, v in Particles do
						v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
						v.Parent = attacked[i] and gameCamera or nil
					end

					if Face.Enabled and attacked[1] then
						local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
						entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
					end

					if #attacked == 0 and hitCounter > 0 and (tick() - lastHitTick) > 1.5 then
						hitCounter = 0
					end
					if #attacked > 0 then
						lastHitTick = tick()
						local extra
						if hitCounter > 28 then
							extra = 0.1
						elseif hitCounter > 20 then
							extra = 0.06
						elseif hitCounter > 12 then
							extra = 0.03
						else
							extra = 0
						end
						task.wait(#attacked * 0.02 + extra + math.random() * 0.005)
					else
						task.wait(1 / UpdateRate.Value)
					end
				until not Killaura.Enabled
			else
				hitCounter = 0
				store.KillauraTarget = nil
				for _, v in Boxes do
					v.Adornee = nil
				end
				for _, v in Particles do
					v.Parent = nil
				end
				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end
				pcall(function()
					local func = oldSwing or bedwars.SwordController.playSwordEffect
					for i = 1, 20 do
						local name, val = debug.getupvalue(func, i)
						if not name then break end
						if name == 'KnitClient' or (type(val) == 'table' and val.Controllers) then
							debug.setupvalue(func, i, bedwars.Knit)
							break
						end
					end
				end)
				pcall(function()
					local func = bedwars.ScytheController.playLocalAnimation
					for i = 1, 20 do
						local name, val = debug.getupvalue(func, i)
						if not name then break end
						if name == 'KnitClient' or (type(val) == 'table' and val.Controllers) then
							debug.setupvalue(func, i, bedwars.Knit)
							break
						end
					end
				end)
				Attacking = false
				if armC0 then
					AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
						C0 = armC0
					})
					AnimTween:Play()
				end
			end
		end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
	})
	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})
	local methods = {'Damage', 'Distance'}
	for i in sortmethods do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 45,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 45,
		Default = 28,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})
	UpdateRate = Killaura:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 240,
		Default = 120,
		Suffix = 'hz'
	})
	MaxTargets = Killaura:CreateSlider({
		Name = 'Max targets',
		Min = 1,
		Max = 10,
		Default = 10
	})
	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = methods
	})
	Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Swing = Killaura:CreateToggle({Name = 'No Swing'})
	GUI = Killaura:CreateToggle({Name = 'GUI check'})
	InstaKill = Killaura:CreateToggle({Name = 'InstaKill'})
	Killaura:CreateToggle({
		Name = 'Show target',
		Function = function(callback)
			BoxSwingColor.Object.Visible = callback
			BoxAttackColor.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local box = Instance.new('BoxHandleAdornment')
					box.Adornee = nil
					box.AlwaysOnTop = true
					box.Size = Vector3.new(3, 5, 3)
					box.CFrame = CFrame.new(0, -0.5, 0)
					box.ZIndex = 0
					box.Parent = vape.gui
					Boxes[i] = box
				end
			else
				for _, v in Boxes do
					v:Destroy()
				end
				table.clear(Boxes)
			end
		end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5,
		Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
		Name = 'Attack Color',
		Darker = true,
		DefaultOpacity = 0.5,
		Visible = false
	})
	Killaura:CreateToggle({
		Name = 'Target particles',
		Function = function(callback)
			ParticleTexture.Object.Visible = callback
			ParticleColor1.Object.Visible = callback
			ParticleColor2.Object.Visible = callback
			ParticleSize.Object.Visible = callback
			if callback then
				for i = 1, 10 do
					local part = Instance.new('Part')
					part.Size = Vector3.new(2, 4, 2)
					part.Anchored = true
					part.CanCollide = false
					part.Transparency = 1
					part.CanQuery = false
					part.Parent = Killaura.Enabled and gameCamera or nil
					local particles = Instance.new('ParticleEmitter')
					particles.Brightness = 1.5
					particles.Size = NumberSequence.new(ParticleSize.Value)
					particles.Shape = Enum.ParticleEmitterShape.Sphere
					particles.Texture = ParticleTexture.Value
					particles.Transparency = NumberSequence.new(0)
					particles.Lifetime = NumberRange.new(0.4)
					particles.Speed = NumberRange.new(16)
					particles.Rate = 128
					particles.Drag = 16
					particles.ShapePartial = 1
					particles.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
					})
					particles.Parent = part
					Particles[i] = part
				end
			else
				for _, v in Particles do
					v:Destroy()
				end
				table.clear(Particles)
			end
		end
	})
	ParticleTexture = Killaura:CreateTextBox({
		Name = 'Texture',
		Default = 'rbxassetid://14736249347',
		Function = function()
			for _, v in Particles do
				v.ParticleEmitter.Texture = ParticleTexture.Value
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
		Name = 'Color Begin',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
		Name = 'Color End',
		Function = function(hue, sat, val)
			for _, v in Particles do
				v.ParticleEmitter.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
				})
			end
		end,
		Darker = true,
		Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
		Name = 'Size',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Function = function(val)
			for _, v in Particles do
				v.ParticleEmitter.Size = NumberSequence.new(val)
			end
		end,
		Darker = true,
		Visible = false
	})
	Face = Killaura:CreateToggle({Name = 'Face target'})
	SSRotations = Killaura:CreateToggle({
		Name = 'ServerSide Rotations',
		Tooltip = 'Applies rotation data on attacks.\nNo visible client-side changes.'
	})
	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			AnimationMode.Object.Visible = callback
			AnimationTween.Object.Visible = callback
			AnimationSpeed.Object.Visible = callback
			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})
	local animnames = {}
	for i in anims do
		table.insert(animnames, i)
	end
	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})
	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when the sword is held'
	})
	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks while swinging manually'
	})
end)

run(function()
	local Value
	local CameraDir
	local start
	local JumpTick, JumpSpeed, Direction = tick(), 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		repeat task.wait() until remotes.FireProjectile and remotes.FireProjectile ~= ''
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function launchProjectile(item, pos, proj, speed, dir)
		if not item or not pos then return end
	
		local id = httpService:GenerateGUID(true)
		local shotId = httpService:GenerateGUID(false)
		pos = pos - dir * 0.1
		local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
		switchItem(item.tool)
		task.wait(0.05)
		bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, id, shootPosition.LookVector * speed, {drawDurationSeconds = 1})
		if projectileRemote:InvokeServer(item.itemType or item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, id, {drawDurationSeconds = 1, shotId = shotId}, workspace:GetServerTimeNow() - 0.045) then
			local shoot = bedwars.ItemMeta[item.itemType] and bedwars.ItemMeta[item.itemType].projectileSource and bedwars.ItemMeta[item.itemType].projectileSource.launchSound
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
			if shoot then
				bedwars.SoundManager:playSound(shoot)
			end
		end
	end
	
	local LongJumpMethods = {
		cannon = function(_, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			bedwars.placeBlock(rounded, 'cannon', false)
	
			task.delay(0, function()
				local block, blockpos = getPlacedBlock(rounded)
				if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
					local breaktype = bedwars.ItemMeta[block.Name].block.breakType
					local tool = store.tools[breaktype]
					if tool then
						switchItem(tool.tool)
					end
	
					bedwars.Client:Get(remotes.CannonAim):SendToServer({
						cannonBlockPos = blockpos,
						lookVector = dir
					})
	
					local broken = 0.1
					if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
						broken = 0.4
						bedwars.breakBlock(block, true, true)
					end
	
					task.delay(broken, function()
						for _ = 1, 3 do
							local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
							if call then
								bedwars.breakBlock(block, true, true)
								JumpSpeed = 5.25 * Value.Value
								JumpTick = tick() + 2.3
								Direction = Vector3.new(dir.X, 0, dir.Z).Unit
								break
							end
							task.wait(0.1)
						end
					end)
				end
			end)
		end,
		cat = function(_, _, dir)
			LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
				JumpSpeed = 4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
				entitylib.character.RootPart.Velocity = Vector3.zero
			end))
	
			if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, pos, dir)
			-- Aim fireball down/backward at feet to guarantee self damage explosion knockback
			local shootDir = -dir + Vector3.new(0, -1, 0)
			launchProjectile(item, pos, 'fireball', 60, shootDir.Unit)
		end,
		grappling_hook = function(item, pos, dir)
			launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
		end,
		jade_hammer = function(item, _, dir)
			if not bedwars.AbilityController:canUseAbility(item.itemType..'_jump') then
				repeat task.wait() until bedwars.AbilityController:canUseAbility(item.itemType..'_jump') or not LongJump.Enabled
			end
	
			if bedwars.AbilityController:canUseAbility(item.itemType..'_jump') and LongJump.Enabled then
				bedwars.AbilityController:useAbility(item.itemType..'_jump')
				JumpSpeed = 1.4 * Value.Value
				JumpTick = tick() + 2.5
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end,
		tnt = function(item, pos, dir)
			pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
			local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
			start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, pos, dir)
			if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
				repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
			end
	
			if LongJump.Enabled then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = dir,
					origin = pos,
					weapon = item.itemType
				})
				JumpSpeed = 4.5 * Value.Value
				JumpTick = tick() + 2.4
				Direction = Vector3.new(dir.X, 0, dir.Z).Unit
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		LongJumpMethods[v] = LongJumpMethods.wood_dao
	end
	LongJumpMethods.void_axe = LongJumpMethods.jade_hammer
	LongJumpMethods.siege_tnt = LongJumpMethods.tnt
	LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt
	
	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.entityInstance == lplr.Character and (damageTable.fromEntity == lplr.Character or damageTable.fromEntity == nil) and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
						local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
							vertical = 0,
							horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
						}).Magnitude * 1.1
	
						if knockbackBoost >= JumpSpeed then
							local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or (damageTable.fromEntity and damageTable.fromEntity.PrimaryPart and damageTable.fromEntity.PrimaryPart.Position)
							if not pos then pos = entitylib.character.RootPart.Position end
							local vec = (entitylib.character.RootPart.Position - pos)
							if vec.Magnitude == 0 then vec = (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector end
							JumpSpeed = knockbackBoost
							JumpTick = tick() + 2.5
							Direction = Vector3.new(vec.X, 0, vec.Z).Unit
						end
					end
				end))
				LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
					if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
						local vec = entitylib.character.RootPart.CFrame.LookVector
						JumpSpeed = 2.5 * Value.Value
						JumpTick = tick() + 2.5
						Direction = Vector3.new(vec.X, 0, vec.Z).Unit
					end
				end))
	
				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
	
					if root and isnetworkowner(root) then
						if JumpTick > tick() then
							root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
							if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
								root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
							else
								root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
							end
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							JumpSpeed = 0
						end
					else
						start = nil
					end
				end))
	
				if store.hand and LongJumpMethods[store.hand.tool.Name] then
					task.spawn(LongJumpMethods[store.hand.tool.Name], getItem(store.hand.tool.Name), start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
					return
				end
	
				for i, v in LongJumpMethods do
					local item = getItem(i)
					if item or store.equippedKit == i then
						task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
						break
					end
				end
			else
				JumpTick = tick()
				Direction = nil
				JumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
end)

run(function()
	local NoFall
	local groundHitEvent
	
	local function findGroundHitEvent()
		local suc, tsRemotes = pcall(function() return require(game:GetService("ReplicatedStorage").TS.remotes).default end)
		if suc and tsRemotes then
			local suc2, event = pcall(function() return tsRemotes.Client:Get("GroundHit") end)
			if suc2 and event and type(event.SendToServer) == "function" then
				return event
			end
		end
		return nil
	end
	
	local oldSendToServer
	NoFall = vape.Categories.Blatant:CreateModule({
		Name = 'NoFall',
		Function = function(callback)
			if callback then
				if not groundHitEvent then groundHitEvent = findGroundHitEvent() end
				
				if groundHitEvent then
					if not oldSendToServer then
						oldSendToServer = groundHitEvent.SendToServer
						groundHitEvent.SendToServer = function(self, data, ...)
							if NoFall.Enabled and type(data) == "table" and typeof(data.velocity) == "Vector3" then
								data = table.clone(data)
								data.velocity = Vector3.new(data.velocity.X, -10, data.velocity.Z)
							end
							return oldSendToServer(self, data, ...)
						end
					end
				else
					warningNotification('NoFall', 'Failed to find GroundHit event', 3)
				end
			end
		end,
		Tooltip = 'Prevents taking fall damage by spoofing impact velocity.'
	})
end)

run(function()
	local old
	
	vape.Categories.Blatant:CreateModule({
		Name = 'NoSlowdown',
		Function = function(callback)
			local modifier = bedwars.SprintController:getMovementStatusModifier()
			if callback then
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if tab.moveSpeedMultiplier then
						tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
					end
					return old(self, tab)
				end
	
				for i in modifier.modifiers do
					if (i.moveSpeedMultiplier or 1) < 1 then
						modifier:removeModifier(i)
					end
				end
			else
				modifier.addModifier = old
				old = nil
			end
		end,
		Tooltip = 'Prevents slowing down when using items.'
	})
end)

run(function()
	local TargetPart
	local Targets
	local FOV
	local OtherProjectiles
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	local old
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.calculateImportantLaunchValues
				bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
					local self, projmeta, worldmeta, origin, shootpos = ...
					local plr = entitylib.EntityMouse({
						Part = 'RootPart',
						Range = FOV.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled,
						Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
					})
	
					if plr then
						local pos = shootpos or self:getLaunchPosition(origin)
						if not pos then
							return old(...)
						end
	
						if (not OtherProjectiles.Enabled) and not projmeta.projectile:find('arrow') then
							return old(...)
						end
	
						local meta = projmeta:getProjectileMeta()
						local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
						local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
						local projSpeed = (meta.launchVelocity or 100)
						local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
						local balloons = plr.Character:GetAttribute('InflatedBalloons')
						local playerGravity = workspace.Gravity
	
						if balloons and balloons > 0 then
							playerGravity = (workspace.Gravity * (1 - ((balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))))
						end
	
						if plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
							playerGravity = 6
						end
	
						if plr.Player:GetAttribute('IsOwlTarget') then
							for _, owl in collectionService:GetTagged('Owl') do
								if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
									playerGravity = 0
								end
							end
						end
	
						local newlook = CFrame.new(offsetpos, plr[TargetPart.Value].Position) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
						local calc = prediction.SolveTrajectory(newlook.p, projSpeed, gravity, plr[TargetPart.Value].Position, projmeta.projectile == 'telepearl' and Vector3.zero or plr[TargetPart.Value].Velocity, playerGravity, plr.HipHeight, plr.Jumping and 42.6 or nil, rayCheck)
						if calc then
							targetinfo.Targets[plr] = tick() + 1
							return {
								initialVelocity = CFrame.new(newlook.Position, calc).LookVector * projSpeed,
								positionFrom = offsetpos,
								deltaT = lifetime,
								gravitationalAcceleration = gravity,
								drawDurationSeconds = 5
							}
						end
					end
	
					return old(...)
				end
			else
				bedwars.ProjectileController.calculateImportantLaunchValues = old
			end
		end,
		Tooltip = 'Silently adjusts your aim towards the enemy'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
end)

run(function()
	local ProjectileAura
	local Targets
	local Range
	local List
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function() end}
	local FireDelays = {}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)
	
	local function getAmmo(check)
		for _, item in store.inventory.inventory.items do
			if check.ammoItemTypes and table.find(check.ammoItemTypes, item.itemType) then
				return item.itemType
			end
		end
	end
	
	local function getProjectiles()
		local items = {}
		for _, item in store.inventory.inventory.items do
			local proj = bedwars.ItemMeta[item.itemType].projectileSource
			local ammo = proj and getAmmo(proj)
			if ammo and table.find(List.ListEnabled, ammo) then
				table.insert(items, {
					item,
					ammo,
					proj.projectileType(ammo),
					proj
				})
			end
		end
		return items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAura',
		Function = function(callback)
			if callback then
				repeat
					if (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 0.5 then
						local ent = entitylib.EntityPosition({
							Part = 'RootPart',
							Range = Range.Value,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})
	
						if ent then
							local pos = entitylib.character.RootPart.Position
							for _, data in getProjectiles() do
								local item, ammo, projectile, itemMeta = unpack(data)
								if (FireDelays[item.itemType] or 0) < tick() then
									rayCheck.FilterDescendantsInstances = {workspace.Map}
									local meta = bedwars.ProjectileMeta[projectile]
									local projSpeed, gravity = meta.launchVelocity, meta.gravitationalAcceleration or 196.2
									local calc = prediction.SolveTrajectory(pos, projSpeed, gravity, ent.RootPart.Position, ent.RootPart.Velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayCheck)
									if calc then
										targetinfo.Targets[ent] = tick() + 1
										local switched = switchItem(item.tool)
	
										task.spawn(function()
											local dir, id = CFrame.lookAt(pos, calc).LookVector, httpService:GenerateGUID(true)
											local shootPosition = (CFrame.new(pos, calc) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
											bedwars.ProjectileController:createLocalProjectile(meta, ammo, projectile, shootPosition, id, dir * projSpeed, {drawDurationSeconds = 1})
											local res = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootPosition, pos, dir * projSpeed, id, {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
											if not res then
												FireDelays[item.itemType] = tick()
											else
												local shoot = itemMeta.launchSound
												shoot = shoot and shoot[math.random(1, #shoot)] or nil
												if shoot then
													bedwars.SoundManager:playSound(shoot)
												end
											end
										end)
	
										FireDelays[item.itemType] = tick() + itemMeta.fireDelaySec
										if switched then
											task.wait(0.05)
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not ProjectileAura.Enabled
			end
		end,
		Tooltip = 'Shoots people around you'
	})
	Targets = ProjectileAura:CreateTargets({
		Players = true,
		Walls = true
	})
	List = ProjectileAura:CreateTextList({
		Name = 'Projectiles',
		Default = {'arrow', 'snowball'}
	})
	Range = ProjectileAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local Speed
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			frictionTable.Speed = callback or nil
			updateVelocity()
			pcall(function()
				debug.setconstant(bedwars.WindWalkerController.updateSpeed, 7, callback and 'constantSpeedMultiplier' or 'moveSpeedMultiplier')
			end)
	
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					bedwars.StatefulEntityKnockbackController.lastImpulseTime = callback and math.huge or time()
					local flyActive = (Fly and Fly.Enabled) or (InfiniteFly and InfiniteFly.Enabled) or (LongJump and LongJump.Enabled)
					if entitylib.isAlive and not flyActive and isnetworkowner(entitylib.character.RootPart) then
						local state = entitylib.character.Humanoid:GetState()
						if state == Enum.HumanoidStateType.Climbing then return end
	
						local root, velo = entitylib.character.RootPart, getSpeed()
						local moveDirection = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
						local destination = (moveDirection * math.max(Value.Value - velo, 0) * dt)
	
						if WallCheck.Enabled then
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
							rayCheck.CollisionGroup = root.CollisionGroup
							local ray = workspace:Raycast(root.Position, destination, rayCheck)
							if ray then
								destination = ((ray.Position + ray.Normal) - root.Position)
							end
						end
	
						root.CFrame += destination
						root.AssemblyLinearVelocity = (moveDirection * velo) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
						if AutoJump.Enabled and (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDirection ~= Vector3.zero and (Attacking or AlwaysJump.Enabled) then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
				end))
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Increases your movement with various methods.'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 23,
		Default = 23,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true
	})
	AutoJump = Speed:CreateToggle({
		Name = 'AutoJump',
		Function = function(callback)
			AlwaysJump.Object.Visible = callback
		end
	})
	AlwaysJump = Speed:CreateToggle({
		Name = 'Always Jump',
		Visible = false,
		Darker = true
	})
end)

run(function()
	local PounceBoost
	local BoostDuration
	local BoostPower
	local WallCheck
	local AutoJump
	local AlwaysJump
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	
	local bv
	local oldLeap
	local function leapHook(self, char, dir)
		local hrp = char and char.HumanoidRootPart
		if hrp and isnetworkowner(hrp) then
			local power = BoostPower.Value
			local horizontalDir = (dir * Vector3.new(1, 0, 1)).Unit
			if horizontalDir.Magnitude < 0.01 then
				horizontalDir = (gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
			end
			oldLeap(self, char, dir)
			local mass = hrp.AssemblyMass or 1
			hrp:ApplyImpulse(horizontalDir * mass * (power * 5.0))
			JumpDir = horizontalDir
			JumpSpeed = power * 5.0
			JumpTick = tick() + BoostDuration.Value
			if bv then
				bv.Parent = nil
				bv:Destroy()
			end
			bv = Instance.new("BodyVelocity")
			bv.Velocity = horizontalDir * JumpSpeed + Vector3.new(0, hrp.Velocity.Y, 0)
			bv.MaxForce = Vector3.new(9e9, 0, 9e9)
			bv.Parent = hrp
		else
			oldLeap(self, char, dir)
		end
	end
	
	PounceBoost = vape.Categories.Blatant:CreateModule({
	    Name = 'YaminiLongJump',
	    Function = function(callback)
	        if callback then
				oldLeap = bedwars.CatController.leap
				bedwars.CatController.leap = leapHook
				PounceBoost:Clean(function()
					if bedwars.CatController.leap == leapHook then
						bedwars.CatController.leap = oldLeap
					end
				end)
	            PounceBoost:Clean(vapeEvents.CatPounce.Event:Connect(function()
	                vape:CreateNotification('YaminiLongJump', 'found cat_pounce boost 1.5sec', 3)
	            end))
	            PounceBoost:Clean(runService.PreSimulation:Connect(function(dt)
	                local root = entitylib.isAlive and entitylib.character.RootPart or nil
	                if not root or not isnetworkowner(root) then return end
	                if JumpTick > tick() then
	                    local remaining = (JumpTick - tick()) / BoostDuration.Value
	                    local speed = JumpSpeed * remaining
	                    local moveDir = entitylib.isAlive and entitylib.character.Humanoid.MoveDirection or Vector3.zero
	                    local finalDir = moveDir.Magnitude > 0 and moveDir.Unit or JumpDir
	                    if WallCheck.Enabled then
	                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	                        rayCheck.CollisionGroup = root.CollisionGroup
	                        local destination = finalDir * speed * dt
	                        local ray = workspace:Raycast(root.Position, destination, rayCheck)
	                        if ray then
	                            finalDir = ((ray.Position + ray.Normal) - root.Position).Unit
	                        end
	                    end
	                    if bv and bv.Parent then
	                        bv.Velocity = finalDir * speed + Vector3.new(0, 0, 0)
	                    end
	                    if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
	                        root.AssemblyLinearVelocity = finalDir * speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	                        root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
	                    else
	                        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
	                    end
	                    if AutoJump.Enabled then
	                        local state = entitylib.character.Humanoid:GetState()
	                        if (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and moveDir.Magnitude > 0 and (AlwaysJump.Enabled) then
	                            entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                    end
	                elseif bv and bv.Parent then
	                    bv:Destroy()
	                    bv = nil
	                end
	            end))
	            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
	                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not PounceBoost.Enabled
	            end
	            if PounceBoost.Enabled then
	                bedwars.AbilityController:useAbility('CAT_POUNCE')
	            end
	        else
	            JumpTick = tick()
	            JumpSpeed = 0
	            if bv then
	                bv:Destroy()
	                bv = nil
	            end
	        end
	    end,
	    ExtraText = function()
	        return 'Heatseeker'
	    end,
	    Tooltip = 'Boosts your Cat pounce using a BodyVelocity force override.'
	})
	
	BoostDuration = PounceBoost:CreateSlider({
	    Name = 'Boost Duration',
	    Min = 0.5,
	    Max = 3.0,
	    Default = 1.5,
	    Decimal = true,
	    Suffix = function(val)
	        return val .. 's'
	    end
	})
	
	BoostPower = PounceBoost:CreateSlider({
	    Name = 'Boost Power',
	    Min = 10,
	    Max = 300,
	    Default = 100,
	    Suffix = function(val)
	        return val == 1 and 'force' or 'force'
	    end
	})
	
	WallCheck = PounceBoost:CreateToggle({
	    Name = 'Wall Check',
	    Default = true
	})
	
	AutoJump = PounceBoost:CreateToggle({
	    Name = 'AutoJump',
	    Function = function(callback)
	        AlwaysJump.Object.Visible = callback
	    end
	})
	
	AlwaysJump = PounceBoost:CreateToggle({
	    Name = 'Always Jump',
	    Visible = false,
	    Darker = true
	})
	
end)

run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local Settings = {
		Width = 170,
		Height = 34,
		ExpandedWidth = 270,
		YPos = 12,
		Colors = {
			Background = Color3.fromRGB(0, 0, 0),
			Stroke = Color3.fromRGB(40, 40, 40),
			Success = Color3.fromRGB(48, 209, 88),
			Error = Color3.fromRGB(255, 69, 58)
		}
	}

	-- Dictionary tracking active modules: [ModuleName] = {Frame, Dot, Label, Scale, Thread}
	local ActiveNotifs = {} 
	local LayoutIndex = 0
	
	-- Snappy 1:1 Apple Easing
	local function AppleTween(inst, props, dur)
		local info = TweenInfo.new(dur or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local t = TweenService:Create(inst, info, props)
		t:Play()
		return t
	end

	local function GetNotifCount()
		local count = 0
		for _ in pairs(ActiveNotifs) do count += 1 end
		return count
	end

	local GUI = Instance.new("ScreenGui")
	GUI.Name = "DynamicIsland"; GUI.ResetOnSpawn = false; GUI.IgnoreGuiInset = true
	GUI.Parent = lplr:WaitForChild("PlayerGui")

	-- Main Container
	local Island = Instance.new("CanvasGroup")
	Island.Size = UDim2.new(0, Settings.Width, 0, Settings.Height)
	Island.Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
	Island.BackgroundColor3 = Settings.Colors.Background
	Island.BorderSizePixel = 0
	Island.ClipsDescendants = true
	Island.Visible = false
	Island.Parent = GUI

	local Corner = Instance.new("UICorner"); Corner.CornerRadius = UDim.new(0, 100); Corner.Parent = Island
	local Stroke = Instance.new("UIStroke"); Stroke.Color = Settings.Colors.Stroke; Stroke.Thickness = 1; Stroke.Parent = Island

	-- COMPACT LAYER (Logo/Clock)
	local CompactLayer = Instance.new("Frame")
	CompactLayer.Size = UDim2.new(1, 0, 1, 0)
	CompactLayer.BackgroundTransparency = 1
	CompactLayer.Parent = Island

	local Logo = Instance.new("TextLabel")
	Logo.Size = UDim2.new(0, 60, 1, 0); Logo.Position = UDim2.new(0, 20, 0, 0)
	Logo.BackgroundTransparency = 1; Logo.Text = "VAPE"; Logo.TextColor3 = Color3.new(1,1,1)
	Logo.TextSize = 11; Logo.Font = Enum.Font.GothamBold; Logo.TextXAlignment = Enum.TextXAlignment.Left; Logo.Parent = CompactLayer

	local Clock = Instance.new("TextLabel")
	Clock.Size = UDim2.new(0, 60, 1, 0); Clock.Position = UDim2.new(1, -80, 0, 0)
	Clock.BackgroundTransparency = 1; Clock.Text = os.date("%H:%M"); Clock.TextColor3 = Color3.fromRGB(140, 140, 140)
	Clock.TextSize = 11; Clock.Font = Enum.Font.GothamBold; Clock.TextXAlignment = Enum.TextXAlignment.Right; Clock.Parent = CompactLayer

	-- NOTIFICATION LAYER
	local NotifLayer = Instance.new("Frame")
	NotifLayer.Size = UDim2.new(1, 0, 1, 0)
	NotifLayer.BackgroundTransparency = 1
	NotifLayer.Visible = false
	NotifLayer.Parent = Island

	-- UIPadding simulates the HTML 12px top/bottom padding
	local Padding = Instance.new("UIPadding")
	Padding.PaddingTop = UDim.new(0, 12); Padding.PaddingBottom = UDim.new(0, 12); Padding.Parent = NotifLayer

	local List = Instance.new("UIListLayout")
	List.Parent = NotifLayer; List.Padding = UDim.new(0, 6); List.HorizontalAlignment = Enum.HorizontalAlignment.Center
	List.SortOrder = Enum.SortOrder.LayoutOrder

	local function UpdateIsland()
		local count = GetNotifCount()
		
		if count > 0 then
			CompactLayer.Visible = false
			NotifLayer.Visible = true
			
			-- Calculate exact height required based on active rows
			local dynamicHeight = 24 + (count * 24) + (math.max(0, count - 1) * 6)
			
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.ExpandedWidth, 0, dynamicHeight),
				Position = UDim2.new(0.5, -Settings.ExpandedWidth/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 22)})
		else
			-- Shrink back to Compact mode
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.Width, 0, Settings.Height),
				Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 100)})
			
			task.delay(0.3, function()
				if GetNotifCount() == 0 then 
					CompactLayer.Visible = true 
					NotifLayer.Visible = false
				end
			end)
		end
	end

	local function RemoveNotif(moduleName)
		local data = ActiveNotifs[moduleName]
		if not data then return end

		-- Untrack immediately so UpdateIsland shrinks the main CanvasGroup
		ActiveNotifs[moduleName] = nil
		UpdateIsland()

		-- Smoothly collapse the row inside the ListLayout
		AppleTween(data.Frame, {Size = UDim2.new(0.9, 0, 0, 0)}, 0.3)
		AppleTween(data.Label, {TextTransparency = 1}, 0.2)

		task.delay(0.3, function()
			if data.Frame then data.Frame:Destroy() end
		end)
	end

	function ShowNotif(moduleName, isEnabled)
		local statusColor = isEnabled and Settings.Colors.Success or Settings.Colors.Error
		local colorHex = isEnabled and "#30D158" or "#FF453A"
		local statusText = isEnabled and "Enabled" or "Disabled"
		local fullText = moduleName .. " <font color='" .. colorHex .. "'>" .. statusText .. "</font>"

		-- IF NOTIFICATION IS ALREADY VISIBLE (Morph Update)
		if ActiveNotifs[moduleName] then
			local data = ActiveNotifs[moduleName]
			
			-- Cancel the existing destruction thread to keep it alive
			if data.Thread then task.cancel(data.Thread) end

			-- 1. Tween Dot Color
			AppleTween(data.Dot, {BackgroundColor3 = statusColor}, 0.3)

			-- 2. Frame Pop Animation
			AppleTween(data.Scale, {Scale = 1.03}, 0.15).Completed:Connect(function()
				AppleTween(data.Scale, {Scale = 1}, 0.15)
			end)

			-- 3. Text Slide Fade out -> Change Text -> Slide Fade In
			AppleTween(data.Label, {TextTransparency = 1, Position = UDim2.new(0, 18, 0, -8)}, 0.15)
			task.delay(0.15, function()
				if not data.Label.Parent then return end
				data.Label.Text = fullText
				data.Label.Position = UDim2.new(0, 18, 0, 8) -- Prep slide in from bottom
				AppleTween(data.Label, {TextTransparency = 0, Position = UDim2.new(0, 18, 0, 0)}, 0.15)
			end)

			-- Restart death timer
			data.Thread = task.delay(3, function() RemoveNotif(moduleName) end)
			return
		end

		-- OTHERWISE, CREATE A NEW ROW
		LayoutIndex += 1

		local item = Instance.new("Frame")
		item.Size = UDim2.new(0.9, 0, 0, 24)
		item.BackgroundTransparency = 1
		item.ClipsDescendants = true -- Crucial for collapse animation
		item.LayoutOrder = LayoutIndex
		item.Parent = NotifLayer

		local scale = Instance.new("UIScale"); scale.Parent = item

		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 4, 0.5, -3)
		dot.BackgroundColor3 = statusColor
		dot.BorderSizePixel = 0; dot.Parent = item
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0)
		lbl.Text = fullText
		lbl.RichText = true; lbl.TextColor3 = Color3.new(1,1,1); lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = item

		-- Save references to the dictionary
		ActiveNotifs[moduleName] = {
			Frame = item,
			Dot = dot,
			Label = lbl,
			Scale = scale,
			Thread = task.delay(3, function() RemoveNotif(moduleName) end)
		}

		UpdateIsland()
	end

	-- Real-time Clock Update
	task.spawn(function()
		while task.wait(1) do Clock.Text = os.date("%H:%M") end
	end)

	NotificationIsland = vape.Categories.Render:CreateModule({
		Name = 'Notification Island',
		Function = function(callback)
			if callback then
				Island.Visible = true
				local old = vape.CreateNotification
				
				-- Override Vape's notification behavior
				vape.CreateNotification = function(_, title, text, dur, t)
					if title == 'Module Toggled' then
						local clean = text:gsub("<[^>]+>", "")
						local name = clean:match("(.+) has been ")
						local enabled = clean:find("Enabled")
						
						if name then 
							ShowNotif(name, enabled ~= nil) 
						end
						return
					end
					return old(_, title, text, dur, t)
				end
				
				NotificationIsland:Clean(function() 
					vape.CreateNotification = old
					Island.Visible = false 
					
					-- Clear active trackers on module disable
					for mod, _ in pairs(ActiveNotifs) do
						RemoveNotif(mod)
					end
				end)
			else
				Island.Visible = false
			end
		end
	})
end)

run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")
	
	local TestModule
	local GUI
	local connection
	
	local function createUI()
		if GUI then GUI:Destroy() end
		
		GUI = Instance.new("ScreenGui")
		GUI.Name = "TestVapeUI"
		GUI.ResetOnSpawn = false
		GUI.IgnoreGuiInset = true
		GUI.DisplayOrder = 1000
		
		local success, parent = pcall(function() return lplr:WaitForChild("PlayerGui") end)
		if not success then parent = game:GetService("CoreGui") end
		GUI.Parent = parent
		
		-- Background dim
		local bg = Instance.new("Frame")
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 1
		bg.BorderSizePixel = 0
		bg.Parent = GUI
		
		-- 1. Splash Screen Layer
		local splashLayer = Instance.new("Frame")
		splashLayer.Size = UDim2.new(1, 0, 1, 0)
		splashLayer.BackgroundTransparency = 1
		splashLayer.Parent = GUI
		
		local helloText = Instance.new("TextLabel")
		helloText.Size = UDim2.new(1, 0, 1, 0)
		helloText.Position = UDim2.new(-1, 0, 1, 0) -- starts bottom left
		helloText.BackgroundTransparency = 1
		helloText.Text = "Hello!"
		helloText.TextColor3 = Color3.fromRGB(255, 255, 255)
		helloText.TextSize = 48
		helloText.Font = Enum.Font.GothamBold
		helloText.Parent = splashLayer
		
		local instructionText = Instance.new("TextLabel")
		instructionText.Size = UDim2.new(1, 0, 1, 0)
		instructionText.BackgroundTransparency = 1
		instructionText.Text = "To start your journey press Right Shift. Or press the logo if you're on mobile."
		instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
		instructionText.TextSize = 24
		instructionText.Font = Enum.Font.GothamMedium
		instructionText.TextTransparency = 1
		instructionText.Parent = splashLayer
		
		local mobileLogo = Instance.new("ImageButton")
		mobileLogo.Size = UDim2.new(0, 50, 0, 50)
		mobileLogo.Position = UDim2.new(0, 20, 0, 20)
		mobileLogo.BackgroundTransparency = 1
		mobileLogo.Image = "rbxassetid://10888331510" -- Example generic logo asset
		mobileLogo.ImageTransparency = 1
		mobileLogo.Parent = splashLayer
		
		-- Hide real clickgui if it's open
		local realClickGui
		pcall(function()
			realClickGui = vape.gui.ScaledGui.ClickGui
			if realClickGui.Visible then
				realClickGui.Visible = false
			end
		end)
		
		-- Splash Animations
		TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 0.5}):Play()
		local t1 = TweenService:Create(helloText, TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)})
		t1:Play()
		
		task.delay(2, function()
			TweenService:Create(helloText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			task.wait(0.5)
			TweenService:Create(instructionText, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			TweenService:Create(mobileLogo, TweenInfo.new(0.5), {ImageTransparency = 0}):Play()
		end)
		
		local function startJourney()
			TweenService:Create(splashLayer, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
			TweenService:Create(instructionText, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
			TweenService:Create(mobileLogo, TweenInfo.new(0.5), {ImageTransparency = 1}):Play()
			task.delay(0.5, function()
				splashLayer:Destroy()
				showDeviceSelection()
			end)
		end
		
		-- Wait for input
		local inputConn
		inputConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.RightShift then
				inputConn:Disconnect()
				startJourney()
			end
		end)
		mobileLogo.MouseButton1Click:Connect(function()
			inputConn:Disconnect()
			startJourney()
		end)
		
		-- 2. Device Selection Screen Layer
		function showDeviceSelection()
			local deviceLayer = Instance.new("Frame")
			deviceLayer.Size = UDim2.new(1, 0, 1, 0)
			deviceLayer.BackgroundTransparency = 1
			deviceLayer.Parent = GUI
			
			local heading = Instance.new("TextLabel")
			heading.Size = UDim2.new(1, 0, 0, 50)
			heading.Position = UDim2.new(0, 0, 0.3, 0)
			heading.BackgroundTransparency = 1
			heading.Text = "Select your device:"
			heading.TextColor3 = Color3.fromRGB(255, 255, 255)
			heading.TextSize = 32
			heading.Font = Enum.Font.GothamBold
			heading.TextTransparency = 1
			heading.Parent = deviceLayer
			
			local pcBtn = Instance.new("TextButton")
			pcBtn.Size = UDim2.new(0, 200, 0, 60)
			pcBtn.Position = UDim2.new(0.5, -220, 0.5, 0)
			pcBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			pcBtn.Text = "PC"
			pcBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			pcBtn.Font = Enum.Font.GothamMedium
			pcBtn.TextSize = 24
			pcBtn.BackgroundTransparency = 1
			pcBtn.TextTransparency = 1
			pcBtn.AutoButtonColor = false
			local pcc = Instance.new("UICorner", pcBtn)
			pcBtn.Parent = deviceLayer
			
			local mobBtn = Instance.new("TextButton")
			mobBtn.Size = UDim2.new(0, 200, 0, 60)
			mobBtn.Position = UDim2.new(0.5, 20, 0.5, 0)
			mobBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			mobBtn.Text = "MOBILE"
			mobBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			mobBtn.Font = Enum.Font.GothamMedium
			mobBtn.TextSize = 24
			mobBtn.BackgroundTransparency = 1
			mobBtn.TextTransparency = 1
			mobBtn.AutoButtonColor = false
			local mobc = Instance.new("UICorner", mobBtn)
			mobBtn.Parent = deviceLayer
			
			TweenService:Create(heading, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
			TweenService:Create(pcBtn, TweenInfo.new(0.5), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			TweenService:Create(mobBtn, TweenInfo.new(0.5), {BackgroundTransparency = 0, TextTransparency = 0}):Play()
			
			local function runTour()
				local targets = {
					{Name = "AimAssist", Category = "Combat", Desc = "Aim Assist\nIts pretty much self explaining."},
					{Name = "Killaura", Category = "Blatant", Desc = "Kill Aura\nWhen you enable it. It will attack players around you"},
					{Name = "Reach", Category = "Combat", Desc = "Reach\nMakes you attack players from a longer distance."}
				}
				
				local defaultScale = vape.guiscale and vape.guiscale.Scale or 1
				local camera = workspace.CurrentCamera
				
				for _, target in ipairs(targets) do
					local cat = vape.Categories[target.Category]
					if not cat then continue end
					local catWindow = cat.Object
					
					local scrollFrame = nil
					local modBtn = nil
					
					for _, v in catWindow:GetDescendants() do
						if (v:IsA("TextLabel") or v:IsA("TextButton")) then
							local cleanName = string.gsub(v.Text:lower(), "[^%w]", "")
							if cleanName == target.Name:lower() then
								local current = v
								while current and current.Parent and not current.Parent:IsA("ScrollingFrame") do
									if current.Parent == catWindow then break end
									current = current.Parent
								end
								modBtn = current
								if current and current.Parent and current.Parent:IsA("ScrollingFrame") then
									scrollFrame = current.Parent
								end
								break
							end
						end
					end
					
					if catWindow and modBtn then
						-- 1. Tween Category to Center
						local screenX = (camera.ViewportSize.X / defaultScale)
						local screenY = (camera.ViewportSize.Y / defaultScale)
						local targetPos = UDim2.fromOffset(screenX/2 - catWindow.AbsoluteSize.X/(2 * defaultScale), screenY/2 - catWindow.AbsoluteSize.Y/(2 * defaultScale))
						TweenService:Create(catWindow, TweenInfo.new(0.6, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Position = targetPos}):Play()
						task.wait(0.6)
						
						-- 2. Scroll to Module (if in a scrolling frame)
						if scrollFrame then
							local btnY = modBtn.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y + scrollFrame.CanvasPosition.Y
							local targetCanvasY = btnY - (scrollFrame.AbsoluteSize.Y / 2) + (modBtn.AbsoluteSize.Y / 2)
							targetCanvasY = math.clamp(targetCanvasY, 0, math.max(0, scrollFrame.CanvasSize.Y.Offset - scrollFrame.AbsoluteSize.Y))
							
							TweenService:Create(scrollFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CanvasPosition = Vector2.new(0, targetCanvasY)}):Play()
							task.wait(0.6)
						end
						
						-- 3. Zoom In
						if vape.guiscale then
							TweenService:Create(vape.guiscale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = defaultScale * 1.8}):Play()
						end
						
						-- Refine Center position after zoom (since AbsoluteSize changes)
						local zoomPos = UDim2.fromOffset((camera.ViewportSize.X / (defaultScale * 1.8))/2 - catWindow.AbsoluteSize.X/(2 * defaultScale * 1.8), (camera.ViewportSize.Y / (defaultScale * 1.8))/2 - catWindow.AbsoluteSize.Y/(2 * defaultScale * 1.8))
						TweenService:Create(catWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = zoomPos}):Play()
						task.wait(0.5)
						
						-- 4. Tooltip
						local tooltip = Instance.new("Frame")
						tooltip.Size = UDim2.new(0, 0, 0, 0)
						tooltip.Position = UDim2.new(1, 15, 0.5, -30)
						tooltip.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
						tooltip.BorderSizePixel = 0
						tooltip.ClipsDescendants = true
						Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 8)
						local stroke = Instance.new("UIStroke", tooltip)
						stroke.Color = Color3.fromRGB(60, 60, 60)
						stroke.Thickness = 1.5
						
						local lbl = Instance.new("TextLabel")
						lbl.Size = UDim2.new(1, -16, 1, -16)
						lbl.Position = UDim2.new(0, 8, 0, 8)
						lbl.BackgroundTransparency = 1
						lbl.Text = target.Desc
						lbl.TextColor3 = Color3.new(1, 1, 1)
						lbl.TextWrapped = true
						lbl.Font = Enum.Font.GothamMedium
						lbl.TextSize = 14
						lbl.TextXAlignment = Enum.TextXAlignment.Left
						lbl.Parent = tooltip
						
						tooltip.Parent = modBtn
						
						TweenService:Create(tooltip, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 220, 0, 70)}):Play()
						
						task.wait(3.5)
						
						-- 5. Zoom Out & Cleanup
						TweenService:Create(tooltip, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0)}):Play()
						task.wait(0.3)
						tooltip:Destroy()
						
						if vape.guiscale then
							TweenService:Create(vape.guiscale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = defaultScale}):Play()
						end
						task.wait(0.5)
					end
				end
			end
			
			local function onDeviceSelected(device)
				TweenService:Create(deviceLayer, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				TweenService:Create(heading, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
				TweenService:Create(pcBtn, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
				TweenService:Create(mobBtn, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
				TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
				
				task.delay(0.5, function()
					deviceLayer:Destroy()
					GUI:Destroy()
					GUI = nil
					
					-- 3. Animate Real ClickGui (Premium Animation)
					if realClickGui then
						realClickGui.Position = UDim2.new(0, 0, 0, 0)
						realClickGui.Visible = true
						
						local delayCounter = 0
						for _, cat in pairs(vape.Categories) do
							local window = cat.Object
							if window then
								local originalPos = window.Position
								window.Position = originalPos + UDim2.fromOffset(0, 300)
								
								local tInfo = TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out, 0, false, delayCounter)
								TweenService:Create(window, tInfo, {Position = originalPos}):Play()
								
								delayCounter = delayCounter + 0.06
							end
						end
						
						if vape.guiscale then
							local targetScale = vape.guiscale.Scale
							vape.guiscale.Scale = targetScale * 0.85
							TweenService:Create(vape.guiscale, TweenInfo.new(1.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Scale = targetScale}):Play()
						end
						
						task.spawn(function()
							task.wait(delayCounter + 0.5)
							runTour()
						end)
					end
				end)
			end
			
			pcBtn.MouseButton1Click:Connect(function() onDeviceSelected("PC") end)
			mobBtn.MouseButton1Click:Connect(function() onDeviceSelected("Mobile") end)
		end
	end

	TestModule = vape.Categories.Render:CreateModule({
		Name = 'Test',
		Function = function(callback)
			if callback then
				createUI()
			else
				if GUI then GUI:Destroy() GUI = nil end
				if connection then connection:Disconnect() connection = nil end
			end
		end
	})
end)


run(function()
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
	
end)

run(function()
	local shooting, old = false
	
	local function getCrossbows()
		local crossbows = {}
		for i, v in store.inventory.hotbar do
			if v.item and v.item.itemType:find('crossbow') and i ~= (store.inventory.hotbarSlot + 1) then table.insert(crossbows, i - 1) end
		end
		return crossbows
	end
	
	vape.Categories.Utility:CreateModule({
		Name = 'AutoShoot',
		Function = function(callback)
			if callback then
				old = bedwars.ProjectileController.createLocalProjectile
				bedwars.ProjectileController.createLocalProjectile = function(...)
					local source, data, proj = ...
					if source and (proj == 'arrow' or proj == 'fireball') and not shooting then
						task.spawn(function()
							local bows = getCrossbows()
							if #bows > 0 then
								shooting = true
								task.wait(0.15)
								local selected = store.inventory.hotbarSlot
								for _, v in getCrossbows() do
									if hotbarSwitch(v) then
										task.wait(0.05)
										mouse1click()
										task.wait(0.05)
									end
								end
								hotbarSwitch(selected)
								shooting = false
							end
						end)
					end
					return old(...)
				end
			else
				bedwars.ProjectileController.createLocalProjectile = old
			end
		end,
		Tooltip = 'Automatically crossbow macro\'s'
	})
	
end)

run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, said, dead = {}, {}, {}
	
	local function sendMessage(name, obj, default)
		local tab = Lists[name].ListEnabled
		local custommsg = #tab > 0 and tab[math.random(1, #tab)] or default
		if not custommsg then return end
		if #tab > 1 and custommsg == said[name] then
			repeat 
				task.wait() 
				custommsg = tab[math.random(1, #tab)] 
			until custommsg ~= said[name]
		end
		said[name] = custommsg
	
		custommsg = custommsg and custommsg:gsub('<obj>', obj or '') or ''
		if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(custommsg)
		else
			replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(custommsg, 'All')
		end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
		Name = 'AutoToxic',
		Function = function(callback)
			if callback then
				AutoToxic:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(bedTable)
					if Toggles.BedDestroyed.Enabled and bedTable.brokenBedTeam.id == lplr:GetAttribute('Team') then
						sendMessage('BedDestroyed', (bedTable.player.DisplayName or bedTable.player.Name), 'how dare you >:( | <obj>')
					elseif Toggles.Bed.Enabled and bedTable.player.UserId == lplr.UserId then
						local team = bedwars.QueueMeta[store.queueType].teams[tonumber(bedTable.brokenBedTeam.id)]
						sendMessage('Bed', team and team.displayName:lower() or 'white', 'nice bed lul | <obj>')
					end
				end))
				AutoToxic:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill then
						local killer = playersService:GetPlayerFromCharacter(deathTable.fromEntity)
						local killed = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
						if not killed or not killer then return end
						if killed == lplr then
							if (not dead) and killer ~= lplr and Toggles.Death.Enabled then
								dead = true
								sendMessage('Death', (killer.DisplayName or killer.Name), 'my gaming chair subscription expired :( | <obj>')
							end
						elseif killer == lplr and Toggles.Kill.Enabled then
							sendMessage('Kill', (killed.DisplayName or killed.Name), 'vxp on top | <obj>')
						end
					end
				end))
				AutoToxic:Clean(vapeEvents.MatchEndEvent.Event:Connect(function(winstuff)
					if GG.Enabled then
						if textChatService.ChatVersion == Enum.ChatVersion.TextChatService then
							textChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync('gg')
						else
							replicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer('gg', 'All')
						end
					end
					
					local myTeam = bedwars.Store:getState().Game.myTeam
					if myTeam and myTeam.id == winstuff.winningTeamId or lplr.Neutral then
						if Toggles.Win.Enabled then 
							sendMessage('Win', nil, 'yall garbage') 
						end
					end
				end))
			end
		end,
		Tooltip = 'Says a message after a certain action'
	})
	GG = AutoToxic:CreateToggle({
		Name = 'AutoGG',
		Default = true
	})
	for _, v in {'Kill', 'Death', 'Bed', 'BedDestroyed', 'Win'} do
		Toggles[v] = AutoToxic:CreateToggle({
			Name = v..' ',
			Function = function(callback)
				if Lists[v] then
					Lists[v].Object.Visible = callback
				end
			end
		})
		Lists[v] = AutoToxic:CreateTextList({
			Name = v,
			Darker = true,
			Visible = false
		})
	end
end)

run(function()
	local AutoVoidDrop
	local OwlCheck
	
	AutoVoidDrop = vape.Categories.Utility:CreateModule({
		Name = 'AutoVoidDrop',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
				if not AutoVoidDrop.Enabled then return end
	
				local lowestpoint = math.huge
				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end
	
				repeat
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
							if not OwlCheck.Enabled or not root:FindFirstChild('OwlLiftForce') then
								for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
									item = getItem(item)
									if item then
										item = bedwars.Client:Get(remotes.DropItem):CallServer({
											item = item.tool,
											amount = item.amount
										})
	
										if item then
											item:SetAttribute('ClientDropTime', tick() + 100)
										end
									end
								end
							end
						end
					end
	
					task.wait(0.1)
				until not AutoVoidDrop.Enabled
			end
		end,
		Tooltip = 'Drops resources when you fall into the void'
	})
	OwlCheck = AutoVoidDrop:CreateToggle({
		Name = 'Owl check',
		Default = true,
		Tooltip = 'Refuses to drop items if being picked up by an owl'
	})
end)

run(function()
    local old

    vape.Categories.Utility:CreateModule({
        Tooltip = "Needs krystal equipped to work.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                bedwars.GlacialSkaterController:updateMomentum(9e9)
                old = bedwars.GlacialSkaterController.updateMomentum
                bedwars.GlacialSkaterController.updateMomentum = function(self)
                    self.momentum = 9e9
                    self.lastMomentumReport = 9e9
                    bedwars.Client:Get('MomentumUpdate'):SendToServer({
                        momentumValue = 9e9
                    })
                end
                bedwars.GlacialSkaterController:updateMomentum()
            else
                bedwars.GlacialSkaterController.updateMomentum = old
            end
        end
    })
end) 


run(function()
	local MissileTP
	
	MissileTP = vape.Categories.Utility:CreateModule({
		Name = 'MissileTP',
		Function = function(callback)
			if callback then
				MissileTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})
	
				if getItem('guided_missile') and plr then
					local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
					if projectile then
						local projectilemodel = projectile.model
						if not projectilemodel.PrimaryPart then
							projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
						end
	
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Name = 'AntiGravity'
						bodyforce.Parent = projectilemodel.PrimaryPart
	
						repeat
							projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
							task.wait(0.1)
						until not projectile.model or not projectile.model.Parent
					else
						notif('MissileTP', 'Missile on cooldown.', 3)
					end
				end
			end
		end,
		Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse.'
	})
end)

run(function()
	local OwlFire = vape.Categories.Utility:CreateModule({
		Name = 'OwlFire',
		Function = function(callback)
			if callback then
				local remote = bedwars.Client:Get('OwlFireProjectile')
				local t = {
					fromPosition = entitylib.character.RootPart.Position
				}
				t.direction = Vector3.new(0, 9e9, 0)
				t.offset = nil
				t.ProjectileRefId = game:GetService('HttpService'):GenerateGUID(false)
				t.initialVelocity = Vector3.new(0, 9e9, 0)
				remote:SendToServer(t)
				vape:CreateNotification('OwlFire', 'Fired projectile', 3)
			end
		end,
		Tooltip = 'Fires a projectile at 9e9 velocity'
	})
	
end)

run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local adjacent, lastpos, label = {}, Vector3.zero
	
	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end
	
	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end
	
	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end
	
	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end
	
	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local wool, amount = getWool()
			if wool then
				return wool, amount
			else
				for _, item in store.inventory.inventory.items do
					if bedwars.ItemMeta[item.itemType].block then
						return item.itemType, item.amount
					end
				end
			end
		end
	
		return nil, 0
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end
	
			if callback then
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()
	
						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end
	
						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end
	
						if wool then
							local root = entitylib.character.RootPart
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
	
							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end
	
								local block, blockpos = getPlacedBlock(currentpos)
								if not block then
									blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(currentpos)
									if blockpos then
										task.spawn(bedwars.placeBlock, blockpos, wool, false)
									end
								end
								lastpos = currentpos
							end
						end
					end
	
					task.wait(0.03)
				until not Scaffold.Enabled
			else
				Label = nil
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

run(function()
	local StaffDetector
	local Mode
	local Clans
	local Party
	local Profile
	local Users
	local blacklistedclans = {'gg', 'gg2', 'DV', 'DV2'}
	local blacklisteduserids = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275}
	local joined = {}
	
	local function getRole(plr, id)
		local suc, res = pcall(function()
			return plr:GetRankInGroup(id)
		end)
		if not suc then
			notif('StaffDetector', res, 30, 'alert')
		end
		return suc and res or 0
	end
	
	local function staffFunction(plr, checktype)
		if not vape.Loaded then
			repeat task.wait() until vape.Loaded
		end
	
		notif('StaffDetector', 'Staff Detected ('..checktype..'): '..plr.Name..' ('..plr.UserId..')', 60, 'alert')
		whitelist.customtags[plr.Name] = {{text = 'GAME STAFF', color = Color3.new(1, 0, 0)}}
	
		if Party.Enabled and not checktype:find('clan') then
			bedwars.PartyController:leaveParty()
		end
	
		if Mode.Value == 'Uninject' then
			task.spawn(function()
				vape:Uninject()
			end)
			game:GetService('StarterGui'):SetCore('SendNotification', {
				Title = 'StaffDetector',
				Text = 'Staff Detected ('..checktype..')\n'..plr.Name..' ('..plr.UserId..')',
				Duration = 60,
			})
		elseif Mode.Value == 'Requeue' then
			bedwars.QueueController:joinQueue(store.queueType)
		elseif Mode.Value == 'Profile' then
			vape.Save = function() end
			if vape.Profile ~= Profile.Value then
				vape:Load(true, Profile.Value)
			end
		elseif Mode.Value == 'AutoConfig' then
			local safe = {'AutoClicker', 'Reach', 'Sprint', 'HitFix', 'StaffDetector'}
			vape.Save = function() end
			for i, v in vape.Modules do
				if not (table.find(safe, i) or v.Category == 'Render') then
					if v.Enabled then
						v:Toggle()
					end
					v:SetBind('')
				end
			end
		end
	end
	
	local function checkFriends(list)
		for _, v in list do
			if joined[v] then
				return joined[v]
			end
		end
		return nil
	end
	
	local function checkJoin(plr, connection)
		if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') and not bedwars.Store:getState().Game.customMatch then
			connection:Disconnect()
			local tab, pages = {}, playersService:GetFriendsAsync(plr.UserId)
			for _ = 1, 4 do
				for _, v in pages:GetCurrentPage() do
					table.insert(tab, v.Id)
				end
				if pages.IsFinished then break end
				pages:AdvanceToNextPageAsync()
			end
	
			local friend = checkFriends(tab)
			if not friend then
				staffFunction(plr, 'impossible_join')
				return true
			else
				notif('StaffDetector', string.format('Spectator %s joined from %s', plr.Name, friend), 20, 'warning')
			end
		end
	end
	
	local function playerAdded(plr)
		joined[plr.UserId] = plr.Name
		if plr == lplr then return end
	
		if table.find(blacklisteduserids, plr.UserId) or table.find(Users.ListEnabled, tostring(plr.UserId)) then
			staffFunction(plr, 'blacklisted_user')
		elseif getRole(plr, 5774246) >= 100 then
			staffFunction(plr, 'staff_role')
		else
			local connection
			connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
				checkJoin(plr, connection)
			end)
			StaffDetector:Clean(connection)
			if checkJoin(plr, connection) then
				return
			end
	
			if not plr:GetAttribute('ClanTag') then
				plr:GetAttributeChangedSignal('ClanTag'):Wait()
			end
	
			if table.find(blacklistedclans, plr:GetAttribute('ClanTag')) and vape.Loaded and Clans.Enabled then
				connection:Disconnect()
				staffFunction(plr, 'blacklisted_clan_'..plr:GetAttribute('ClanTag'):lower())
			end
		end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
		Name = 'StaffDetector',
		Function = function(callback)
			if callback then
				StaffDetector:Clean(playersService.PlayerAdded:Connect(playerAdded))
				for _, v in playersService:GetPlayers() do
					task.spawn(playerAdded, v)
				end
			else
				table.clear(joined)
			end
		end,
		Tooltip = 'Detects people with a staff rank ingame'
	})
	Mode = StaffDetector:CreateDropdown({
		Name = 'Mode',
		List = {'Uninject', 'Profile', 'Requeue', 'AutoConfig', 'Notify'},
		Function = function(val)
			if Profile.Object then
				Profile.Object.Visible = val == 'Profile'
			end
		end
	})
	Clans = StaffDetector:CreateToggle({
		Name = 'Blacklist clans',
		Default = true
	})
	Party = StaffDetector:CreateToggle({
		Name = 'Leave party'
	})
	Profile = StaffDetector:CreateTextBox({
		Name = 'Profile',
		Default = 'default',
		Darker = true,
		Visible = false
	})
	Users = StaffDetector:CreateTextList({
		Name = 'Users',
		Placeholder = 'player (userid)'
	})
	
	task.spawn(function()
		repeat task.wait(1) until vape.Loaded or vape.Loaded == nil
		if vape.Loaded and not StaffDetector.Enabled then
			StaffDetector:Toggle()
		end
	end)
end)

run(function()
	local BedPlates
	local Background
	local Color = {}
	local Reference = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui
	
	local function scanSide(self, start, tab)
		for _, side in sides do
			for i = 1, 15 do
				local block = getPlacedBlock(start + (side * i))
				if not block or block == self then break end
				if not block:GetAttribute('NoBreak') and not table.find(tab, block.Name) then
					table.insert(tab, block.Name)
				end
			end
		end
	end
	
	local function refreshAdornee(v)
		for _, obj in v.Frame:GetChildren() do
			if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
				obj:Destroy()
			end
		end
	
		local start = v.Adornee.Position
		local alreadygot = {}
		scanSide(v.Adornee, start, alreadygot)
		scanSide(v.Adornee, start + Vector3.new(0, 0, 3), alreadygot)
		table.sort(alreadygot, function(a, b)
			return (bedwars.ItemMeta[a].block and bedwars.ItemMeta[a].block.health or 0) > (bedwars.ItemMeta[b].block and bedwars.ItemMeta[b].block.health or 0)
		end)
		v.Enabled = #alreadygot > 0
	
		for _, block in alreadygot do
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = block}, true)
			blockimage.Parent = v.Frame
		end
	end
	
	local function Added(v)
		local billboard = Instance.new('BillboardGui')
		billboard.Parent = Folder
		billboard.Name = 'bed'
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = v
		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled
		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		frame.Parent = billboard
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, 4)
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
			billboard.Size = UDim2.fromOffset(math.max(layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		layout.Parent = frame
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = frame
		Reference[v] = billboard
		refreshAdornee(billboard)
	end
	
	local function refreshNear(data)
		data = data.blockRef.blockPosition * 3
		for i, v in Reference do
			if (data - i.Position).Magnitude <= 30 then
				refreshAdornee(v)
			end
		end
	end
	
	BedPlates = vape.Categories.Minigames:CreateModule({
		Name = 'BedPlates',
		Function = function(callback)
			if callback then
				for _, v in collectionService:GetTagged('bed') do 
					task.spawn(Added, v) 
				end
				BedPlates:Clean(vapeEvents.PlaceBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(vapeEvents.BreakBlockEvent.Event:Connect(refreshNear))
				BedPlates:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(Added))
				BedPlates:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(v)
					if Reference[v] then
						Reference[v]:Destroy()
						Reference[v]:ClearAllChildren()
						Reference[v] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Displays blocks over the bed'
	})
	Background = BedPlates:CreateToggle({
		Name = 'Background',
		Function = function(callback)
			if Color.Object then 
				Color.Object.Visible = callback 
			end
			for _, v in Reference do
				v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
				v.Blur.Visible = callback
			end
		end,
		Default = true
	})
	Color = BedPlates:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(hue, sat, val, opacity)
			for _, v in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
				v.Frame.BackgroundTransparency = 1 - opacity
			end
		end,
		Darker = true
	})
end)

run(function()
	local Breaker
	local Range
	local BreakSpeed
	local UpdateRate
	local Custom
	local Bed
	local LuckyBlock
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local InstantBreak
	local LimitItem
	local AutoToolToggle
	local customlist, parts = {}, {}
	
	local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
		if block:GetAttribute('NoHealthbar') then return end
		if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
			self.healthbarMaid:DoCleaning()
			self.healthbarBlockRef = blockRef
			local create = bedwars.Roact.createElement
			local percent = math.clamp(health / maxHealth, 0, 1)
			local cleanCheck = true
			local part = Instance.new('Part')
			part.Size = Vector3.one
			part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
			part.Transparency = 1
			part.Anchored = true
			part.CanCollide = false
			part.Parent = workspace
			self.healthbarPart = part
			bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)
	
			local mounted = bedwars.Roact.mount(create('BillboardGui', {
				Size = UDim2.fromOffset(249, 102),
				StudsOffset = Vector3.new(0, 2.5, 0),
				Adornee = part,
				MaxDistance = 40,
				AlwaysOnTop = true
			}, {
				create('Frame', {
					Size = UDim2.fromOffset(160, 50),
					Position = UDim2.fromOffset(44, 32),
					BackgroundColor3 = Color3.new(),
					BackgroundTransparency = 0.5
				}, {
					create('UICorner', {CornerRadius = UDim.new(0, 5)}),
					create('ImageLabel', {
						Size = UDim2.new(1, 89, 1, 52),
						Position = UDim2.fromOffset(-48, -31),
						BackgroundTransparency = 1,
						Image = getcustomasset('newvape/assets/new/blur.png'),
						ScaleType = Enum.ScaleType.Slice,
						SliceCenter = Rect.new(52, 31, 261, 502)
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(13, 12),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = Color3.new(),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('TextLabel', {
						Size = UDim2.fromOffset(145, 14),
						Position = UDim2.fromOffset(12, 11),
						BackgroundTransparency = 1,
						Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextColor3 = color.Dark(uipallet.Text, 0.16),
						TextScaled = true,
						Font = Enum.Font.Arial
					}),
					create('Frame', {
						Size = UDim2.fromOffset(138, 4),
						Position = UDim2.fromOffset(12, 32),
						BackgroundColor3 = uipallet.Main
					}, {
						create('UICorner', {CornerRadius = UDim.new(1, 0)}),
						create('Frame', {
							[bedwars.Roact.Ref] = self.healthbarProgressRef,
							Size = UDim2.fromScale(percent, 1),
							BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
						}, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
					})
				})
			}), part)
	
			self.healthbarMaid:GiveTask(function()
				cleanCheck = false
				self.healthbarBlockRef = nil
				bedwars.Roact.unmount(mounted)
				if self.healthbarPart then
					self.healthbarPart:Destroy()
				end
				self.healthbarPart = nil
			end)
	
			bedwars.RuntimeLib.Promise.delay(5):andThen(function()
				if cleanCheck then
					self.healthbarMaid:DoCleaning()
				end
			end)
		end
	
		local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
		tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
			Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
		}):Play()
	end
	
	local hit = 0
	
	local function attemptBreak(tab, localPosition)
		if not tab then return end
		for _, v in tab do
			if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
				if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
				if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
				if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end
	
				if AutoToolToggle.Enabled then
					local meta = bedwars.ItemMeta[v.Name]
					local breakType = meta and meta.block and meta.block.breakType
					if breakType then
						local tool = store.tools[breakType]
						if tool then
							for i, item in store.inventory.hotbar do
								if item.item and item.item.itemType == tool.itemType then
									hotbarSwitch(i - 1)
									break
								end
							end
						end
					end
				end
	
				hit += 1
				local target, path, endpos = bedwars.breakBlock(v, Effect.Enabled, Animation.Enabled, CustomHealth.Enabled and customHealthbar or nil, InstantBreak.Enabled)
				if path then
					local currentnode = target
					for _, part in parts do
						part.Position = currentnode or Vector3.zero
						if currentnode then
							part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
						end
						currentnode = path[currentnode]
					end
				end
	
				task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)
	
				return true
			end
		end
	
		return false
	end
	
	Breaker = vape.Categories.Minigames:CreateModule({
		Name = 'Breaker',
		Function = function(callback)
			if callback then
				for _ = 1, 30 do
					local part = Instance.new('Part')
					part.Anchored = true
					part.CanQuery = false
					part.CanCollide = false
					part.Transparency = 1
					part.Parent = gameCamera
					local highlight = Instance.new('BoxHandleAdornment')
					highlight.Size = Vector3.one
					highlight.AlwaysOnTop = true
					highlight.ZIndex = 1
					highlight.Transparency = 0.5
					highlight.Adornee = part
					highlight.Parent = part
					table.insert(parts, part)
				end
	
				local beds = collection('bed', Breaker)
				local luckyblock = collection('LuckyBlock', Breaker)
				local ironores = collection('iron-ore', Breaker)
				customlist = collection('block', Breaker, function(tab, obj)
					if table.find(Custom.ListEnabled, obj.Name) then
						table.insert(tab, obj)
					end
				end)
	
				repeat
					task.wait(1 / UpdateRate.Value)
					if not Breaker.Enabled then break end
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
	
						if attemptBreak(Bed.Enabled and beds, localPosition) then continue end
						if attemptBreak(customlist, localPosition) then continue end
						if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
						if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end
	
						for _, v in parts do
							v.Position = Vector3.zero
						end
					end
				until not Breaker.Enabled
			else
				for _, v in parts do
					v:ClearAllChildren()
					v:Destroy()
				end
				table.clear(parts)
			end
		end,
		Tooltip = 'Break blocks around you automatically'
	})
	Range = Breaker:CreateSlider({
		Name = 'Break range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	BreakSpeed = Breaker:CreateSlider({
		Name = 'Break speed',
		Min = 0,
		Max = 0.3,
		Default = 0.25,
		Decimal = 100,
		Suffix = 'seconds'
	})
	UpdateRate = Breaker:CreateSlider({
		Name = 'Update rate',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = 'hz'
	})
	Custom = Breaker:CreateTextList({
		Name = 'Custom',
		Function = function()
			if not customlist then return end
			table.clear(customlist)
			for _, obj in store.blocks do
				if table.find(Custom.ListEnabled, obj.Name) then
					table.insert(customlist, obj)
				end
			end
		end
	})
	Bed = Breaker:CreateToggle({
		Name = 'Break Bed',
		Default = true
	})
	LuckyBlock = Breaker:CreateToggle({
		Name = 'Break Lucky Block',
		Default = true
	})
	IronOre = Breaker:CreateToggle({
		Name = 'Break Iron Ore',
		Default = true
	})
	Effect = Breaker:CreateToggle({
		Name = 'Show Healthbar & Effects',
		Function = function(callback)
			if CustomHealth.Object then
				CustomHealth.Object.Visible = callback
			end
		end,
		Default = true
	})
	CustomHealth = Breaker:CreateToggle({
		Name = 'Custom Healthbar',
		Default = true,
		Darker = true
	})
	Animation = Breaker:CreateToggle({Name = 'Animation'})
	SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
	InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
	LimitItem = Breaker:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
	AutoToolToggle = Breaker:CreateToggle({
		Name = 'Auto Tool',
		Tooltip = 'Automatically selects the correct tool'
	})
end)

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


run(function()
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
	
end)

run(function()
	local Cape, Mode, Source, Texture
	local part, motor, capesurface
	local currentImage
	
	local function getRangikuTexture()
		local path = "newvape/cape/rangiku.png"
		if isfile(path) then
			return assetfunction(path)
		end
		return 'rbxassetid://14637958134'
	end
	
	local function resolveTexture()
		local mode = Mode.Value
		if mode == 'Rangiku' then
			return getRangikuTexture()
		elseif mode == 'Vape' then
			return 'rbxassetid://14637958134'
		end
		local input = Texture.Value
		if input == '' or input:find('rbxasset') then
			return input == '' and 'rbxassetid://14637958134' or input
		end
		local src = Source.Value
		if src == 'Local File' then
			return isfile(input) and assetfunction(input) or 'rbxassetid://14637958134'
		elseif src == 'GitHub URL' then
			local suc, data = pcall(game.HttpGet, game, input, true)
			if suc and data then
				local ext = input:match('%.(%w+)$') or 'png'
				local path = 'vape/cache/cape.' .. ext
				writefile(path, data)
				return isfile(path) and assetfunction(path) or 'rbxassetid://14637958134'
			end
			return 'rbxassetid://14637958134'
		end
		return assetfunction(input)
	end
	
	local function createMotor(char)
		if motor then
			motor:Destroy()
		end
		part.Parent = gameCamera
		motor = Instance.new('Motor6D')
		motor.MaxVelocity = 0.08
		motor.Part0 = part
		motor.Part1 = char.Character:FindFirstChild('UpperTorso') or char.RootPart
		motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
		motor.C1 = CFrame.new(0, motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
		motor.Parent = part
	end
	
	local function refreshTexture()
		if capesurface and capesurface:FindFirstChildOfClass("ImageLabel") then
			capesurface:FindFirstChildOfClass("ImageLabel").Image = resolveTexture()
		end
	end
	
	Cape = vape.Legit:CreateModule({
		Name = 'Cape',
		Function = function(callback)
			if callback then
				part = Instance.new('Part')
				part.Size = Vector3.new(2, 4, 0.1)
				part.CanCollide = false
				part.CanQuery = false
				part.Massless = true
				part.Transparency = 0
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.new()
				part.CastShadow = false
				part.Parent = gameCamera
	
				capesurface = Instance.new('SurfaceGui')
				capesurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				capesurface.Adornee = part
				capesurface.Face = Enum.NormalId.Front
				capesurface.Parent = part
	
				local decal = Instance.new('ImageLabel')
				decal.Image = resolveTexture()
				decal.Size = UDim2.fromScale(1, 1)
				decal.BackgroundTransparency = 1
				decal.Parent = capesurface
				currentImage = decal
	
				Cape:Clean(part)
				Cape:Clean(entitylib.Events.LocalAdded:Connect(createMotor))
				if entitylib.isAlive then
					createMotor(entitylib.character)
				end
	
				repeat
					if motor and entitylib.isAlive then
						local velo = math.min(entitylib.character.RootPart.Velocity.Magnitude, 90)
						motor.DesiredAngle = math.rad(6) + math.rad(velo) + (velo > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
					end
					capesurface.Enabled = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6
					part.Transparency = (gameCamera.CFrame.Position - gameCamera.Focus.Position).Magnitude > 0.6 and 0 or 1
					task.wait()
				until not Cape.Enabled
			else
				part = nil
				motor = nil
				currentImage = nil
			end
		end,
		Tooltip = 'Add\'s a cape to your character'
	})
	
	Mode = Cape:CreateDropdown({
		Name = 'Mode',
		List = {'Rangiku', 'Vape', 'Custom'},
		Default = 1,
		Function = function()
			if Cape.Enabled then
				refreshTexture()
			end
		end
	})
	Source = Cape:CreateDropdown({
		Name = 'Source',
		List = {'rbxassetid', 'Local File', 'GitHub URL'},
		Default = 1
	})
	Texture = Cape:CreateTextBox({
		Name = 'Texture',
		Function = function()
			if Cape.Enabled then
				refreshTexture()
			end
		end
	})
	
end)

run(function()
	local DarkMode
	local darkConn = {}
	local saved = {}
	
	local darkBg = Color3.fromHex('#141413')
	local dimText = Color3.fromRGB(200, 200, 200)
	
	local function isMidtone(r, g, b)
		local avg = (r + g + b) / 3
		return avg > 15 and avg < 200
	end
	
	local function darken(col)
		local r, g, b = col.R * 255, col.G * 255, col.B * 255
		local avg = (r + g + b) / 3
		local factor = avg / 255
		local reduced = math.max(0.35, factor * 0.6)
		return Color3.new(col.R * reduced, col.G * reduced, col.B * reduced)
	end
	
	local function applyTo(inst)
		for _, v in pairs(inst:GetDescendants()) do
			if v:IsA("Frame") and not v:IsA("TextBox") and v.BackgroundTransparency < 0.9 then
				local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
				if isMidtone(r, g, b) then
					if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
					v.BackgroundColor3 = darkBg
					v.BackgroundTransparency = 0
				end
			end
	
			if (v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text ~= "" then
				local r, g, b = v.TextColor3.R * 255, v.TextColor3.G * 255, v.TextColor3.B * 255
				if isMidtone(r, g, b) or (r + g + b) / 3 > 200 then
					if not saved[v] then saved[v] = {tc = v.TextColor3} end
					v.TextColor3 = dimText
				end
			end
	
			if v:IsA("ImageLabel") then
				if v.BackgroundTransparency < 0.9 then
					local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
					if isMidtone(r, g, b) then
						if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
						v.BackgroundColor3 = darkBg
						v.BackgroundTransparency = 0
					end
				end
				local ir, ig, ib = v.ImageColor3.R * 255, v.ImageColor3.G * 255, v.ImageColor3.B * 255
				local iavg = (ir + ig + ib) / 3
				if iavg > 10 and iavg < 230 then
					if not saved[v] then saved[v] = {ic = v.ImageColor3} end
					if iavg < 50 then
						v.ImageColor3 = Color3.fromRGB(60, 60, 60)
					else
						v.ImageColor3 = darken(v.ImageColor3)
					end
				end
			end
	
			if v:IsA("ScrollingFrame") and v.BackgroundTransparency < 0.9 then
				local r, g, b = v.BackgroundColor3.R * 255, v.BackgroundColor3.G * 255, v.BackgroundColor3.B * 255
				if isMidtone(r, g, b) then
					if not saved[v] then saved[v] = {bg = v.BackgroundColor3, tr = v.BackgroundTransparency} end
					v.BackgroundColor3 = darkBg
					v.BackgroundTransparency = 0
				end
			end
		end
	end
	
	local function restore()
		for v, cols in pairs(saved) do
			if v and v.Parent then
				if cols.bg then pcall(function() v.BackgroundColor3 = cols.bg end) end
				if cols.tr then pcall(function() v.BackgroundTransparency = cols.tr end) end
				if cols.tc then pcall(function() v.TextColor3 = cols.tc end) end
				if cols.ic then pcall(function() v.ImageColor3 = cols.ic end) end
			end
		end
		table.clear(saved)
	end
	
	DarkMode = vape.Legit:CreateModule({
		Name = 'Dark Mode',
		Function = function(callback)
			if callback then
				for _, gui in pairs(lplr.PlayerGui:GetChildren()) do
					if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then applyTo(gui) end
				end
				darkConn[#darkConn + 1] = lplr.PlayerGui.ChildAdded:Connect(function(gui)
					if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then
						task.wait(0.2)
						applyTo(gui)
					end
				end)
				task.spawn(function()
					while DarkMode and DarkMode.Enabled do
						task.wait(1.5)
						for _, gui in pairs(lplr.PlayerGui:GetChildren()) do
							if gui:IsA("ScreenGui") and gui.Name ~= "SettingsAppGui" then applyTo(gui) end
						end
					end
				end)
			else
				for _, c in darkConn do
					pcall(function() c:Disconnect() end)
				end
				table.clear(darkConn)
				restore()
			end
		end,
		Tooltip = 'Changes BedWars HUD to dark mode (#141413)'
	})
	
end)

run(function()
	local ForceBacon
	
	local function applyBacon(char)
		local bc = char:FindFirstChild("Body Colors")
		if bc then
			bc.HeadColor = BrickColor.new("Bright yellowish green")
			bc.TorsoColor = BrickColor.new("Bright blue")
			bc.LeftArmColor = BrickColor.new("Bright yellowish green")
			bc.RightArmColor = BrickColor.new("Bright yellowish green")
			bc.LeftLegColor = BrickColor.new("Bright blue")
			bc.RightLegColor = BrickColor.new("Bright blue")
		end
		local clothing = char:FindFirstChild("3DClothing")
		if clothing then
			clothing:ClearAllChildren()
		end
		for _, child in pairs(char:GetChildren()) do
			if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then
				child:Destroy()
			end
		end
	end
	
	ForceBacon = vape.Legit:CreateModule({
		Name = 'Force Bacon',
		Function = function(callback)
			if callback then
				if entitylib.isAlive then
					applyBacon(entitylib.character.Character)
				end
				ForceBacon:Clean(entitylib.Events.LocalAdded:Connect(function(char)
					applyBacon(char)
				end))
			end
		end,
		Tooltip = 'Forces your kit model to default Bacon appearance'
	})
	
end)

run(function()
	local TexturePack
	local Mode
	local currentConnection
	local loadedPacks = {}
	
	local packAssets = {
		Acidic = 'rbxassetid://14245759641',
		Devourer = 'rbxassetid://14258977192',
		Enlightened = 'rbxassetid://14261862180',
		FatCat = 'rbxassetid://100570768622198',
		Fury = 'rbxassetid://14331255019',
		Makima = 'rbxassetid://14335043180',
		['Marin-Kitsawaba'] = 'rbxassetid://14405573385',
		Moon4Real = 'rbxassetid://14271708146',
		Nebula = 'rbxassetid://14654171957',
		Onyx = 'rbxassetid://14334779267',
		Prime = 'rbxassetid://14479023830',
		Simply = 'rbxassetid://117028342668949',
		Vile = 'rbxassetid://14247192725',
		VioletsDreams = 'rbxassetid://14248304333',
		Wichtiger = 'rbxassetid://14320382383'
	}
	
	local function applyTexturePack(packName)
		if currentConnection then
			currentConnection:Disconnect()
			currentConnection = nil
		end
	
		local assetId = packAssets[packName]
		if not assetId then return end
	
		task.spawn(function()
			local import = loadedPacks[packName]
			if not import then
				local success, objs = pcall(function()
					return game:GetObjects(assetId)
				end)
				if success and objs and objs[1] then
					import = objs[1]
					import.Parent = replicatedStorage
					for _, part in pairs(import:GetDescendants()) do
						if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
							pcall(function() part.CanCollide = false; part.CanQuery = false end)
						end
					end
					loadedPacks[packName] = import
				end
			end
	
			if not import then return end
	
			local viewmodel = gameCamera:WaitForChild("Viewmodel", 5)
			if not viewmodel then return end
	
			local items = import:GetChildren()
	
			local function handleTool(tool)
				if not tool or not TexturePack.Enabled then return end
	
				local targetModel = nil
				local offset = CFrame.Angles(math.rad(0), math.rad(-100), math.rad(-90))
	
				local toolLower = tool.Name:lower()
				for _, v in pairs(items) do
					if v.Name:lower() == toolLower then
						targetModel = v
						if v.Name:find("axe") then
							offset = CFrame.new(0, 0.45, 0) * CFrame.Angles(math.rad(0), math.rad(-10), math.rad(-95))
						end
						break
					end
				end
	
				if not targetModel then
					local nameMap = {
						wood_sword = "Wood_Sword",
						stone_sword = "Stone_Sword",
						iron_sword = "Iron_Sword",
						diamond_sword = "Diamond_Sword",
						emerald_sword = "Emerald_Sword"
					}
					local mapped = nameMap[toolLower]
					if mapped then
						targetModel = import:FindFirstChild(mapped)
					end
				end
	
				if not targetModel then
					for _, v in pairs(items) do
						if toolLower:find("sword") and v.Name:lower():find("sword") then
							targetModel = v
							break
						end
					end
				end
	
				if targetModel then
					for _, existing in pairs(tool:GetChildren()) do
						if existing:IsA("WeldConstraint") or existing:IsA("Model") then
							existing:Destroy()
						end
					end
	
					for _, part in pairs(tool:GetDescendants()) do
						if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
							part.Transparency = 1
							pcall(function() part.CanCollide = false; part.CanQuery = false end)
						end
					end
	
					local handle = tool:WaitForChild("Handle", 2)
					if handle then
						local clone = targetModel:Clone()
						for _, part in pairs(clone:GetDescendants()) do
							if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
								pcall(function() part.CanCollide = false; part.CanQuery = false end)
							end
						end
						clone.CFrame = handle.CFrame * offset * CFrame.Angles(0, math.rad(-50), 0)
						clone.Size *= Vector3.new(1.375, 1.375, 1.375)
						clone.Parent = tool
	
						local weld = Instance.new("WeldConstraint", clone)
						weld.Part0 = clone
						weld.Part1 = handle
					end
				end
			end
	
			local function onToolAdded(child)
				if child:IsA("Accessory") or child:IsA("Tool") then
					handleTool(child)
					child:GetPropertyChangedSignal("Name"):Connect(function()
						handleTool(child)
					end)
				end
			end
	
			currentConnection = viewmodel.ChildAdded:Connect(onToolAdded)
	
			viewmodel.ChildRemoved:Connect(function(child)
				for _, v in pairs(child:GetChildren()) do
					if v:IsA("WeldConstraint") or v:IsA("MeshPart") or v:IsA("Part") then
						v:Destroy()
					end
				end
			end)
	
			for _, child in pairs(viewmodel:GetChildren()) do
				onToolAdded(child)
			end
	
			task.spawn(function()
				while TexturePack.Enabled and viewmodel and viewmodel.Parent do
					task.wait(0.5)
					for _, child in pairs(viewmodel:GetChildren()) do
						if child:IsA("Accessory") or child:IsA("Tool") then
							handleTool(child)
						end
					end
				end
			end)
		end)
	end
	
	TexturePack = vape.Legit:CreateModule({
		Name = 'Texture Pack',
		Function = function(callback)
			if callback then
				applyTexturePack(Mode.Value)
			else
				if currentConnection then
					currentConnection:Disconnect()
					currentConnection = nil
				end
			end
		end,
		Tooltip = 'Custom BedWars Texture Packs'
	})
	
	Mode = TexturePack:CreateDropdown({
		Name = 'Mode',
		List = {
			'Acidic', 'Devourer', 'Enlightened', 'FatCat', 'Fury',
			'Makima', 'Marin-Kitsawaba', 'Moon4Real', 'Nebula', 'Onyx',
			'Prime', 'Simply', 'Vile', 'VioletsDreams', 'Wichtiger'
		},
		Function = function(val)
			if TexturePack.Enabled then
				applyTexturePack(val)
			end
		end
	})
	
end)

-- Fetch public modules dynamically
task.spawn(function()
	local publicMods = {
		"World/Anti-AFK.lua",
		"World/AutoSuffocate.lua",
		"World/AutoTool.lua",
		"World/BedProtector.lua",
		"World/ChestSteal.lua",
		"World/Schematica.lua",
		"Render/BedESP.lua",
		"Render/Health.lua",
		"Render/KitESP.lua",
		"Render/NameTags.lua",
		"Render/StorageESP.lua",
		"Utility/AutoBalloon.lua",
		"Utility/AutoKit.lua",
		"Utility/AutoPearl.lua",
		"Utility/AutoPlay.lua",
		"Utility/PickupRange.lua",
		"Utility/RavenTP.lua",
		"Utility/TrapDisabler.lua",
		"Utility/ShopTierBypass.lua",
		"Inventory/ArmorSwitch.lua",
		"Inventory/AutoBank.lua",
		"Inventory/AutoBuy.lua",
		"Inventory/AutoConsume.lua",
		"Inventory/AutoHotbar.lua",
		"Inventory/FastConsume.lua",
		"Inventory/FastDrop.lua",
		"Legit/BedBreakEffect.lua",
		"Legit/CleanKit.lua",
		"Legit/Crosshair.lua",
		"Legit/DamageIndicator.lua",
		"Legit/FOV.lua",
		"Legit/FPSBoost.lua",
		"Legit/HitColor.lua",
		"Legit/HitFix.lua",
		"Legit/Interface.lua",
		"Legit/KillEffect.lua",
		"Legit/ReachDisplay.lua",
		"Legit/SongBeats.lua",
		"Legit/SoundChanger.lua",
		"Legit/UICleanup.lua",
		"Legit/Viewmodel.lua",
		"Legit/WinEffect.lua",
		"Combat/AimAssist.lua",
		"Combat/AutoClicker.lua",
		"Combat/NoClickDelay.lua",
		"Combat/Reach.lua",
		"Combat/Sprint.lua",
		"Combat/TriggerBot.lua",
		"Combat/Velocity.lua"
	}
	for _, modPath in publicMods do
		pcall(function()
			local code = game:HttpGet("https://raw.githubusercontent.com/xdxd09266-byte/test/main/src/games/bedwars/6872274481%20-%20game/"..modPath, true)
			if code and #code > 10 then
				loadstring(code, modPath)()
			end
			pcall(function()
				task.wait(0.01)
			end)
		end)
	end
end)

