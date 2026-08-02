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
if not vape then
	error("[ezvape] You executed the game module directly. You need to execute main.lua instead, which will automatically load this script once the GUI engine is initialized.")
end
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

run(function()
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

run(function()
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
					groundHitEvent.SendToServer = function(self, blockHit, velocity, serverTime, ...)
						if NoFall.Enabled and typeof(velocity) == "Vector3" then
							velocity = Vector3.new(velocity.X, -10, velocity.Z)
						end
						return oldSendToServer(self, blockHit, velocity, serverTime, ...)
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

end)

run(function()
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

PounceBoost = vape.Categories.Blatant:CreateModule({
    Name = 'Pounce Boost',
    Function = function(callback)
   
        if callback then

            local originalLeap = bedwars.CatController.leap
            

            bedwars.CatController.leap = function(self, character, direction)

                self.midLeap = true
                self.jumpMaid:GiveTask(function()
                    self.midLeap = false
                end)
                
                local hrp = character.HumanoidRootPart
                if not hrp then return end
                
                local mass = hrp.AssemblyMass or 1
                local boostActive = true
                local startTime = tick()
                local duration = BoostDuration.Value -- 1.5 seconds
                local power = BoostPower.Value -- Boost strength
                
    
                character.Humanoid.JumpHeight = 0.5
                character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                
                local boostDirection = direction.Unit * Vector3.new(1, 0, 1)
                
  
                local bodyForce = Instance.new("BodyForce")
                bodyForce.Force = Vector3.new(0, 0, 0)
                bodyForce.Parent = hrp
                

                self.jumpMaid:GiveTask(function()
                    boostActive = false
                    bodyForce:Destroy()
                end)
                
          
                local connection
                connection = runService.Heartbeat:Connect(function(deltaTime)
                    if not boostActive or not hrp.Parent then
                        connection:Disconnect()
                        return
                    end
                    
                    local elapsed = tick() - startTime
                    
                    if elapsed >= duration then
                        boostActive = false
                        bodyForce:Destroy()
                        connection:Disconnect()
                        return
                    end
                    
           
                    local remainingPercent = 1 - (elapsed / duration)
                    local currentForce = mass * power * remainingPercent
             
                    local moveDirection = AntiFallDirection or character.Humanoid.MoveDirection
                    local finalDirection = moveDirection.Magnitude > 0 and moveDirection.Unit or boostDirection
                    
             
                    if WallCheck.Enabled then
                        rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        rayCheck.CollisionGroup = hrp.CollisionGroup
                        
                        local destination = finalDirection * currentForce * dt
                        local ray = workspace:Raycast(hrp.Position, destination, rayCheck)
                        if ray then
                            destination = ((ray.Position + ray.Normal) - hrp.Position)
               
                            bodyForce.Force = destination / dt
                        else
                            bodyForce.Force = finalDirection * currentForce
                        end
                    else
                        bodyForce.Force = finalDirection * currentForce
                    end
                
                    bodyForce.Force = bodyForce.Force + Vector3.new(0, mass * 30, 0)
                    
           
                    if AutoJump.Enabled then
                        local state = character.Humanoid:GetState()
                        if (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and 
                           moveDirection ~= Vector3.zero and 
                           (Attacking or AlwaysJump.Enabled) then
                            character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
                
    
                SoundManager:playSound(RandomUtil.fromList(unpack({
                    GameSound.CAT_POUNCE_1, 
                    GameSound.CAT_POUNCE_2, 
                    GameSound.CAT_POUNCE_3
                })), {
                    position = hrp.Position
                })
                
                KnitClient.Controllers.ViewmodelController:playAnimation(AnimationType.DAGGER_CHARGE)
                KnitClient.Controllers.ViewmodelController:playAnimation(AnimationType.FP_USE_ITEM)
                
       
                PounceBoost:Clean(function()
                    boostActive = false
                    if bodyForce then bodyForce:Destroy() end
                    if connection then connection:Disconnect() end
                    
                    bedwars.CatController.leap = originalLeap
                end)
            end
        else
            
            if originalLeap then
                bedwars.CatController.leap = originalLeap
            end
        end
    end,
    ExtraText = function()
        return 'Heatseeker'
    end,
    Tooltip = 'Boosts your Cat pounce for 1.5 seconds with continuous momentum.'
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
    Max = 150,
    Default = 70,
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

-- Additional options
local FalloffMode = PounceBoost:CreateDropdown({
    Name = 'Falloff Mode',
    Options = {'Linear', 'Exponential', 'None'},
    Default = 'Linear'
})

local VerticalBoost = PounceBoost:CreateSlider({
    Name = 'Vertical Boost',
    Min = 0,
    Max = 100,
    Default = 30,
    Suffix = function(val)
        return val == 1 and 'force' or 'force'
    end
})
end)

run(function()
local BedBreakEffect
local Mode
local List
local NameToId = {}

BedBreakEffect = vape.Legit:CreateModule({
	Name = 'Bed Break Effect',
	Function = function(callback)
		if callback then
            BedBreakEffect:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function(data)
                firesignal(bedwars.Client:Get('BedBreakEffectTriggered').instance.OnClientEvent, {
                    player = data.player,
                    position = data.bedBlockPosition * 3,
                    effectType = NameToId[List.Value],
                    teamId = data.brokenBedTeam.id,
                    centerBedPosition = data.bedBlockPosition * 3
                })
            end))
        end
	end,
	Tooltip = 'Custom bed break effects'
})
local BreakEffectName = {}
for i, v in bedwars.BedBreakEffectMeta do
	table.insert(BreakEffectName, v.name)
	NameToId[v.name] = i
end
table.sort(BreakEffectName)
List = BedBreakEffect:CreateDropdown({
	Name = 'Effect',
	List = BreakEffectName
})
end)

run(function()
vape.Legit:CreateModule({
	Name = 'Clean Kit',
	Function = function(callback)
		if callback then
			bedwars.WindWalkerController.spawnOrb = function() end
			local zephyreffect = lplr.PlayerGui:FindFirstChild('WindWalkerEffect', true)
			if zephyreffect then 
				zephyreffect.Visible = false 
			end
		end
	end,
	Tooltip = 'Removes zephyr status indicator'
})
end)

run(function()
local old
local Image

local Crosshair = vape.Legit:CreateModule({
	Name = 'Crosshair',
	Function = function(callback)
		if callback then
			old = debug.getconstant(bedwars.ViewmodelController.showCrosshair, 25)
			debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, Image.Value)
			debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, Image.Value)
		else
			debug.setconstant(bedwars.ViewmodelController.showCrosshair, 25, old)
			debug.setconstant(bedwars.ViewmodelController.showCrosshair, 37, old)
			old = nil
		end

		if bedwars.ViewmodelController.crosshair then
			bedwars.ViewmodelController:hideCrosshair()
			bedwars.ViewmodelController:showCrosshair()
		end
	end,
	Tooltip = 'Custom first person crosshair depending on the image choosen.'
})
Image = Crosshair:CreateTextBox({
	Name = 'Image',
	Placeholder = 'image id (roblox)',
	Function = function(enter)
		if enter and Crosshair.Enabled then
			Crosshair:Toggle()
			Crosshair:Toggle()
		end
	end
})
end)

run(function()
local DamageIndicator
local FontOption
local Color
local Size
local Anchor
local Stroke
local suc, tab = pcall(function()
	return debug.getupvalue(bedwars.DamageIndicator, 2)
end)
tab = suc and tab or {}
local oldvalues, oldfont = {}

DamageIndicator = vape.Legit:CreateModule({
	Name = 'Damage Indicator',
	Function = function(callback)
		if callback then
			oldvalues = table.clone(tab)
			oldfont = debug.getconstant(bedwars.DamageIndicator, 86)
			debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[FontOption.Value])
			debug.setconstant(bedwars.DamageIndicator, 119, Stroke.Enabled and 'Thickness' or 'Enabled')
			tab.strokeThickness = Stroke.Enabled and 1 or false
			tab.textSize = Size.Value
			tab.blowUpSize = Size.Value
			tab.blowUpDuration = 0
			tab.baseColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			tab.blowUpCompleteDuration = 0
			tab.anchoredDuration = Anchor.Value
		else
			for i, v in oldvalues do
				tab[i] = v
			end
			debug.setconstant(bedwars.DamageIndicator, 86, oldfont)
			debug.setconstant(bedwars.DamageIndicator, 119, 'Thickness')
		end
	end,
	Tooltip = 'Customize the damage indicator'
})
local fontitems = {'GothamBlack'}
for _, v in Enum.Font:GetEnumItems() do
	if v.Name ~= 'GothamBlack' then
		table.insert(fontitems, v.Name)
	end
end
FontOption = DamageIndicator:CreateDropdown({
	Name = 'Font',
	List = fontitems,
	Function = function(val)
		if DamageIndicator.Enabled then
			debug.setconstant(bedwars.DamageIndicator, 86, Enum.Font[val])
		end
	end
})
Color = DamageIndicator:CreateColorSlider({
	Name = 'Color',
	DefaultHue = 0,
	Function = function(hue, sat, val)
		if DamageIndicator.Enabled then
			tab.baseColor = Color3.fromHSV(hue, sat, val)
		end
	end
})
Size = DamageIndicator:CreateSlider({
	Name = 'Size',
	Min = 1,
	Max = 32,
	Default = 32,
	Function = function(val)
		if DamageIndicator.Enabled then
			tab.textSize = val
			tab.blowUpSize = val
		end
	end
})
Anchor = DamageIndicator:CreateSlider({
	Name = 'Anchor',
	Min = 0,
	Max = 1,
	Decimal = 10,
	Function = function(val)
		if DamageIndicator.Enabled then
			tab.anchoredDuration = val
		end
	end
})
Stroke = DamageIndicator:CreateToggle({
	Name = 'Stroke',
	Function = function(callback)
		if DamageIndicator.Enabled then
			debug.setconstant(bedwars.DamageIndicator, 119, callback and 'Thickness' or 'Enabled')
			tab.strokeThickness = callback and 1 or false
		end
	end
})
end)

run(function()
local FOV
local Value
local old, old2

FOV = vape.Legit:CreateModule({
	Name = 'FOV',
	Function = function(callback)
		if callback then
			old = bedwars.FovController.setFOV
			old2 = bedwars.FovController.getFOV
			bedwars.FovController.setFOV = function(self) 
				return old(self, Value.Value) 
			end
			bedwars.FovController.getFOV = function() 
				return Value.Value 
			end
		else
			bedwars.FovController.setFOV = old
			bedwars.FovController.getFOV = old2
		end
		
		bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
	end,
	Tooltip = 'Adjusts camera vision'
})
Value = FOV:CreateSlider({
	Name = 'FOV',
	Min = 30,
	Max = 120
})
end)

run(function()
local FPSBoost
local Kill
local Visualizer
local effects, util = {}, {}

FPSBoost = vape.Legit:CreateModule({
	Name = 'FPS Boost',
	Function = function(callback)
		if callback then
			if Kill.Enabled then
				for i, v in bedwars.KillEffectController.killEffects do
					if not i:find('Custom') then
						effects[i] = v
						bedwars.KillEffectController.killEffects[i] = {
							new = function() 
								return {
									onKill = function() end, 
									isPlayDefaultKillEffect = function() 
										return true 
									end
								} 
							end
						}
					end
				end
			end

			if Visualizer.Enabled then
				for i, v in bedwars.VisualizerUtils do
					util[i] = v
					bedwars.VisualizerUtils[i] = function() end
				end
			end

			repeat task.wait() until store.matchState ~= 0
			if not bedwars.AppController then return end
			bedwars.NametagController.addGameNametag = function() end
			for _, v in bedwars.AppController:getOpenApps() do
				if tostring(v):find('Nametag') then
					bedwars.AppController:closeApp(tostring(v))
				end
			end
		else
			for i, v in effects do 
				bedwars.KillEffectController.killEffects[i] = v 
			end
			for i, v in util do 
				bedwars.VisualizerUtils[i] = v 
			end
			table.clear(effects)
			table.clear(util)
		end
	end,
	Tooltip = 'Improves the framerate by turning off certain effects'
})
Kill = FPSBoost:CreateToggle({
	Name = 'Kill Effects',
	Function = function()
		if FPSBoost.Enabled then
			FPSBoost:Toggle()
			FPSBoost:Toggle()
		end
	end,
	Default = true
})
Visualizer = FPSBoost:CreateToggle({
	Name = 'Visualizer',
	Function = function()
		if FPSBoost.Enabled then
			FPSBoost:Toggle()
			FPSBoost:Toggle()
		end
	end,
	Default = true
})
end)

run(function()
local HitColor
local Color
local done = {}

HitColor = vape.Legit:CreateModule({
	Name = 'Hit Color',
	Function = function(callback)
		if callback then 
			repeat
				for i, v in entitylib.List do 
					local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
					if highlight then 
						if not table.find(done, highlight) then 
							table.insert(done, highlight) 
						end
						highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
						highlight.FillTransparency = Color.Opacity
					end
				end
				task.wait(0.1)
			until not HitColor.Enabled
		else
			for i, v in done do 
				v.FillColor = Color3.new(1, 0, 0)
				v.FillTransparency = 0.4
			end
			table.clear(done)
		end
	end,
	Tooltip = 'Customize the hit highlight options'
})
Color = HitColor:CreateColorSlider({
	Name = 'Color',
	DefaultOpacity = 0.4
})
end)

run(function()
vape.Legit:CreateModule({
	Name = 'HitFix',
	Function = function(callback)
		debug.setconstant(bedwars.SwordController.swingSwordAtMouse, 23, callback and 'raycast' or 'Raycast')
		debug.setupvalue(bedwars.SwordController.swingSwordAtMouse, 4, callback and bedwars.QueryUtil or workspace)
	end,
	Tooltip = 'Changes the raycast function to the correct one'
})
end)

run(function()
local Interface
local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
local HotbarHealthbar = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
local HotbarApp = getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
local old, new = {}, {}

vape:Clean(function()
	for _, v in new do
		table.clear(v)
	end
	for _, v in old do
		table.clear(v)
	end
	table.clear(new)
	table.clear(old)
end)

local function modifyconstant(func, ind, val)
	if not func then return end
	if not old[func] then old[func] = {} end
	if not new[func] then new[func] = {} end
	if not old[func][ind] then
		old[func][ind] = debug.getconstant(func, ind)
	end
	if typeof(old[func][ind]) ~= typeof(val) then return end
	new[func][ind] = val

	if Interface.Enabled then
		if val then
			debug.setconstant(func, ind, val)
		else
			debug.setconstant(func, ind, old[func][ind])
			old[func][ind] = nil
		end
	end
end

Interface = vape.Legit:CreateModule({
	Name = 'Interface',
	Function = function(callback)
		for i, v in (callback and new or old) do
			for i2, v2 in v do
				debug.setconstant(i, i2, v2)
			end
		end
	end,
	Tooltip = 'Customize bedwars UI'
})
local fontitems = {'LuckiestGuy'}
for _, v in Enum.Font:GetEnumItems() do
	if v.Name ~= 'LuckiestGuy' then
		table.insert(fontitems, v.Name)
	end
end
Interface:CreateDropdown({
	Name = 'Health Font',
	List = fontitems,
	Function = function(val)
		modifyconstant(HotbarHealthbar.render, 77, val)
	end
})
Interface:CreateColorSlider({
	Name = 'Health Color',
	Function = function(hue, sat, val)
		modifyconstant(HotbarHealthbar.render, 16, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
		if Interface.Enabled then
			local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
			hotbar = hotbar and hotbar:FindFirstChild('HealthbarProgressWrapper', true)
			if hotbar then
				hotbar['1'].BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			end
		end
	end
})
Interface:CreateColorSlider({
	Name = 'Hotbar Color',
	DefaultOpacity = 0.8,
	Function = function(hue, sat, val, opacity)
		local func = oldinvrender or HotbarOpenInventory.render
		modifyconstant(debug.getupvalue(HotbarApp, 23).render, 51, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
		modifyconstant(debug.getupvalue(HotbarApp, 23).render, 58, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
		modifyconstant(debug.getupvalue(HotbarApp, 23).render, 54, 1 - opacity)
		modifyconstant(debug.getupvalue(HotbarApp, 23).render, 55, math.clamp(1.2 - opacity, 0, 1))
		modifyconstant(func, 31, tonumber(Color3.fromHSV(hue, sat, val):ToHex(), 16))
		modifyconstant(func, 32, math.clamp(1.2 - opacity, 0, 1))
		modifyconstant(func, 34, tonumber(Color3.fromHSV(hue, sat, math.clamp(val > 0.5 and val - 0.2 or val + 0.2, 0, 1)):ToHex(), 16))
	end
})
end)

run(function()
local KillEffect
local Mode
local List
local NameToId = {}

local killeffects = {
	Gravity = function(_, _, char, _)
		char:BreakJoints()
		local highlight = char:FindFirstChildWhichIsA('Highlight')
		local nametag = char:FindFirstChild('Nametag', true)
		if highlight then
			highlight:Destroy()
		end
		if nametag then
			nametag:Destroy()
		end

		task.spawn(function()
			local partvelo = {}
			for _, v in char:GetDescendants() do
				if v:IsA('BasePart') then
					partvelo[v.Name] = v.Velocity
				end
			end
			char.Archivable = true
			local clone = char:Clone()
			clone.Humanoid.Health = 100
			clone.Parent = workspace
			game:GetService('Debris'):AddItem(clone, 30)
			char:Destroy()
			task.wait(0.01)
			clone.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
			clone:BreakJoints()
			task.wait(0.01)
			for _, v in clone:GetDescendants() do
				if v:IsA('BasePart') then
					local bodyforce = Instance.new('BodyForce')
					bodyforce.Force = Vector3.new(0, (workspace.Gravity - 10) * v:GetMass(), 0)
					bodyforce.Parent = v
					v.CanCollide = true
					v.Velocity = partvelo[v.Name] or Vector3.zero
				end
			end
		end)
	end,
	Lightning = function(_, _, char, _)
		char:BreakJoints()
		local highlight = char:FindFirstChildWhichIsA('Highlight')
		if highlight then
			highlight:Destroy()
		end
		local startpos = 1125
		local startcf = char.PrimaryPart.CFrame.p - Vector3.new(0, 8, 0)
		local newpos = Vector3.new((math.random(1, 10) - 5) * 2, startpos, (math.random(1, 10) - 5) * 2)

		for i = startpos - 75, 0, -75 do
			local newpos2 = Vector3.new((math.random(1, 10) - 5) * 2, i, (math.random(1, 10) - 5) * 2)
			if i == 0 then
				newpos2 = Vector3.zero
			end
			local part = Instance.new('Part')
			part.Size = Vector3.new(1.5, 1.5, 77)
			part.Material = Enum.Material.SmoothPlastic
			part.Anchored = true
			part.Material = Enum.Material.Neon
			part.CanCollide = false
			part.CFrame = CFrame.new(startcf + newpos + ((newpos2 - newpos) * 0.5), startcf + newpos2)
			part.Parent = workspace
			local part2 = part:Clone()
			part2.Size = Vector3.new(3, 3, 78)
			part2.Color = Color3.new(0.7, 0.7, 0.7)
			part2.Transparency = 0.7
			part2.Material = Enum.Material.SmoothPlastic
			part2.Parent = workspace
			game:GetService('Debris'):AddItem(part, 0.5)
			game:GetService('Debris'):AddItem(part2, 0.5)
			bedwars.QueryUtil:setQueryIgnored(part, true)
			bedwars.QueryUtil:setQueryIgnored(part2, true)
			if i == 0 then
				local soundpart = Instance.new('Part')
				soundpart.Transparency = 1
				soundpart.Anchored = true
				soundpart.Size = Vector3.zero
				soundpart.Position = startcf
				soundpart.Parent = workspace
				bedwars.QueryUtil:setQueryIgnored(soundpart, true)
				local sound = Instance.new('Sound')
				sound.SoundId = 'rbxassetid://6993372814'
				sound.Volume = 2
				sound.Pitch = 0.5 + (math.random(1, 3) / 10)
				sound.Parent = soundpart
				sound:Play()
				sound.Ended:Connect(function()
					soundpart:Destroy()
				end)
			end
			newpos = newpos2
		end
	end,
	Delete = function(_, _, char, _)
		char:Destroy()
	end
}

KillEffect = vape.Legit:CreateModule({
	Name = 'Kill Effect',
	Function = function(callback)
		if callback then
			for i, v in killeffects do
				bedwars.KillEffectController.killEffects['Custom'..i] = {
					new = function()
						return {
							onKill = v,
							isPlayDefaultKillEffect = function()
								return false
							end
						}
					end
				}
			end
			KillEffect:Clean(lplr:GetAttributeChangedSignal('KillEffectType'):Connect(function()
				lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
			end))
			lplr:SetAttribute('KillEffectType', Mode.Value == 'Bedwars' and NameToId[List.Value] or 'Custom'..Mode.Value)
		else
			for i in killeffects do
				bedwars.KillEffectController.killEffects['Custom'..i] = nil
			end
			lplr:SetAttribute('KillEffectType', 'default')
		end
	end,
	Tooltip = 'Custom final kill effects'
})
local modes = {'Bedwars'}
for i in killeffects do
	table.insert(modes, i)
end
Mode = KillEffect:CreateDropdown({
	Name = 'Mode',
	List = modes,
	Function = function(val)
		List.Object.Visible = val == 'Bedwars'
		if KillEffect.Enabled then
			lplr:SetAttribute('KillEffectType', val == 'Bedwars' and NameToId[List.Value] or 'Custom'..val)
		end
	end
})
local KillEffectName = {}
for i, v in bedwars.KillEffectMeta do
	table.insert(KillEffectName, v.name)
	NameToId[v.name] = i
end
table.sort(KillEffectName)
List = KillEffect:CreateDropdown({
	Name = 'Bedwars',
	List = KillEffectName,
	Function = function(val)
		if KillEffect.Enabled then
			lplr:SetAttribute('KillEffectType', NameToId[val])
		end
	end,
	Darker = true
})
end)

run(function()
local ReachDisplay
local label

ReachDisplay = vape.Legit:CreateModule({
	Name = 'Reach Display',
	Function = function(callback)
		if callback then
			repeat
				label.Text = (store.attackReachUpdate > tick() and store.attackReach or '0.00')..' studs'
				task.wait(0.4)
			until not ReachDisplay.Enabled
		end
	end,
	Size = UDim2.fromOffset(100, 41)
})
ReachDisplay:CreateFont({
	Name = 'Font',
	Blacklist = 'Gotham',
	Function = function(val)
		label.FontFace = val
	end
})
ReachDisplay:CreateColorSlider({
	Name = 'Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		label.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
		label.BackgroundTransparency = 1 - opacity
	end
})
label = Instance.new('TextLabel')
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 0.5
label.TextSize = 15
label.Font = Enum.Font.Gotham
label.Text = '0.00 studs'
label.TextColor3 = Color3.new(1, 1, 1)
label.BackgroundColor3 = Color3.new()
label.Parent = ReachDisplay.Children
local corner = Instance.new('UICorner')
corner.CornerRadius = UDim.new(0, 4)
corner.Parent = label
end)

run(function()
local SongBeats
local List
local FOV
local FOVValue = {}
local Volume
local alreadypicked = {}
local beattick = tick()
local oldfov, songobj, songbpm, songtween

local function choosesong()
	local list = List.ListEnabled
	if #alreadypicked >= #list then 
		table.clear(alreadypicked) 
	end

	if #list <= 0 then
		notif('SongBeats', 'no songs', 10)
		SongBeats:Toggle()
		return
	end

	local chosensong = list[math.random(1, #list)]
	if #list > 1 and table.find(alreadypicked, chosensong) then
		repeat 
			task.wait() 
			chosensong = list[math.random(1, #list)] 
		until not table.find(alreadypicked, chosensong) or not SongBeats.Enabled
	end
	if not SongBeats.Enabled then return end

	local split = chosensong:split('/')
	if not isfile(split[1]) then
		notif('SongBeats', 'Missing song ('..split[1]..')', 10)
		SongBeats:Toggle()
		return
	end

	songobj.SoundId = assetfunction(split[1])
	repeat task.wait() until songobj.IsLoaded or not SongBeats.Enabled
	if SongBeats.Enabled then
		beattick = tick() + (tonumber(split[3]) or 0)
		songbpm = 60 / (tonumber(split[2]) or 50)
		songobj:Play()
	end
end

SongBeats = vape.Legit:CreateModule({
	Name = 'Song Beats',
	Function = function(callback)
		if callback then
			songobj = Instance.new('Sound')
			songobj.Volume = Volume.Value / 100
			songobj.Parent = workspace
			repeat
				if not songobj.Playing then choosesong() end
				if beattick < tick() and SongBeats.Enabled and FOV.Enabled then
					beattick = tick() + songbpm
					oldfov = math.min(bedwars.FovController:getFOV() * (bedwars.SprintController.sprinting and 1.1 or 1), 120)
					gameCamera.FieldOfView = oldfov - FOVValue.Value
					songtween = tweenService:Create(gameCamera, TweenInfo.new(math.min(songbpm, 0.2), Enum.EasingStyle.Linear), {FieldOfView = oldfov})
					songtween:Play()
				end
				task.wait()
			until not SongBeats.Enabled
		else
			if songobj then
				songobj:Destroy()
			end
			if songtween then
				songtween:Cancel()
			end
			if oldfov then
				gameCamera.FieldOfView = oldfov
			end
			table.clear(alreadypicked)
		end
	end,
	Tooltip = 'Built in mp3 player'
})
List = SongBeats:CreateTextList({
	Name = 'Songs',
	Placeholder = 'filepath/bpm/start'
})
FOV = SongBeats:CreateToggle({
	Name = 'Beat FOV',
	Function = function(callback)
		if FOVValue.Object then
			FOVValue.Object.Visible = callback
		end
		if SongBeats.Enabled then
			SongBeats:Toggle()
			SongBeats:Toggle()
		end
	end,
	Default = true
})
FOVValue = SongBeats:CreateSlider({
	Name = 'Adjustment',
	Min = 1,
	Max = 30,
	Default = 5,
	Darker = true
})
Volume = SongBeats:CreateSlider({
	Name = 'Volume',
	Function = function(val)
		if songobj then 
			songobj.Volume = val / 100 
		end
	end,
	Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
end)

run(function()
local SoundChanger
local List
local soundlist = {}
local old

SoundChanger = vape.Legit:CreateModule({
	Name = 'SoundChanger',
	Function = function(callback)
		if callback then
			old = bedwars.SoundManager.playSound
			bedwars.SoundManager.playSound = function(self, id, ...)
				if soundlist[id] then
					id = soundlist[id]
				end

				return old(self, id, ...)
			end
		else
			bedwars.SoundManager.playSound = old
			old = nil
		end
	end,
	Tooltip = 'Change ingame sounds to custom ones.'
})
List = SoundChanger:CreateTextList({
	Name = 'Sounds',
	Placeholder = '(DAMAGE_1/ben.mp3)',
	Function = function()
		table.clear(soundlist)
		for _, entry in List.ListEnabled do
			local split = entry:split('/')
			local id = bedwars.SoundList[split[1]]
			if id and #split > 1 then
				soundlist[id] = split[2]:find('rbxasset') and split[2] or isfile(split[2]) and assetfunction(split[2]) or ''
			end
		end
	end
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

run(function()
local UICleanup
local OpenInv
local KillFeed
local OldTabList
local noHotbarNumsConn, resizeHealthConn
local HotbarOpenInventory = require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
local oldkillfeed

UICleanup = vape.Legit:CreateModule({
	Name = 'UI Cleanup',
	Function = function(callback)
		if callback then
			if OpenInv.Enabled then
				oldinvrender = HotbarOpenInventory.render
				HotbarOpenInventory.render = function()
					return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
				end
			end

			if KillFeed.Enabled then
				oldkillfeed = bedwars.KillFeedController.addToKillFeed
				bedwars.KillFeedController.addToKillFeed = function() end
			end

			if OldTabList.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
			end
		else
			if oldinvrender then
				HotbarOpenInventory.render = oldinvrender
				oldinvrender = nil
			end

			if KillFeed.Enabled then
				bedwars.KillFeedController.addToKillFeed = oldkillfeed
				oldkillfeed = nil
			end

			if OldTabList.Enabled then
				starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end
		end
	end,
	Tooltip = 'Cleans up the UI for kits & main'
})
UICleanup:CreateToggle({
	Name = 'No Hotbar Numbers',
	Function = function(callback)
		if callback then
			noHotbarNumsConn = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui").ChildAdded:Connect(function(inst)
				if inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					task.spawn(function()
						task.wait(0.5)
						for _, label in pairs(inst:GetDescendants()) do
							if label:IsA("TextLabel") and label.Text:match("^[1-9]$") then
								label:GetPropertyChangedSignal("Text"):Connect(function()
									if label.Text:match("^[1-9]$") then label.Text = "" end
								end)
								if label.Text:match("^[1-9]$") then label.Text = "" end
							end
						end
					end)
				end
			end)
			task.wait(0.5)
			for _, inst in pairs(lplr.PlayerGui:GetChildren()) do
				if inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					for _, label in pairs(inst:GetDescendants()) do
						if label:IsA("TextLabel") and label.Text:match("^[1-9]$") then
							label.Text = ""
						end
					end
				end
			end
		elseif noHotbarNumsConn then
			noHotbarNumsConn:Disconnect()
			noHotbarNumsConn = nil
		end
	end,
	Default = true
})
UICleanup:CreateToggle({
	Name = 'Resize Health',
	Function = function(callback)
		if callback then
			resizeHealthConn = lplr.PlayerGui.ChildAdded:Connect(function(inst)
				if inst.Name:find("health") or inst.Name:find("Health") or inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					task.spawn(function()
						task.wait(0.5)
						for _, label in pairs(inst:GetDescendants()) do
							if label:IsA("TextLabel") and label.Text:match("^%d+$") and label.Text:len() <= 4 then
								label.TextSize = label.TextSize + 2
							end
						end
					end)
				end
			end)
			task.wait(0.5)
			for _, inst in pairs(lplr.PlayerGui:GetChildren()) do
				if inst.Name:find("health") or inst.Name:find("Health") or inst.Name:find("hotbar") or inst.Name:find("Hotbar") then
					for _, label in pairs(inst:GetDescendants()) do
						if label:IsA("TextLabel") and label.Text:match("^%d+$") and label.Text:len() <= 4 then
							label.TextSize = label.TextSize + 2
						end
					end
				end
			end
		elseif resizeHealthConn then
			resizeHealthConn:Disconnect()
			resizeHealthConn = nil
		end
	end,
	Default = true
})
OpenInv = UICleanup:CreateToggle({
	Name = 'No Inventory Button',
	Function = function(callback)
		if UICleanup.Enabled then
			if callback then
				oldinvrender = HotbarOpenInventory.render
				HotbarOpenInventory.render = function()
					return bedwars.Roact.createElement('TextButton', {Visible = false}, {})
				end
			else
				HotbarOpenInventory.render = oldinvrender
				oldinvrender = nil
			end
		end
	end,
	Default = true
})
KillFeed = UICleanup:CreateToggle({
	Name = 'No Kill Feed',
	Function = function(callback)
		if UICleanup.Enabled then
			if callback then
				oldkillfeed = bedwars.KillFeedController.addToKillFeed
				bedwars.KillFeedController.addToKillFeed = function() end
			else
				bedwars.KillFeedController.addToKillFeed = oldkillfeed
				oldkillfeed = nil
			end
		end
	end,
	Default = true
})
OldTabList = UICleanup:CreateToggle({
	Name = 'Old Player List',
	Function = function(callback)
		if UICleanup.Enabled then
			starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, callback)
		end
	end,
	Default = true
})
UICleanup:CreateToggle({
	Name = 'Fix Queue Card',
	Function = function(callback)
		if callback then
			bedwars.QueueCard.render = function()
				return bedwars.Roact.createElement('Frame', {Visible = false, Size = UDim2.new(0, 0, 0, 0)}, {})
			end
		end
	end,
	Default = true
})
end)

run(function()
local Viewmodel
local Depth
local Horizontal
local Vertical
local NoBob
local Rots = {}
local old, oldc1

Viewmodel = vape.Legit:CreateModule({
	Name = 'Viewmodel',
	Function = function(callback)
		local viewmodel = gameCamera:FindFirstChild('Viewmodel')
		if callback then
			old = bedwars.ViewmodelController.playAnimation
			oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
			if NoBob.Enabled then
				bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
					if bedwars.AnimationType and animtype == bedwars.AnimationType.FP_WALK then return end
					return old(self, animtype, ...)
				end
			end

			bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
			if viewmodel then
				gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
			end
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
		else
			bedwars.ViewmodelController.playAnimation = old
			if viewmodel then
				viewmodel.RightHand.RightWrist.C1 = oldc1
			end

			bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
			old = nil
		end
	end,
	Tooltip = 'Changes the viewmodel animations'
})
Depth = Viewmodel:CreateSlider({
	Name = 'Depth',
	Min = 0,
	Max = 2,
	Default = 0.8,
	Decimal = 10,
	Function = function(val)
		if Viewmodel.Enabled then
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
		end
	end
})
Horizontal = Viewmodel:CreateSlider({
	Name = 'Horizontal',
	Min = 0,
	Max = 2,
	Default = 0.8,
	Decimal = 10,
	Function = function(val)
		if Viewmodel.Enabled then
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
		end
	end
})
Vertical = Viewmodel:CreateSlider({
	Name = 'Vertical',
	Min = -0.2,
	Max = 2,
	Default = -0.2,
	Decimal = 10,
	Function = function(val)
		if Viewmodel.Enabled then
			lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
		end
	end
})
for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
	table.insert(Rots, Viewmodel:CreateSlider({
		Name = name,
		Min = 0,
		Max = 360,
		Function = function(val)
			if Viewmodel.Enabled then
				gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
			end
		end
	}))
end
NoBob = Viewmodel:CreateToggle({
	Name = 'No Bobbing',
	Default = true,
	Function = function()
		if Viewmodel.Enabled then
			Viewmodel:Toggle()
			Viewmodel:Toggle()
		end
	end
})
end)

run(function()
local WinEffect
local List
local NameToId = {}

WinEffect = vape.Legit:CreateModule({
	Name = 'WinEffect',
	Function = function(callback)
		if callback then
			WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(function()
				for i, v in getconnections(bedwars.Client:Get('WinEffectTriggered').instance.OnClientEvent) do
					if v.Function then
						v.Function({
							winEffectType = NameToId[List.Value],
							winningPlayer = lplr
						})
					end
				end
			end))
		end
	end,
	Tooltip = 'Allows you to select any clientside win effect'
})
local WinEffectName = {}
for i, v in bedwars.WinEffectMeta do
	table.insert(WinEffectName, v.name)
	NameToId[v.name] = i
end
table.sort(WinEffectName)
List = WinEffect:CreateDropdown({
	Name = 'Effects',
	List = WinEffectName
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
local AutoBalloon

AutoBalloon = vape.Categories.Utility:CreateModule({
	Name = 'AutoBalloon',
	Function = function(callback)
		if callback then
			repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
			if not AutoBalloon.Enabled then return end

			local lowestpoint = math.huge
			for _, v in store.blocks do
				local point = (v.Position.Y - (v.Size.Y / 2)) - 50
				if point < lowestpoint then 
					lowestpoint = point 
				end
			end

			repeat
				if entitylib.isAlive then
					if entitylib.character.RootPart.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) < 3 then
						local balloon = getItem('balloon')
						if balloon then
							for _ = 1, 3 do 
								bedwars.BalloonController:inflateBalloon() 
							end
						end
						task.wait(0.1)
					end
				end
				task.wait(0.1)
			until not AutoBalloon.Enabled
		end
	end,
	Tooltip = 'Inflates when you fall into the void'
})
end)

run(function()
local AutoKit
local Legit
local Toggles = {}

local function kitCollection(id, func, range, specific)
	local objs = type(id) == 'table' and id or collection(id, AutoKit)
	repeat
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in objs do
				if InfiniteFly.Enabled or not AutoKit.Enabled then break end
				local part = not v:IsA('Model') and v or v.PrimaryPart
				if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
					func(v)
				end
			end
		end
		task.wait(0.1)
	until not AutoKit.Enabled
end

local AutoKitFunctions = {
	battery = function()
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for i, v in bedwars.BatteryEffectsController.liveBatteries do
					if (v.position - localPosition).Magnitude <= 10 then
						local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
						if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
						BatteryInfo.consumeTime = workspace:GetServerTimeNow()
						bedwars.Client:Get(remotes.ConsumeBattery):SendToServer({batteryId = i})
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end,
	beekeeper = function()
		kitCollection('bee', function(v)
			bedwars.Client:Get(remotes.BeePickup):SendToServer({beeId = v:GetAttribute('BeeId')})
		end, 18, false)
	end,
	bigman = function()
		kitCollection('treeOrb', function(v)
			if bedwars.Client:Get(remotes.ConsumeTreeOrb):CallServer({treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
				v:Destroy()
			end
		end, 12, false)
	end,
	block_kicker = function()
		local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
		bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
			local origin, dir = select(2, ...)
			local plr = entitylib.EntityMouse({
				Part = 'RootPart',
				Range = 1000,
				Origin = origin,
				Players = true,
				Wallcheck = true
			})

			if plr then
				local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)

				if calc then
					for i, v in debug.getstack(2) do
						if v == dir then
							debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
						end
					end
				end
			end

			return old(...)
		end

		AutoKit:Clean(function()
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
		end)
	end,
	cat = function()
		local old = bedwars.CatController.leap
		bedwars.CatController.leap = function(...)
			vapeEvents.CatPounce:Fire()
			return old(...)
		end

		AutoKit:Clean(function()
			bedwars.CatController.leap = old
		end)
	end,
	davey = function()
		local old = bedwars.CannonHandController.launchSelf
		bedwars.CannonHandController.launchSelf = function(...)
			local res = {old(...)}
			local self, block = ...

			if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
				task.spawn(bedwars.breakBlock, block, false, nil, true)
			end

			return unpack(res)
		end

		AutoKit:Clean(function()
			bedwars.CannonHandController.launchSelf = old
		end)
	end,
	dragon_slayer = function()
		kitCollection('KaliyahPunchInteraction', function(v)
			bedwars.DragonSlayerController:deleteEmblem(v)
			bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
			bedwars.Client:Get(remotes.KaliyahPunch):SendToServer({
				target = v
			})
		end, 18, true)
	end,
	farmer_cletus = function()
		kitCollection('HarvestableCrop', function(v)
			if bedwars.Client:Get(remotes.HarvestCrop):CallServer({position = bedwars.BlockController:getBlockPosition(v.Position)}) then
				bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
				bedwars.SoundManager:playSound(bedwars.SoundList.CROP_HARVEST)
			end
		end, 10, false)
	end,
	fisherman = function()
		local old = bedwars.FishingMinigameController.startMinigame
		bedwars.FishingMinigameController.startMinigame = function(_, _, result)
			result({win = true})
		end

		AutoKit:Clean(function()
			bedwars.FishingMinigameController.startMinigame = old
		end)
	end,
	gingerbread_man = function()
		local old = bedwars.LaunchPadController.attemptLaunch
		bedwars.LaunchPadController.attemptLaunch = function(...)
			local res = {old(...)}
			local self, block = ...

			if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false, nil, true)
				end
			end

			return unpack(res)
		end

		AutoKit:Clean(function()
			bedwars.LaunchPadController.attemptLaunch = old
		end)
	end,
	hannah = function()
		kitCollection('HannahExecuteInteraction', function(v)
			local billboard = bedwars.Client:Get(remotes.HannahKill):CallServer({
				user = lplr,
				victimEntity = v
			}) and v:FindFirstChild('Hannah Execution Icon')

			if billboard then
				billboard:Destroy()
			end
		end, 30, true)
	end,
	jailor = function()
		kitCollection('jailor_soul', function(v)
			bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
		end, 20, false)
	end,
	grim_reaper = function()
		kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
			if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
				bedwars.Client:Get(remotes.ConsumeSoul):CallServer({
					secret = v:GetAttribute('GrimReaperSoulSecret')
				})
			end
		end, 120, false)
	end,
	melody = function()
		repeat
			local mag, hp, ent = 30, math.huge
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in entitylib.List do
					if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
						local newmag = (localPosition - v.RootPart.Position).Magnitude
						if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
							mag, hp, ent = newmag, v.Health, v
						end
					end
				end
			end

			if ent and getItem('guitar') then
				bedwars.Client:Get(remotes.GuitarHeal):SendToServer({
					healTarget = ent.Character
				})
			end

			task.wait(0.1)
		until not AutoKit.Enabled
	end,
	metal_detector = function()
		kitCollection('hidden-metal', function(v)
			bedwars.Client:Get(remotes.PickupMetal):SendToServer({
				id = v:GetAttribute('Id')
			})
		end, 20, false)
	end,
	miner = function()
		kitCollection('petrified-player', function(v)
			bedwars.Client:Get(remotes.MinerDig):SendToServer({
				petrifyId = v:GetAttribute('PetrifyId')
			})
		end, 6, true)
	end,
	pinata = function()
		kitCollection(lplr.Name..':pinata', function(v)
			if getItem('candy') then
				bedwars.Client:Get(remotes.DepositPinata):CallServer(v)
			end
		end, 6, true)
	end,
	spirit_assassin = function()
		kitCollection('EvelynnSoul', function(v)
			bedwars.SpiritAssassinController:useSpirit(lplr, v)
		end, 120, true)
	end,
	star_collector = function()
		kitCollection('stars', function(v)
			bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
		end, 20, false)
	end,
	summoner = function()
		repeat
			local plr = entitylib.EntityPosition({
				Range = 31,
				Part = 'RootPart',
				Players = true,
				Sort = sortmethods.Health
			})

			if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
				local localPosition = entitylib.character.RootPart.Position
				local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
				localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)

				bedwars.Client:Get(remotes.SummonerClawAttack):SendToServer({
					position = localPosition,
					direction = shootDir,
					clientTime = workspace:GetServerTimeNow()
				})
			end

			task.wait(0.1)
		until not AutoKit.Enabled
	end,
	void_dragon = function()
		local oldflap = bedwars.VoidDragonController.flapWings
		local flapped

		bedwars.VoidDragonController.flapWings = function(self)
			if not flapped and bedwars.Client:Get(remotes.DragonFly):CallServer() then
				local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
					blockSprint = true,
					constantSpeedMultiplier = 2
				})
				self.SpeedMaid:GiveTask(modifier)
				self.SpeedMaid:GiveTask(function()
					flapped = false
				end)
				flapped = true
			end
		end

		AutoKit:Clean(function()
			bedwars.VoidDragonController.flapWings = oldflap
		end)

		repeat
			if bedwars.VoidDragonController.inDragonForm then
				local plr = entitylib.EntityPosition({
					Range = 30,
					Part = 'RootPart',
					Players = true
				})

				if plr then
					bedwars.Client:Get(remotes.DragonBreath):SendToServer({
						player = lplr,
						targetPoint = plr.RootPart.Position
					})
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end,
	warlock = function()
		local lastTarget
		repeat
			if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
				local plr = entitylib.EntityPosition({
					Range = 30,
					Part = 'RootPart',
					Players = true,
					NPCs = true
				})

				if plr and plr.Character ~= lastTarget then
					if not bedwars.Client:Get(remotes.WarlockTarget):CallServer({
						target = plr.Character
					}) then
						plr = nil
					end
				end

				lastTarget = plr and plr.Character
			else
				lastTarget = nil
			end

			task.wait(0.1)
		until not AutoKit.Enabled
	end,
	wizard = function()
		repeat
			local ability = lplr:GetAttribute('WizardAbility')
			if ability and bedwars.AbilityController:canUseAbility(ability) then
				local plr = entitylib.EntityPosition({
					Range = 50,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})

				if plr then
					bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
				end
			end

			task.wait(0.1)
		until not AutoKit.Enabled
	end
}

AutoKit = vape.Categories.Utility:CreateModule({
	Name = 'AutoKit',
	Function = function(callback)
		if callback then
			repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
			if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
				AutoKitFunctions[store.equippedKit]()
			end
		end
	end,
	Tooltip = 'Automatically uses kit abilities.'
})
Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
local sortTable = {}
for i in AutoKitFunctions do
	table.insert(sortTable, i)
end
table.sort(sortTable, function(a, b)
	return bedwars.BedwarsKitMeta[a].name < bedwars.BedwarsKitMeta[b].name
end)
for _, v in sortTable do
	Toggles[v] = AutoKit:CreateToggle({
		Name = bedwars.BedwarsKitMeta[v].name,
		Default = true
	})
end
end)

run(function()
local AutoPearl
local rayCheck = RaycastParams.new()
rayCheck.RespectCanCollide = true
local projectileRemote = {InvokeServer = function() end}
task.spawn(function()
	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
end)

local function firePearl(pos, spot, item)
	switchItem(item.tool)
	local meta = bedwars.ProjectileMeta.telepearl
	local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)

	if calc then
		local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
		bedwars.ProjectileController:createLocalProjectile(meta, 'telepearl', 'telepearl', pos, nil, dir, {drawDurationSeconds = 1})
		projectileRemote:InvokeServer(item.tool, 'telepearl', 'telepearl', pos, pos, dir, httpService:GenerateGUID(true), {drawDurationSeconds = 1, shotId = httpService:GenerateGUID(false)}, workspace:GetServerTimeNow() - 0.045)
	end

	if store.hand then
		switchItem(store.hand.tool)
	end
end

AutoPearl = vape.Categories.Utility:CreateModule({
	Name = 'AutoPearl',
	Function = function(callback)
		if callback then
			local check
			repeat
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					local pearl = getItem('telepearl')
					rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
					rayCheck.CollisionGroup = root.CollisionGroup

					if pearl and root.Velocity.Y < -100 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
						if not check then
							check = true
							local ground = getNearGround(20)

							if ground then
								firePearl(root.Position, ground, pearl)
							end
						end
					else
						check = false
					end
				end
				task.wait(0.1)
			until not AutoPearl.Enabled
		end
	end,
	Tooltip = 'Automatically throws a pearl onto nearby ground after\nfalling a certain distance.'
})
end)

run(function()
local AutoPlay
local Random

local function isEveryoneDead()
	return #bedwars.Store:getState().Party.members <= 0
end

local function joinQueue()
	if not bedwars.Store:getState().Game.customMatch and bedwars.Store:getState().Party.leader.userId == lplr.UserId and bedwars.Store:getState().Party.queueState == 0 then
		if Random.Enabled then
			local listofmodes = {}
			for i, v in bedwars.QueueMeta do
				if not v.disabled and not v.voiceChatOnly and not v.rankCategory then 
					table.insert(listofmodes, i) 
				end
			end
			bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
		else
			bedwars.QueueController:joinQueue(store.queueType)
		end
	end
end

AutoPlay = vape.Categories.Utility:CreateModule({
	Name = 'AutoPlay',
	Function = function(callback)
		if callback then
			AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
				if deathTable.finalKill and deathTable.entityInstance == lplr.Character and isEveryoneDead() and store.matchState ~= 2 then
					joinQueue()
				end
			end))
			AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
		end
	end,
	Tooltip = 'Automatically queues after the match ends.'
})
Random = AutoPlay:CreateToggle({
	Name = 'Random',
	Tooltip = 'Chooses a random mode'
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
run(function()
    local oldUpdate
    local skaterController
    
    vape.Categories.Utility:CreateModule({
        Tooltip = "Disables Glacial Skater momentum override so you can fly with Heatseeker.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                pcall(function()
                    local Knit = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
                    skaterController = Knit.Controllers.GlacialSkaterController
                    
                    local MomentumBarUi = require(game:GetService("Players").LocalPlayer.PlayerScripts.TS.controllers.games.bedwars.kit.kits["glacial-skater"]["momentum-bar-ui"])
                    
                    if skaterController and not oldUpdate then
                        oldUpdate = skaterController.updateMomentum
                        skaterController.updateMomentum = function(self, ...)
                            self.momentum = 0
                            if MomentumBarUi and MomentumBarUi.momentumChanged then
                                MomentumBarUi.momentumChanged:Fire(0)
                            end
                            return
                        end
                        
                        -- Also remove the blockSprint modifier that Krystal applies on respawns
                        local SprintController = Knit.Controllers.SprintController
                        if SprintController then
                            local RunService = game:GetService("RunService")
                            KrystalModifierLoop = RunService.Heartbeat:Connect(function()
                                local mod = SprintController:getMovementStatusModifier()
                                if mod and mod.modifiers then
                                    for i = #mod.modifiers, 1, -1 do
                                        if type(mod.modifiers[i]) == "table" and mod.modifiers[i].blockSprint then
                                            mod:removeModifier(mod.modifiers[i])
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end)
            else
                if skaterController and oldUpdate then
                    skaterController.updateMomentum = oldUpdate
                    oldUpdate = nil
                end
                if KrystalModifierLoop then
                    KrystalModifierLoop:Disconnect()
                    KrystalModifierLoop = nil
                end
            end
            end
        end
    })
end)

end)

run(function()
local PickupRange
local Range
local Network
local Lower

PickupRange = vape.Categories.Utility:CreateModule({
	Name = 'PickupRange',
	Function = function(callback)
		if callback then
			local items = collection('ItemDrop', PickupRange)
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in items do
						if tick() - (v:GetAttribute('ClientDropTime') or 0) < 2 then continue end
						if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then 
							v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0)) 
						end
						
						if (localPosition - v.Position).Magnitude <= Range.Value then
							if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
							task.spawn(function()
								bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
									itemDrop = v
								}):andThen(function(suc)
									if suc and bedwars.SoundList then
										bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
										local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
										if sound then
											bedwars.SoundManager:playSound(sound, {
												position = v.Position,
												volumeMultiplier = 0.9
											})
										end
									end
								end)
							end)
						end
					end
				end
				task.wait(0.1)
			until not PickupRange.Enabled
		end
	end,
	Tooltip = 'Picks up items from a farther distance'
})
Range = PickupRange:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 10,
	Default = 10,
	Suffix = function(val) 
		return val == 1 and 'stud' or 'studs' 
	end
})
Network = PickupRange:CreateToggle({
	Name = 'Network TP',
	Default = true
})
Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
end)

run(function()
local RavenTP

RavenTP = vape.Categories.Utility:CreateModule({
	Name = 'RavenTP',
	Function = function(callback)
		if callback then
			RavenTP:Toggle()
			local plr = entitylib.EntityMouse({
				Range = 1000,
				Players = true,
				Part = 'RootPart'
			})

			if getItem('raven') and plr then
				bedwars.Client:Get(remotes.SpawnRaven):CallServerAsync():andThen(function(projectile)
					if projectile then
						local bodyforce = Instance.new('BodyForce')
						bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
						bodyforce.Parent = projectile.PrimaryPart

						if plr then
							task.spawn(function()
								for _ = 1, 20 do
									if plr.RootPart and projectile then
										projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
									end
									task.wait(0.05)
								end
							end)
							task.wait(0.3)
							bedwars.RavenController:detonateRaven()
						end
					end
				end)
			end
		end
	end,
	Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
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
-- WindWalker Crash Protector
-- Uses math.clamp(9e9, 9e9) as the maximum safe value

local Protection = {}
Protection.__index = Protection

function Protection.new()
    local self = setmetatable({}, Protection)
    self.enabled = true
    self.maxSpeed = 9e9
    self.maxOrbCount = 9e9
    self.maxPosition = 9e9
    self.maxOrbsPerFrame = 50
    self.orbSpawnCooldown = 0.05
    self._lastOrbTime = nil
    self._orbCount = 0
    self._heartbeat = nil
    return self
end

function Protection:init()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local player = Players.LocalPlayer
    
    -- Wait for everything to load
    task.wait(3)
    
    -- Try to find WindWalkerController
    local controller = nil
    
    -- Method 1: Check _G
    if _G.Knit and _G.Knit.Controllers then
        controller = _G.Knit.Controllers.WindWalkerController
    end
    
    -- Method 2: Check through RuntimeLib
    if not controller then
        local success, RuntimeLib = pcall(function()
            return require(ReplicatedStorage:WaitForChild("rbxts_include"):WaitForChild("RuntimeLib"))
        end)
        
        if success then
            local success2, KnitClient = pcall(function()
                return RuntimeLib.import(script, ReplicatedStorage, "rbxts_include", "node_modules", "@easy-games", "knit", "src").KnitClient
            end)
            
            if success2 then
                controller = KnitClient.Controllers.WindWalkerController
            end
        end
    end
    
    -- Method 3: GC scanning
    if not controller then
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and obj.Controllers and obj.Controllers.WindWalkerController then
                controller = obj.Controllers.WindWalkerController
                break
            end
        end
    end
    
    if not controller then
        print("[Protection] WindWalkerController not found")
        return false
    end
    
    print("[Protection] WindWalkerController found, protecting...")
    
    -- Store original methods
    self.controller = controller
    self.originalMethods = {
        updateSpeed = controller.updateSpeed,
        updateJump = controller.updateJump,
        spawnOrb = controller.spawnOrb,
    }
    
    -- Apply protection
    self:patchMethods()
    self:patchRemotes()
    self:monitorPerformance()
    
    return true
end

function Protection:patchMethods()
    local self = self
    local controller = self.controller
    
    -- Safe updateSpeed with math.clamp(9e9, 9e9)
    controller.updateSpeed = function(orig, ...)
        local args = {...}
        local multiplier = args[2] or 1
        
        -- Clamp using 9e9
        local safeMultiplier = math.clamp(multiplier, -9e9, 9e9)
        
        if multiplier ~= safeMultiplier then
            print("[Protection] Speed clamped:", multiplier, "->", safeMultiplier)
        end
        
        return self.originalMethods.updateSpeed(controller, safeMultiplier)
    end
    
    -- Safe updateJump with math.clamp(9e9, 9e9)
    controller.updateJump = function(orig, ...)
        local args = {...}
        local orbCount = args[2] or 0
        
        -- Clamp using 9e9
        local safeCount = math.clamp(orbCount, -9e9, 9e9)
        
        if orbCount ~= safeCount then
            print("[Protection] Orb count clamped:", orbCount, "->", safeCount)
        end
        
        return self.originalMethods.updateJump(controller, safeCount)
    end
    
    -- Safe spawnOrb with math.clamp(9e9, 9e9)
    controller.spawnOrb = function(orig, ...)
        local args = {...}
        local entity = args[2]
        local position = args[3]
        
        -- Clamp position using 9e9
        if position then
            local safePos = Vector3.new(
                math.clamp(position.X, -9e9, 9e9),
                math.clamp(position.Y, -9e9, 9e9),
                math.clamp(position.Z, -9e9, 9e9)
            )
            
            if position ~= safePos then
                print("[Protection] Position clamped:", position, "->", safePos)
            end
            
            position = safePos
        end
        
        -- Rate limit orbs
        if not self._lastOrbTime then
            self._lastOrbTime = tick()
        end
        
        local now = tick()
        if now - self._lastOrbTime < self.orbSpawnCooldown then
            print("[Protection] Orb spawn rate limited")
        end
        self._lastOrbTime = now
        
        -- Track orb count
        self._orbCount = (self._orbCount or 0) + 1
        if self._orbCount > self.maxOrbsPerFrame then
            print("[Protection] Too many orbs ("..self._orbCount.."), blocking")
            return nil
        end
        
        -- Reset counter next frame
        task.defer(function()
            self._orbCount = 0
        end)
        
        return self.originalMethods.spawnOrb(controller, entity, position)
    end
    
    print("[Protection] Methods patched with math.clamp(9e9, 9e9)")
end

function Protection:patchRemotes()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local remotes = ReplicatedStorage:FindFirstChild("remotes")
    if not remotes then 
        print("[Protection] Remotes folder not found")
        return 
    end
    
    -- Block extreme values from remotes
    local remoteNames = {"WindWalkerSpeedUpdate", "SpawnWindWalkerOrb", "WindWalkerEffect"}
    
    for _, remoteName in ipairs(remoteNames) do
        local remote = remotes:FindFirstChild(remoteName)
        if remote and remote:IsA("RemoteEvent") then
            -- Connect to the event instead of overriding it
            remote.OnClientEvent:Connect(function(...)
                local args = {...}
                local safeArgs = {}
                
                -- Check for extreme values and clamp them
                for i, arg in ipairs(args) do
                    if type(arg) == "table" then
                        safeArgs[i] = {}
                        for key, value in pairs(arg) do
                            if type(value) == "number" then
                                -- Clamp with 9e9
                                if math.abs(value) > 9e9 or value ~= value then -- NaN check
                                    local safeValue = math.clamp(value, -9e9, 9e9)
                                    if value ~= safeValue then
                                        print("[Protection] Clamped remote value:", remoteName, key, value, "->", safeValue)
                                    end
                                    safeArgs[i][key] = safeValue
                                else
                                    safeArgs[i][key] = value
                                end
                            else
                                safeArgs[i][key] = value
                            end
                        end
                    else
                        safeArgs[i] = arg
                    end
                end
                
                -- Log safe arguments (we can't modify the original event args)
                print("[Protection] Remote event fired:", remoteName, "with", #safeArgs, "args")
            end)
            print("[Protection] Remote event listener added:", remoteName)
        end
    end
end

function Protection:monitorPerformance()
    -- Monitor for memory issues
    local RunService = game:GetService("RunService")
    
    self._heartbeat = RunService.Heartbeat:Connect(function()
        -- Check memory usage
        local stats = game:GetService("CoreGui"):FindFirstChild("RobloxGui")
        if stats then
            local performance = stats:FindFirstChild("PerformanceStats")
            if performance then
                local memory = performance:FindFirstChild("Memory")
                if memory then
                    local memMB = tonumber(memory.Text:gsub("[^%d.]", "")) or 0
                    
                    -- If memory exceeds 2GB, warn
                    if memMB > 2000 then
                        print("[Protection] High memory usage detected:", memMB, "MB")
                    end
                end
            end
        end
    end)
end

-- Emergency cleanup
function Protection:emergencyCleanup()
    print("[Protection] Emergency cleanup triggered")
    
    -- Clean up orbs
    local workspace = game:GetService("Workspace")
    for _, orb in ipairs(workspace:GetChildren()) do
        if orb.Name == "WindWalkerOrb" then
            orb:Destroy()
        end
    end
    
    -- Clean up beams
    for _, beam in ipairs(workspace:GetDescendants()) do
        if beam:IsA("Beam") and beam.Parent and beam.Parent.Name == "WindWalkerOrb" then
            beam:Destroy()
        end
    end
    
    -- Restore original methods
    if self.controller and self.originalMethods then
        self.controller.updateSpeed = self.originalMethods.updateSpeed
        self.controller.updateJump = self.originalMethods.updateJump
        self.controller.spawnOrb = self.originalMethods.spawnOrb
    end
    
    print("[Protection] Cleanup complete")
end

-- Start protection with retry logic
local function startProtection()
    local protection = Protection.new()  -- Create instance
    
    local attempts = 0
    local maxAttempts = 5
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        print("[Protection] Attempt", attempts, "to initialize...")
        
        local success = protection:init()
        if success then
            print("[Protection] Protection active!")
            _G._windWalkerProtection = protection
            return protection
        end
        
        print("[Protection] Waiting 2 seconds before retry...")
        task.wait(2)
    end
    
    print("[Protection] Failed to initialize after", maxAttempts, "attempts")
    return nil
end

-- Start the protection
task.wait(1)
local protection = startProtection()

-- Bind emergency cleanup to F9
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F9 then
        if protection then
            protection:emergencyCleanup()
        end
    end
end)

print("[Protection] WindWalker crash protection loaded!")
print("[Protection] Press F9 for emergency cleanup")
end)

run(function()
TrapDisabler = vape.Categories.Utility:CreateModule({
	Name = 'TrapDisabler',
	Tooltip = 'Disables Snap Traps'
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

