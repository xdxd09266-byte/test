local isfile = isfile or function(file)
	local suc, res = pcall(function()
		return readfile(file)
	end)
	return suc and res ~= nil and res ~= ''
end
local delfile = delfile or function(file)
	writefile(file, '')
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then
			-- Only wipe and fallback if it's a critical file (not assets)
			if not path:find('assets/') then
				-- Redownload everything except assets (preserve custom assets)
				for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/libraries', 'newvape/guis'} do
					wipeFolder(folder)
					makefolder(folder)
				end
				-- Ensure assets folder exists but don't wipe it
				if not isfolder('newvape/assets') then
					makefolder('newvape/assets')
				end
				local injSuc, injData = pcall(function()
					return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/build/inject_bedwars.lua', true)
				end)
				if injSuc and injData and #injData > 1000 then
					writefile('newvape/inject_bedwars.lua', injData)
					local func = loadstring(injData)
					if func then func() end
					return
				end
				error('Failed to download: ' .. tostring(res))
			end
			-- For assets, just return nil on 404 (don't error)
			return nil
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('owner') then continue end
		if isfile(file) then delfile(file) else wipeFolder(file) end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

-- Download cape from GitHub raw (only if not exists)
if not isfile("newvape/cape/rangiku.png") then
	local capeOk, capeData = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/xdxd09266-byte/test/main/assets/cape.png", true)
	if capeOk and capeData and #capeData > 100 then
		writefile("newvape/cape/rangiku.png", capeData)
	end
end

-- Auto-download configs from GitHub
local configIds = {"6872265039", "6872274481", "8444591321", "8560631822"}
for _, placeId in ipairs(configIds) do
	local configName = "blatant" .. placeId
	local configPath = "newvape/profiles/" .. configName .. ".gui.txt"
	if not isfile(configPath) then
		local suc, res = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/xdxd09266-byte/test/main/profiles/" .. configName .. ".gui.txt", true)
		if suc and res and #res > 10 then
			writefile(configPath, res)
		end
	end
end

-- Write essential profiles (only if not exists)
if not isfile('newvape/profiles/commit.txt') then
	writefile('newvape/profiles/commit.txt', '71f871ed64df5695cef5b6d2e3a94b717eb6c32e')
end
if not isfile('newvape/profiles/gui.txt') then
	writefile('newvape/profiles/gui.txt', 'new')
end
if not isfile('newvape/profiles/metacommit.txt') then
	writefile('newvape/profiles/metacommit.txt', 'a109a0a4441e42d497fa7e3cdc04d770dd853a15')
end

-- Write compiled private game features
writefile("newvape/games/6872274481.lua", [===[local run = function(func)
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

]===])

-- Redirect scripts for sub-places (point to local file instead of GitHub)
local redirectScript = 'loadstring(readfile("newvape/games/6872274481.lua"))()'
writefile("newvape/games/8444591321.lua", redirectScript)
writefile("newvape/games/8560631822.lua", redirectScript)

-- Dynamic Place ID fallback: auto-bind current place ID to game script if in main game
if game.PlaceId == 6872274481 or game.PlaceId == 8444591321 or game.PlaceId == 8560631822 then
	local placeId = tostring(game.PlaceId)
	if not isfile("newvape/games/" .. placeId .. ".lua") then
		writefile("newvape/games/" .. placeId .. ".lua", redirectScript)
	end
end

-- Run authentication and main script
-- Safely get global functions, fallback to stubs if not available
local readfile
local success = pcall(function() readfile = readfile end)
if not success or type(readfile) ~= "function" then
	readfile = function() return "" end
end

local writefile
success = pcall(function() writefile = writefile end)
if not success or type(writefile) ~= "function" then
	writefile = function() end
end

local makefolder
success = pcall(function() makefolder = makefolder end)
if not success or type(makefolder) ~= "function" then
	makefolder = function() end
end

local isfolder
success = pcall(function() isfolder = isfolder end)
if not success or type(isfolder) ~= "function" then
	isfolder = function() return false end
end

local listfiles
success = pcall(function() listfiles = listfiles end)
if not success or type(listfiles) ~= "function" then
	listfiles = function() return {} end
end

local isfile
success = pcall(function() isfile = isfile end)
if not success or type(isfile) ~= "function" then
	isfile = function(file)
		local suc, res = pcall(function()
			return readfile(file)
		end)
		return suc and res ~= nil and res ~= ''
	end
end

local delfile
success = pcall(function() delfile = delfile end)
if not success or type(delfile) ~= "function" then
	delfile = function(file)
		writefile(file, '')
	end
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or type(res) ~= 'string' or res:match('^%d%d%d:') then
			return nil
		end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('owner') then continue end
		if isfile(file) then delfile(file) else wipeFolder(file) end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then
		makefolder(folder)
	end
end

local function ezLog(msg)
	print('[ezvape] ' .. tostring(msg))
	pcall(function()
		local rf = readfile or function() return '' end
		local wf = writefile or function() end
		local old = ''
		pcall(function() old = rf('newvape/debug.log') or '' end)
		if type(old) ~= 'string' then old = '' end
		if #old > 20000 then old = old:sub(-15000) end
		wf('newvape/debug.log', old .. '\n[' .. tostring(os.time()) .. '] ' .. msg)
	end)
end

local function ezError(msg)
	warn('[ezvape Error] ' .. tostring(msg))
	ezLog('[ERROR] ' .. tostring(msg))
end

local function ezSuccess(msg)
	ezLog(msg)
end

local ezStatus = {}
-- ============================================================
-- SECURE SHA-256 KEY AUTH SYSTEM & DISCORD ANALYTICS WEBHOOK
-- ============================================================
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local WEBHOOK_URL = ""
if isfile and isfile('newvape/profiles/secrets_config.lua') then
	local suc, res = pcall(function()
		return HttpService:JSONDecode(readfile('newvape/profiles/secrets_config.lua'))
	end)
	if suc and type(res) == 'table' and res.WEBHOOK_URL then
		WEBHOOK_URL = res.WEBHOOK_URL
	end
end

local function getExecutorName()
	local exec = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or (Krnl and "KRNL") or (Synapse and "Synapse X")
	if type(exec) == "table" then
		return tostring(exec[1] or "Unknown Executor")
	end
	return tostring(exec or "Unknown Executor")
end

local function sendAnalyticsWebhook(matchedKeyInfo, inputKey)
	if WEBHOOK_URL == "" then return end
	pcall(function()
		local reqFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
		if not reqFunc then return end

		local player = Players.LocalPlayer
		local username = player and player.Name or "Unknown Player"
		local userId = player and player.UserId or 0
		local executorName = getExecutorName()
		local placeId = tostring(game.PlaceId)
		local note = (matchedKeyInfo and matchedKeyInfo.note) or "N/A"
		local discordUser = (matchedKeyInfo and matchedKeyInfo.discord) or "N/A"

		local embedData = {
			["title"] = "🚀 ezvape Execution & Key Analytics",
			["color"] = 7506394, -- Discord Blurple
			["fields"] = {
				{ ["name"] = "👤 Roblox Player", ["value"] = username .. " (" .. tostring(userId) .. ")", ["inline"] = true },
				{ ["name"] = "⚡ Executor", ["value"] = executorName, ["inline"] = true },
				{ ["name"] = "🎮 Place ID", ["value"] = placeId, ["inline"] = true },
				{ ["name"] = "🔑 Key Note / User", ["value"] = note, ["inline"] = true },
				{ ["name"] = "💬 Discord Tag", ["value"] = discordUser ~= "" and discordUser or "N/A", ["inline"] = true },
				{ ["name"] = "🔑 Entered Key", ["value"] = "`" .. tostring(inputKey):sub(1, 14) .. "...`", ["inline"] = true }
			},
			["footer"] = { ["text"] = "ezvape Security & Telemetry System" },
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
		}

		local payload = HttpService:JSONEncode({
			["username"] = "ezvape Security Logger",
			["embeds"] = { embedData }
		})

		reqFunc({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload
		})
	end)
end

local function sha256(str)
	local bit = bit32 or bit
	local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
	local rshift, lshift = bit.rshift, bit.lshift
	local rrotate = bit.rrotate or function(w, r)
		return bor(rshift(w, r), lshift(w, 32 - r))
	end

	local K = {
		0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
		0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
		0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
		0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
		0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
		0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
		0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
		0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
	}
	local H = {
		0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
	}

	local bytes = {str:byte(1, #str)}
	local len = #bytes * 8
	table.insert(bytes, 0x80)
	while (#bytes % 64) ~= 56 do
		table.insert(bytes, 0x00)
	end
	for i = 7, 0, -1 do
		table.insert(bytes, band(rshift(len, i * 8), 0xFF))
	end

	local W = {}
	for chunk = 1, #bytes, 64 do
		for i = 0, 15 do
			W[i + 1] = bor(
				lshift(bytes[chunk + i * 4], 24),
				lshift(bytes[chunk + i * 4 + 1], 16),
				lshift(bytes[chunk + i * 4 + 2], 8),
				bytes[chunk + i * 4 + 3]
			)
		end
		for i = 16, 63 do
			local s0 = bxor(rrotate(W[i - 15 + 1], 7), rrotate(W[i - 15 + 1], 18), rshift(W[i - 15 + 1], 3))
			local s1 = bxor(rrotate(W[i - 2 + 1], 17), rrotate(W[i - 2 + 1], 19), rshift(W[i - 2 + 1], 10))
			W[i + 1] = band(W[i - 16 + 1] + s0 + W[i - 7 + 1] + s1, 0xFFFFFFFF)
		end

		local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
		for i = 0, 63 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = band(h + S1 + ch + K[i + 1] + W[i + 1], 0xFFFFFFFF)
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = band(S0 + maj, 0xFFFFFFFF)

			h = g
			g = f
			f = e
			e = band(d + temp1, 0xFFFFFFFF)
			d = c
			c = b
			b = a
			a = band(temp1 + temp2, 0xFFFFFFFF)
		end

		H[1] = band(H[1] + a, 0xFFFFFFFF)
		H[2] = band(H[2] + b, 0xFFFFFFFF)
		H[3] = band(H[3] + c, 0xFFFFFFFF)
		H[4] = band(H[4] + d, 0xFFFFFFFF)
		H[5] = band(H[5] + e, 0xFFFFFFFF)
		H[6] = band(H[6] + f, 0xFFFFFFFF)
		H[7] = band(H[7] + g, 0xFFFFFFFF)
		H[8] = band(H[8] + h, 0xFFFFFFFF)
	end

	return string.format("%08x%08x%08x%08x%08x%08x%08x%08x", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8])
end

local function fetchKeys()
	if isfile and isfile('newvape/keys.json') then
		local localSuc, localData = pcall(function()
			return HttpService:JSONDecode(readfile('newvape/keys.json'))
		end)
		if localSuc and localData and localData.keys then
			return localData.keys
		end
	end
	local suc, res = pcall(function()
		return game:HttpGet('https://raw.githubusercontent.com/xdxd09266-byte/test/main/keys.json?t='..tostring(os.time()), true)
	end)
	if suc and res and not res:match('^%d%d%d:') then
		local jsonSuc, data = pcall(function()
			return HttpService:JSONDecode(res)
		end)
		if jsonSuc and data and data.keys then
			return data.keys
		end
	end
	return nil
end

local function validateKey(enteredKey, keyList)
	if not enteredKey or enteredKey == "" or not keyList then return false, "Invalid parameters", nil end
	local inputHash = sha256(enteredKey)
	local currentTime = os.time()
	for _, k in ipairs(keyList) do
		if k.hash == inputHash or k.key == enteredKey then
			if k.active == false then
				return false, "Key has been revoked!", k
			end
			if k.expires and tonumber(k.expires) and currentTime > tonumber(k.expires) then
				return false, "Key has expired!", k
			end
			return true, "Success", k
		end
	end
	return false, "Invalid Key", nil
end

local function authenticateUser()
	local keyList = fetchKeys()
	if not keyList then
		print("[ezvape Auth] Warning: Unable to fetch key database.")
	end

	local savedKey = isfile("newvape/profiles/key.txt") and readfile("newvape/profiles/key.txt"):gsub("%s+", "") or ""

	if savedKey ~= "" and keyList then
		local valid, msg, keyInfo = validateKey(savedKey, keyList)
		if valid then
			print("[ezvape Auth] Key verified automatically!")
			task.spawn(function()
				sendAnalyticsWebhook(keyInfo, savedKey)
			end)
			return true
		else
			print("[ezvape Auth] Saved key invalid: " .. tostring(msg))
		end
	end

	-- Load Rayfield Gen2 UI library
	local preRayfieldGuis = {}
	pcall(function()
		for _, child in ipairs(game:GetService('CoreGui'):GetChildren()) do
			preRayfieldGuis[child] = true
		end
		local player = game:GetService('Players').LocalPlayer
		if player then
			local playerGui = player:FindFirstChild('PlayerGui')
			if playerGui then
				for _, child in ipairs(playerGui:GetChildren()) do
					preRayfieldGuis[child] = true
				end
			end
		end
	end)
	local RayfieldSuc, Rayfield = pcall(function()
		return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
	end)
	if not RayfieldSuc or not Rayfield then
		error("Failed to load Rayfield Gen2 UI library. Check your internet connection.")
	end
	
	-- Detect mobile and use simpler approach if needed
	local isMobile = game:GetService("UserInputService").TouchEnabled
	
	local Window
	local WindowSuc, WindowErr = pcall(function()
		return Rayfield:CreateWindow({
			name = "ezvape Authentication",
			subtitle = "by xdxd09266-byte"
		})
	end)
	
	if not WindowSuc then
		-- Fallback for mobile or if Rayfield window creation fails
		warn("[ezvape] Rayfield window creation failed: " .. tostring(WindowErr))
		if isMobile then
			warn("[ezvape] Mobile detected - using simple input fallback")
			-- Simple fallback: prompt user via console or simple GUI

			
			local key = ""
			-- Use a simple InputBox if available, otherwise use console
			local screenGui = Instance.new("ScreenGui")
			screenGui.Parent = game:GetService("CoreGui")
			
			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0.5, 0, 0.3, 0)
			frame.Position = UDim2.new(0.25, 0, 0.35, 0)
			frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			frame.Parent = screenGui
			
			local textBox = Instance.new("TextBox")
		 textBox.Size = UDim2.new(0.8, 0, 0.3, 0)
			textBox.Position = UDim2.new(0.1, 0, 0.2, 0)
			textBox.PlaceholderText = "Enter your key"
			textBox.Text = ""
			textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
			textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
			textBox.Parent = frame
			
			local submitButton = Instance.new("TextButton")
			submitButton.Size = UDim2.new(0.4, 0, 0.2, 0)
			submitButton.Position = UDim2.new(0.3, 0, 0.6, 0)
			submitButton.Text = "Submit"
			submitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
			submitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			submitButton.Parent = frame
			
			local statusLabel = Instance.new("TextLabel")
			statusLabel.Size = UDim2.new(0.8, 0, 0.2, 0)
			statusLabel.Position = UDim2.new(0.1, 0, 0.8, 0)
			statusLabel.Text = "Enter your key to continue"
			statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Parent = frame
			
			local authenticated = false
			
			submitButton.MouseButton1Click:Connect(function()
				key = textBox.Text:gsub("%s+", "")
				statusLabel.Text = "Verifying..."
				
				keyList = fetchKeys() or keyList
				local valid, msg, keyInfo = validateKey(key, keyList)
				
				if valid then
					statusLabel.Text = "✅ Success!"
					writefile("newvape/profiles/key.txt", key)
					
					task.spawn(function()
						sendAnalyticsWebhook(keyInfo, key)
					end)
					
					task.wait(0.5)
					screenGui:Destroy()
					authenticated = true
				else
					statusLabel.Text = "❌ " .. tostring(msg)
				end
			end)
			
			repeat task.wait() until authenticated
			return authenticated
		else
			error("Rayfield window creation failed: " .. tostring(WindowErr))
		end
	end
	
	Window = WindowErr

	local authenticated = false
	local currentKeyInput = savedKey or ""

	local Tab = Window:CreateTab({
		name = "Authentication"
	})

	local keyInput = Tab:CreateInput({
		name = "Enter Key",
		value = savedKey ~= "" and savedKey or "",
		placeholder = "ezvape-XXXX-XXXX-XXXX",
		flag = "ezvape_key_input",
		callback = function(Text)
			currentKeyInput = Text:gsub("%s+", "")
		end
	})

	local function verify()
		local keyToVerify = currentKeyInput
		if keyToVerify == "" then
			keyToVerify = savedKey
		end

		if not keyToVerify or keyToVerify == "" then
			Window:Notify({
				title = "Error",
				content = "❌ Please enter your key!",
				duration = 3
			})
			return
		end
        
		Window:Notify({
			title = "Verifying",
			content = "⏳ Verifying...",
			duration = 2
		})
		
		keyList = fetchKeys() or keyList
		local valid, msg, keyInfo = validateKey(keyToVerify, keyList)
		
		if valid then
			Window:Notify({
				title = "Success",
				content = "✅ Access Granted! Loading...",
				duration = 2
			})
			writefile("newvape/profiles/key.txt", keyToVerify)
			
			task.spawn(function()
				sendAnalyticsWebhook(keyInfo, keyToVerify)
			end)
			
			task.wait(0.5)
			print('[ezvape] auth: verified, unloading window')
			pcall(function() Window:Unload() end)
			print('[ezvape] auth: window unloaded')
			pcall(function()
				local destroyed = 0
				local function cleanGuis(parent)
					if not parent then return end
					for _, child in ipairs(parent:GetChildren()) do
						if child:IsA('ScreenGui') and child.Name:lower():find('rayfield') and not preRayfieldGuis[child] then
							child:Destroy()
							destroyed = destroyed + 1
						end
					end
				end
				cleanGuis(game:GetService('CoreGui'))
				local player = game:GetService('Players').LocalPlayer
				if player then
					cleanGuis(player:FindFirstChild('PlayerGui'))
				end
				print('[ezvape] rayfield cleanup: destroyed ' .. tostring(destroyed) .. ' leftover screen guis')
			end)
			authenticated = true
		else
			Window:Notify({
				title = "Error",
				content = "❌ " .. tostring(msg),
				duration = 5
			})
		end
	end

	Tab:CreateButton({
		name = "Verify & Unlock",
		callback = verify
	})

	Tab:CreateButton({
		name = "Reset Key",
		callback = function()
			if isfile("newvape/profiles/key.txt") then
				delfile("newvape/profiles/key.txt")
			end
			savedKey = ""
			currentKeyInput = ""
			keyInput:Set("", true)
			Window:Notify({
				title = "Success",
				content = "✅ Key cleared! Please enter a new key.",
				duration = 3
			})
		end
	})

	repeat task.wait() until authenticated
	return authenticated
end

-- Run key authentication check
print('[ezvape] running authentication...')
local authSuccess = authenticateUser()
print('[ezvape] authenticateUser returned: ' .. tostring(authSuccess))
if not authSuccess then
	ezError('[ezvape Auth] Authentication failed.')
	return
end

-- Proceed with standard loading
if not shared.VapeDeveloper and not isfile('newvape/profiles/local.txt') then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/xdxd09266-byte/test')
	end)
	local commit = nil
	if type(subbed) == 'string' and not subbed:match('^%d%d%d:') then
		local idx = subbed:find('currentOid')
		if idx then
			local candidate = subbed:sub(idx + 13, idx + 52)
			if #candidate == 40 then commit = candidate end
		end
	end
	-- Only wipe when the repo is actually reachable (private/offline repos return 403/404 -> no wipe)
	if commit and commit ~= (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
		-- Preserve assets folder - don't wipe it
		if not isfolder('newvape/assets') then
			makefolder('newvape/assets')
		end
	end
	if commit then
		writefile('newvape/profiles/commit.txt', commit)
	end
end

-- Safely download and execute main.lua
ezLog('inject: auth passed, downloading main.lua')
local mainScriptSource = downloadFile('newvape/main.lua')

if mainScriptSource then
	local mainFunc, err = loadstring(mainScriptSource, "main")
	if type(mainFunc) == "function" then
		ezLog('inject: main.lua compiled, executing')
		local success, runtimeErr = pcall(mainFunc)
		if not success then
			ezError('main.lua crashed:\n' .. tostring(runtimeErr))
		else
			ezLog('inject: main.lua finished without error')
			ezSuccess('ezvape finished loading.\nIf no menu appeared: press the button in the TOP RIGHT (mobile) or RightShift (PC).\nIf a red error panel appeared earlier, screenshot it.')
		end
	else
		ezError('Syntax error in main.lua:\n' .. tostring(err))
	end
else
	ezError('Failed to download newvape/main.lua (network blocked?)')
end
