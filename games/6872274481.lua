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

