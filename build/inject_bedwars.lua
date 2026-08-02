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
local AimAssist
local Targets
local Sort
local AimSpeed
local Distance
local AngleSlider
local StrafeIncrease
local KillauraTarget
local ClickAim

AimAssist = vape.Categories.Combat:CreateModule({
	Name = 'AimAssist',
	Function = function(callback)
		if callback then
			AimAssist:Clean(runService.Heartbeat:Connect(function(dt)
				if entitylib.isAlive and store.hand.toolType == 'sword' and ((not ClickAim.Enabled) or (tick() - bedwars.SwordController.lastSwing) < 0.4) then
					local ent = not KillauraTarget.Enabled and entitylib.EntityPosition({
						Range = Distance.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Sort = sortmethods[Sort.Value]
					}) or store.KillauraTarget

					if ent then
						local delta = (ent.RootPart.Position - entitylib.character.RootPart.Position)
						local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
						local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
						if angle >= (math.rad(AngleSlider.Value) / 2) then return end
						targetinfo.Targets[ent] = tick() + 1
						gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.p, ent.RootPart.Position), (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) * dt)
					end
				end
			end))
		end
	end,
	Tooltip = 'Smoothly aims to closest valid target with sword'
})
Targets = AimAssist:CreateTargets({
	Players = true,
	Walls = true
})
local methods = {'Damage', 'Distance'}
for i in sortmethods do
	if not table.find(methods, i) then
		table.insert(methods, i)
	end
end
Sort = AimAssist:CreateDropdown({
	Name = 'Target Mode',
	List = methods
})
AimSpeed = AimAssist:CreateSlider({
	Name = 'Aim Speed',
	Min = 1,
	Max = 20,
	Default = 6
})
Distance = AimAssist:CreateSlider({
	Name = 'Distance',
	Min = 1,
	Max = 30,
	Default = 30,
	Suffx = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
AngleSlider = AimAssist:CreateSlider({
	Name = 'Max angle',
	Min = 1,
	Max = 360,
	Default = 70
})
ClickAim = AimAssist:CreateToggle({
	Name = 'Click Aim',
	Default = true
})
KillauraTarget = AimAssist:CreateToggle({
	Name = 'Use killaura target'
})
StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
end)

run(function()
local AutoClicker
local CPS
local BlockCPS = {}
local Thread

local function AutoClick()
	if Thread then
		task.cancel(Thread)
	end

	Thread = task.delay(1 / 7, function()
		repeat
			if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
				local blockPlacer = bedwars.BlockPlacementController.blockPlacer
				if store.hand.toolType == 'block' and blockPlacer then
					if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
						local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
						if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
							task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
						end
					end
				elseif store.hand.toolType == 'sword' then
					bedwars.SwordController:swingSwordAtMouse()
				end
			end

			task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
		until not AutoClicker.Enabled
	end)
end

AutoClicker = vape.Categories.Combat:CreateModule({
	Name = 'AutoClicker',
	Function = function(callback)
		if callback then
			AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					AutoClick()
				end
			end))

			AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end))

			if inputService.TouchEnabled then
				pcall(function()
					AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
					AutoClicker:Clean(lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
						if Thread then
							task.cancel(Thread)
							Thread = nil
						end
					end))
				end)
			end
		else
			if Thread then
				task.cancel(Thread)
				Thread = nil
			end
		end
	end,
	Tooltip = 'Hold attack button to automatically click'
})
CPS = AutoClicker:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 9,
	DefaultMin = 7,
	DefaultMax = 7
})
AutoClicker:CreateToggle({
	Name = 'Place Blocks',
	Default = true,
	Function = function(callback)
		if BlockCPS.Object then
			BlockCPS.Object.Visible = callback
		end
	end
})
BlockCPS = AutoClicker:CreateTwoSlider({
	Name = 'Block CPS',
	Min = 1,
	Max = 12,
	DefaultMin = 12,
	DefaultMax = 12,
	Darker = true
})
end)

run(function()
local old

vape.Categories.Combat:CreateModule({
	Name = 'NoClickDelay',
	Function = function(callback)
		if callback then
			old = bedwars.SwordController.isClickingTooFast
			bedwars.SwordController.isClickingTooFast = function(self)
				self.lastSwing = os.clock()
				return false
			end
		else
			bedwars.SwordController.isClickingTooFast = old
		end
	end,
	Tooltip = 'Remove the CPS cap'
})
end)

run(function()
local Value

Reach = vape.Categories.Combat:CreateModule({
	Name = 'Reach',
	Function = function(callback)
		bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and Value.Value + 2 or 14.4
	end,
	Tooltip = 'Extends attack reach'
})
Value = Reach:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 18,
	Default = 18,
	Function = function(val)
		if Reach.Enabled then
			bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = val + 2
		end
	end,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)

run(function()
local Sprint
local old

Sprint = vape.Categories.Combat:CreateModule({
	Name = 'Sprint',
	Function = function(callback)
		if callback then
			if inputService.TouchEnabled then 
				pcall(function() 
					lplr.PlayerGui.MobileUI['4'].Visible = false 
				end) 
			end
			old = bedwars.SprintController.stopSprinting
			bedwars.SprintController.stopSprinting = function(...)
				local call = old(...)
				bedwars.SprintController:startSprinting()
				return call
			end
			Sprint:Clean(entitylib.Events.LocalAdded:Connect(function() 
				task.delay(0.1, function() 
					bedwars.SprintController:stopSprinting() 
				end) 
			end))
			bedwars.SprintController:stopSprinting()
		else
			if inputService.TouchEnabled then 
				pcall(function() 
					lplr.PlayerGui.MobileUI['4'].Visible = true 
				end) 
			end
			bedwars.SprintController.stopSprinting = old
			bedwars.SprintController:stopSprinting()
		end
	end,
	Tooltip = 'Sets your sprinting to true.'
})
end)

run(function()
local TriggerBot
local CPS
local rayParams = RaycastParams.new()

TriggerBot = vape.Categories.Combat:CreateModule({
	Name = 'TriggerBot',
	Function = function(callback)
		if callback then
			repeat
				local doAttack
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					if entitylib.isAlive and store.hand.toolType == 'sword' and bedwars.DaoController.chargingMaid == nil then
						local attackRange = bedwars.ItemMeta[store.hand.tool.Name].sword.attackRange
						rayParams.FilterDescendantsInstances = {lplr.Character}

						local unit = lplr:GetMouse().UnitRay
						local localPos = entitylib.character.RootPart.Position
						local rayRange = (attackRange or 14.4)
						local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
						if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
							local limit = (attackRange)
							for _, ent in entitylib.List do
								doAttack = ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (localPos - ent.RootPart.Position).Magnitude <= rayRange
								if doAttack then
									break
								end
							end
						end

						doAttack = doAttack or bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
						if doAttack then
							bedwars.SwordController:swingSwordAtMouse()
						end
					end
				end

				task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
			until not TriggerBot.Enabled
		end
	end,
	Tooltip = 'Automatically swings when hovering over a entity'
})
CPS = TriggerBot:CreateTwoSlider({
	Name = 'CPS',
	Min = 1,
	Max = 9,
	DefaultMin = 7,
	DefaultMax = 7
})
end)

run(function()
local Velocity
local Horizontal
local Vertical
local Chance
local TargetCheck
local rand, old = Random.new()

Velocity = vape.Categories.Combat:CreateModule({
	Name = 'Velocity',
	Function = function(callback)
		if callback then
			old = bedwars.KnockbackUtil.applyKnockback
			bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
				if rand:NextNumber(0, 100) > Chance.Value then return end
				local check = (not TargetCheck.Enabled) or entitylib.EntityPosition({
					Range = 50,
					Part = 'RootPart',
					Players = true
				})

				if check then
					knockback = knockback or {}
					if Horizontal.Value == 0 and Vertical.Value == 0 then return end
					knockback.horizontal = (knockback.horizontal or 1) * (Horizontal.Value / 100)
					knockback.vertical = (knockback.vertical or 1) * (Vertical.Value / 100)
				end
				
				return old(root, mass, dir, knockback, ...)
			end
		else
			bedwars.KnockbackUtil.applyKnockback = old
		end
	end,
	Tooltip = 'Reduces knockback taken'
})
Horizontal = Velocity:CreateSlider({
	Name = 'Horizontal',
	Min = 0,
	Max = 100,
	Default = 0,
	Suffix = '%'
})
Vertical = Velocity:CreateSlider({
	Name = 'Vertical',
	Min = 0,
	Max = 100,
	Default = 0,
	Suffix = '%'
})
Chance = Velocity:CreateSlider({
	Name = 'Chance',
	Min = 0,
	Max = 100,
	Default = 100,
	Suffix = '%'
})
TargetCheck = Velocity:CreateToggle({Name = 'Only when targeting'})
end)

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
local BedESP
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local function Added(bed)
	if not BedESP.Enabled then return end
	local BedFolder = Instance.new('Folder')
	BedFolder.Parent = Folder
	Reference[bed] = BedFolder
	local parts = bed:GetChildren()
	table.sort(parts, function(a, b)
		return a.Name > b.Name
	end)

	for _, part in parts do
		if part:IsA('BasePart') and part.Name ~= 'Blanket' then
			local handle = Instance.new('BoxHandleAdornment')
			handle.Size = part.Size + Vector3.new(.01, .01, .01)
			handle.AlwaysOnTop = true
			handle.ZIndex = 2
			handle.Visible = true
			handle.Adornee = part
			handle.Color3 = part.Color
			if part.Name == 'Legs' then
				handle.Color3 = Color3.fromRGB(167, 112, 64)
				handle.Size = part.Size + Vector3.new(.01, -1, .01)
				handle.CFrame = CFrame.new(0, -0.4, 0)
				handle.ZIndex = 0
			end
			handle.Parent = BedFolder
		end
	end

	table.clear(parts)
end

BedESP = vape.Categories.Render:CreateModule({
	Name = 'BedESP',
	Function = function(callback)
		if callback then
			BedESP:Clean(collectionService:GetInstanceAddedSignal('bed'):Connect(function(bed)
				task.delay(0.2, Added, bed)
			end))
			BedESP:Clean(collectionService:GetInstanceRemovedSignal('bed'):Connect(function(bed)
				if Reference[bed] then
					Reference[bed]:Destroy()
					Reference[bed] = nil
				end
			end))
			for _, bed in collectionService:GetTagged('bed') do
				Added(bed)
			end
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'Render Beds through walls'
})
end)

run(function()
local Health

Health = vape.Categories.Render:CreateModule({
	Name = 'Health',
	Function = function(callback)
		if callback then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(100, 20)
			label.Position = UDim2.new(0.5, 6, 0.5, 30)
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
			label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
			label.TextSize = 18
			label.Font = Enum.Font.Arial
			label.Parent = vape.gui
			Health:Clean(label)
			Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
				label.Text = entitylib.isAlive and math.round(lplr.Character:GetAttribute('Health'))..' ❤️' or ''
				label.TextColor3 = entitylib.isAlive and Color3.fromHSV((lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) / 2.8, 0.86, 1) or Color3.new()
			end))
		end
	end,
	Tooltip = 'Displays your health in the center of your screen.'
})
end)

run(function()
local KitESP
local Background
local Color = {}
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local ESPKits = {
	alchemist = {'alchemist_ingedients', 'wild_flower'},
	beekeeper = {'bee', 'bee'},
	bigman = {'treeOrb', 'natures_essence_1'},
	ghost_catcher = {'ghost', 'ghost_orb'},
	metal_detector = {'hidden-metal', 'iron'},
	sheep_herder = {'SheepModel', 'purple_hay_bale'},
	sorcerer = {'alchemy_crystal', 'wild_flower'},
	star_collector = {'stars', 'crit_star'}
}

local function Added(v, icon)
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = icon
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.AlwaysOnTop = true
	billboard.ClipsDescendants = false
	billboard.Adornee = v
	local blur = addBlur(billboard)
	blur.Visible = Background.Enabled
	local image = Instance.new('ImageLabel')
	image.Size = UDim2.fromOffset(36, 36)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	image.BorderSizePixel = 0
	image.Image = bedwars.getIcon({itemType = icon}, true)
	image.Parent = billboard
	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 4)
	uicorner.Parent = image
	Reference[v] = billboard
end

local function addKit(tag, icon)
	KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
		Added(v.PrimaryPart, icon)
	end))
	KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
		if Reference[v.PrimaryPart] then
			Reference[v.PrimaryPart]:Destroy()
			Reference[v.PrimaryPart] = nil
		end
	end))
	for _, v in collectionService:GetTagged(tag) do
		Added(v.PrimaryPart, icon)
	end
end

KitESP = vape.Categories.Render:CreateModule({
	Name = 'KitESP',
	Function = function(callback)
		if callback then
			repeat task.wait() until store.equippedKit ~= '' or (not KitESP.Enabled)
			local kit = KitESP.Enabled and ESPKits[store.equippedKit] or nil
			if kit then
				addKit(kit[1], kit[2])
			end
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'ESP for certain kit related objects'
})
Background = KitESP:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color.Object then Color.Object.Visible = callback end
		for _, v in Reference do
			v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true
})
Color = KitESP:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.ImageLabel.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true
})
end)

run(function()
local NameTags
local Targets
local Color
local Background
local DisplayName
local Health
local Distance
local Equipment
local DrawingToggle
local Scale
local FontOption
local Teammates
local DistanceCheck
local DistanceLimit
local Strings, Sizes, Reference = {}, {}, {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui
local methodused

local Added = {
	Normal = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

		local nametag = Instance.new('TextLabel')
		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

		if Health.Enabled then
			local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
			Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
		end

		if Distance.Enabled then
			Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
		end

		if Equipment.Enabled then
			for i, v in {'Hand', 'Helmet', 'Chestplate', 'Boots', 'Kit'} do
				local Icon = Instance.new('ImageLabel')
				Icon.Name = v
				Icon.Size = UDim2.fromOffset(30, 30)
				Icon.Position = UDim2.fromOffset(-60 + (i * 30), -30)
				Icon.BackgroundTransparency = 1
				Icon.Image = ''
				Icon.Parent = nametag
			end
		end

		nametag.TextSize = 14 * Scale.Value
		nametag.FontFace = FontOption.Value
		local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
		nametag.Name = ent.Player and ent.Player.Name or ent.Character.Name
		nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
		nametag.AnchorPoint = Vector2.new(0.5, 1)
		nametag.BackgroundColor3 = Color3.new()
		nametag.BackgroundTransparency = Background.Value
		nametag.BorderSizePixel = 0
		nametag.Visible = false
		nametag.Text = Strings[ent]
		nametag.TextColor3 = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.RichText = true
		nametag.Parent = Folder
		Reference[ent] = nametag
	end,
	Drawing = function(ent)
		if not Targets.Players.Enabled and ent.Player then return end
		if not Targets.NPCs.Enabled and ent.NPC then return end
		if Teammates.Enabled and (not ent.Targetable) and (not ent.Friend) then return end

		local nametag = {}
		nametag.BG = Drawing.new('Square')
		nametag.BG.Filled = true
		nametag.BG.Transparency = 1 - Background.Value
		nametag.BG.Color = Color3.new()
		nametag.BG.ZIndex = 1
		nametag.Text = Drawing.new('Text')
		nametag.Text.Size = 15 * Scale.Value
		nametag.Text.Font = 0
		nametag.Text.ZIndex = 2
		Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

		if Health.Enabled then
			Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
		end

		if Distance.Enabled then
			Strings[ent] = '[%s] '..Strings[ent]
		end

		nametag.Text.Text = Strings[ent]
		nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
		Reference[ent] = nametag
	end
}

local Removed = {
	Normal = function(ent)
		local v = Reference[ent]
		if v then
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			v:Destroy()
		end
	end,
	Drawing = function(ent)
		local v = Reference[ent]
		if v then
			Reference[ent] = nil
			Strings[ent] = nil
			Sizes[ent] = nil
			for _, obj in v do
				pcall(function()
					obj.Visible = false
					obj:Remove()
				end)
			end
		end
	end
}

local Updated = {
	Normal = function(ent)
		local nametag = Reference[ent]
		if nametag then
			Sizes[ent] = nil
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

			if Health.Enabled then
				local healthColor = Color3.fromHSV(math.clamp(ent.Health / ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
				Strings[ent] = Strings[ent]..' <font color="rgb('..tostring(math.floor(healthColor.R * 255))..','..tostring(math.floor(healthColor.G * 255))..','..tostring(math.floor(healthColor.B * 255))..')">'..math.round(ent.Health)..'</font>'
			end

			if Distance.Enabled then
				Strings[ent] = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> '..Strings[ent]
			end

			if Equipment.Enabled and store.inventories[ent.Player] then
				local kit = ent.Player:GetAttribute('PlayingAsKit')
				local inventory = store.inventories[ent.Player]
				nametag.Hand.Image = bedwars.getIcon(inventory.hand or {itemType = ''}, true)
				nametag.Helmet.Image = bedwars.getIcon(inventory.armor[4] or {itemType = ''}, true)
				nametag.Chestplate.Image = bedwars.getIcon(inventory.armor[5] or {itemType = ''}, true)
				nametag.Boots.Image = bedwars.getIcon(inventory.armor[6] or {itemType = ''}, true)
				nametag.Kit.Image = kit and kit ~= 'none' and bedwars.BedwarsKitMeta[kit].renderImage or ''
			end

			local size = getfontsize(removeTags(Strings[ent]), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
			nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
			nametag.Text = Strings[ent]
		end
	end,
	Drawing = function(ent)
		local nametag = Reference[ent]
		if nametag then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Sizes[ent] = nil
			Strings[ent] = ent.Player and whitelist:tag(ent.Player, true)..(DisplayName.Enabled and ent.Player.DisplayName or ent.Player.Name) or ent.Character.Name

			if Health.Enabled then
				Strings[ent] = Strings[ent]..' '..math.round(ent.Health)
			end

			if Distance.Enabled then
				Strings[ent] = '[%s] '..Strings[ent]
				nametag.Text.Text = entitylib.isAlive and string.format(Strings[ent], math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)) or Strings[ent]
			else
				nametag.Text.Text = Strings[ent]
			end

			nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
			nametag.Text.Color = entitylib.getEntityColor(ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		end
	end
}

local ColorFunc = {
	Normal = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.TextColor3 = entitylib.getEntityColor(i) or color
		end
	end,
	Drawing = function(hue, sat, val)
		local color = Color3.fromHSV(hue, sat, val)
		for i, v in Reference do
			v.Text.Color = entitylib.getEntityColor(i) or color
		end
	end
}

local Loop = {
	Normal = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
				if Sizes[ent] ~= mag then
					nametag.Text = string.format(Strings[ent], mag)
					local ize = getfontsize(removeTags(nametag.Text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(ize.X + 8, ize.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
		end
	end,
	Drawing = function()
		for ent, nametag in Reference do
			if DistanceCheck.Enabled then
				local distance = entitylib.isAlive and (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude or math.huge
				if distance < DistanceLimit.ValueMin or distance > DistanceLimit.ValueMax then
					nametag.Text.Visible = false
					nametag.BG.Visible = false
					continue
				end
			end

			local headPos, headVis = gameCamera:WorldToViewportPoint(ent.RootPart.Position + Vector3.new(0, ent.HipHeight + 1, 0))
			nametag.Text.Visible = headVis
			nametag.BG.Visible = headVis
			if not headVis then
				continue
			end

			if Distance.Enabled then
				local mag = entitylib.isAlive and math.floor((entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude) or 0
				if Sizes[ent] ~= mag then
					nametag.Text.Text = string.format(Strings[ent], mag)
					nametag.BG.Size = Vector2.new(nametag.Text.TextBounds.X + 8, nametag.Text.TextBounds.Y + 7)
					Sizes[ent] = mag
				end
			end
			nametag.BG.Position = Vector2.new(headPos.X - (nametag.BG.Size.X / 2), headPos.Y - nametag.BG.Size.Y)
			nametag.Text.Position = nametag.BG.Position + Vector2.new(4, 3)
		end
	end
}

NameTags = vape.Categories.Render:CreateModule({
	Name = 'NameTags',
	Function = function(callback)
		if callback then
			methodused = DrawingToggle.Enabled and 'Drawing' or 'Normal'
			if Removed[methodused] then
				NameTags:Clean(entitylib.Events.EntityRemoved:Connect(Removed[methodused]))
			end
			if Added[methodused] then
				for _, v in entitylib.List do
					if Reference[v] then
						Removed[methodused](v)
					end
					Added[methodused](v)
				end
				NameTags:Clean(entitylib.Events.EntityAdded:Connect(function(ent)
					if Reference[ent] then
						Removed[methodused](ent)
					end
					Added[methodused](ent)
				end))
			end
			if Updated[methodused] then
				NameTags:Clean(entitylib.Events.EntityUpdated:Connect(Updated[methodused]))
				for _, v in entitylib.List do
					Updated[methodused](v)
				end
			end
			if ColorFunc[methodused] then
				NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[methodused](Color.Hue, Color.Sat, Color.Value)
				end))
			end
			if Loop[methodused] then
				NameTags:Clean(runService.RenderStepped:Connect(Loop[methodused]))
			end
		else
			if Removed[methodused] then
				for i in Reference do
					Removed[methodused](i)
				end
			end
		end
	end,
	Tooltip = 'Renders nametags on entities through walls.'
})
Targets = NameTags:CreateTargets({
	Players = true,
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
FontOption = NameTags:CreateFont({
	Name = 'Font',
	Blacklist = 'Arial',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
Color = NameTags:CreateColorSlider({
	Name = 'Player Color',
	Function = function(hue, sat, val)
		if NameTags.Enabled and ColorFunc[methodused] then
			ColorFunc[methodused](hue, sat, val)
		end
	end
})
Scale = NameTags:CreateSlider({
	Name = 'Scale',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 1,
	Min = 0.1,
	Max = 1.5,
	Decimal = 10
})
Background = NameTags:CreateSlider({
	Name = 'Transparency',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = 0.5,
	Min = 0,
	Max = 1,
	Decimal = 10
})
Health = NameTags:CreateToggle({
	Name = 'Health',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
Distance = NameTags:CreateToggle({
	Name = 'Distance',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
Equipment = NameTags:CreateToggle({
	Name = 'Equipment',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end
})
DisplayName = NameTags:CreateToggle({
	Name = 'Use Displayname',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true
})
Teammates = NameTags:CreateToggle({
	Name = 'Priority Only',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
	Default = true
})
DrawingToggle = NameTags:CreateToggle({
	Name = 'Drawing',
	Function = function()
		if NameTags.Enabled then
			NameTags:Toggle()
			NameTags:Toggle()
		end
	end,
})
DistanceCheck = NameTags:CreateToggle({
	Name = 'Distance Check',
	Function = function(callback)
		DistanceLimit.Object.Visible = callback
	end
})
DistanceLimit = NameTags:CreateTwoSlider({
	Name = 'Player Distance',
	Min = 0,
	Max = 256,
	DefaultMin = 0,
	DefaultMax = 64,
	Darker = true,
	Visible = false
})
end)

run(function()
run(function()
	local TweenService = game:GetService("TweenService")
	local UserInputService = game:GetService("UserInputService")

	local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	
	local Settings = {
		Width = 170,
		Height = 34,
		ExpandedWidth = 270,
		YPos = 12,
		Colors = {
			Background = Color3.fromRGB(0, 0, 0),
			Stroke = Color3.fromRGB(40, 40, 40),
			Success = Color3.fromRGB(48, 209, 88), -- Permanent Apple Green
			Error = Color3.fromRGB(255, 69, 58)    -- Permanent Apple Red
		}
	}

	local ActiveNotifs = {}
	
	-- Snappy 1:1 Apple Easing
	local function AppleTween(inst, props, dur)
		local info = TweenInfo.new(dur or 0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		local t = TweenService:Create(inst, info, props)
		t:Play()
		return t
	end

	local GUI = Instance.new("ScreenGui")
	GUI.Name = "DynamicIsland"; GUI.ResetOnSpawn = false; GUI.IgnoreGuiInset = true
	GUI.Parent = lplr:WaitForChild("PlayerGui")

	-- Main Container (CanvasGroup for perfect fading)
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

	local List = Instance.new("UIListLayout")
	List.Parent = NotifLayer; List.Padding = UDim.new(0, 6); List.HorizontalAlignment = Enum.HorizontalAlignment.Center; List.VerticalAlignment = Enum.VerticalAlignment.Center
	List.SortOrder = Enum.SortOrder.LayoutOrder

	local function UpdateIsland()
		local count = #ActiveNotifs
		
		if count > 0 then
			CompactLayer.Visible = false
			NotifLayer.Visible = true
			
			-- Snappy Expansion Animation
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.ExpandedWidth, 0, 38 + (count * 10)),
				Position = UDim2.new(0.5, -Settings.ExpandedWidth/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 22)})
		else
			NotifLayer.Visible = false
			AppleTween(Island, {
				Size = UDim2.new(0, Settings.Width, 0, Settings.Height),
				Position = UDim2.new(0.5, -Settings.Width/2, 0, Settings.YPos)
			})
			AppleTween(Corner, {CornerRadius = UDim.new(0, 100)})
			
			task.delay(0.3, function()
				if #ActiveNotifs == 0 then CompactLayer.Visible = true end
			end)
		end
	end

	function ShowNotif(text, isEnabled)
		-- Create the item
		local item = Instance.new("Frame")
		item.Size = UDim2.new(0.9, 0, 0, 24)
		item.BackgroundTransparency = 1
		item.Parent = NotifLayer

		-- Determine Permanent Color
		local statusColor = isEnabled and Settings.Colors.Success or Settings.Colors.Error
		local colorHex = isEnabled and "#30D158" or "#FF453A"
-- Permanent Status Dot
local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 6, 0, 6); dot.Position = UDim2.new(0, 4, 0.5, -3)
dot.BackgroundColor3 = statusColor
dot.BorderSizePixel = 0; dot.Parent = item
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local lockConn
lockConn = dot:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
	if dot.BackgroundColor3 ~= statusColor then
		dot.BackgroundColor3 = statusColor
	end
end)
dot.AncestryChanged:Connect(function(_, parent)
	if not parent and lockConn then
		lockConn:Disconnect()
	end
end)
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, -20, 1, 0); lbl.Position = UDim2.new(0, 18, 0, 0)
		lbl.Text = text .. " <font color='" .. colorHex .. "'>" .. (isEnabled and "Enabled" or "Disabled") .. "</font>"
		lbl.RichText = true; lbl.TextColor3 = Color3.new(1,1,1); lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.GothamMedium; lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = item

		table.insert(ActiveNotifs, item)
		UpdateIsland()

		-- CLEANUP LOGIC (Prevents "Staying Forever")
		task.delay(3, function()
			-- Remove from table first
			for i, v in ipairs(ActiveNotifs) do
				if v == item then
					table.remove(ActiveNotifs, i)
					break
				end
			end
			
			-- Animate out and destroy
			local out = AppleTween(item, {Position = UDim2.new(0, 0, 0, -20)}, 0.3)
			out.Completed:Wait()
			item:Destroy()
			UpdateIsland()
		end)
	end

	task.spawn(function()
		while task.wait(1) do Clock.Text = os.date("%H:%M") end
	end)

	NotificationIsland = vape.Categories.Render:CreateModule({
		Name = 'Notification Island',
		Function = function(callback)
			if callback then
				Island.Visible = true
				local old = vape.CreateNotification
				vape.CreateNotification = function(_, title, text, dur, t)
					if title == 'Module Toggled' then
						local clean = text:gsub("<[^>]+>", "")
						local name = clean:match("(.+) has been ")
						local enabled = clean:find("Enabled")
						if name then ShowNotif(name, enabled) end
						return
					end
					return old(_, title, text, dur, t)
				end
				NotificationIsland:Clean(function() 
					vape.CreateNotification = old
					Island.Visible = false 
				end)
			else
				Island.Visible = false
			end
		end
	})
end)
end)

run(function()
local StorageESP
local List
local Background
local Color = {}
local Reference = {}
local Folder = Instance.new('Folder')
Folder.Parent = vape.gui

local function nearStorageItem(item)
	for _, v in List.ListEnabled do
		if item:find(v) then return v end
	end
end

local function refreshAdornee(v)
	local chest = v.Adornee:FindFirstChild('ChestFolderValue')
	chest = chest and chest.Value or nil
	if not chest then
		v.Enabled = false
		return
	end

	local chestitems = chest and chest:GetChildren() or {}
	for _, obj in v.Frame:GetChildren() do
		if obj:IsA('ImageLabel') and obj.Name ~= 'Blur' then
			obj:Destroy()
		end
	end

	v.Enabled = false
	local alreadygot = {}
	for _, item in chestitems do
		if not alreadygot[item.Name] and (table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name)) then
			alreadygot[item.Name] = true
			v.Enabled = true
			local blockimage = Instance.new('ImageLabel')
			blockimage.Size = UDim2.fromOffset(32, 32)
			blockimage.BackgroundTransparency = 1
			blockimage.Image = bedwars.getIcon({itemType = item.Name}, true)
			blockimage.Parent = v.Frame
		end
	end
	table.clear(chestitems)
end

local function Added(v)
	local chest = v:WaitForChild('ChestFolderValue', 3)
	if not (chest and StorageESP.Enabled) then return end
	chest = chest.Value
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = 'chest'
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
	StorageESP:Clean(chest.ChildAdded:Connect(function(item)
		if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
			refreshAdornee(billboard)
		end
	end))
	StorageESP:Clean(chest.ChildRemoved:Connect(function(item)
		if table.find(List.ListEnabled, item.Name) or nearStorageItem(item.Name) then
			refreshAdornee(billboard)
		end
	end))
	task.spawn(refreshAdornee, billboard)
end

StorageESP = vape.Categories.Render:CreateModule({
	Name = 'StorageESP',
	Function = function(callback)
		if callback then
			StorageESP:Clean(collectionService:GetInstanceAddedSignal('chest'):Connect(Added))
			for _, v in collectionService:GetTagged('chest') do
				task.spawn(Added, v)
			end
		else
			table.clear(Reference)
			Folder:ClearAllChildren()
		end
	end,
	Tooltip = 'Displays items in chests'
})
List = StorageESP:CreateTextList({
	Name = 'Item',
	Function = function()
		for _, v in Reference do
			task.spawn(refreshAdornee, v)
		end
	end
})
Background = StorageESP:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color.Object then Color.Object.Visible = callback end
		for _, v in Reference do
			v.Frame.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true
})
Color = StorageESP:CreateColorSlider({
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
    local Knit
    local KrystalHeartbeat
    
    vape.Categories.Utility:CreateModule({
        Tooltip = "Disables Krystal (Glacial Skater) anticheat by forcing max momentum server-side.",
        Name = 'Partial Disabler',
        Function = function(callback)
            if callback then
                pcall(function()
                    Knit = require(game:GetService("ReplicatedStorage").rbxts_include.node_modules["@easy-games"].knit.src).KnitClient
                    skaterController = Knit.Controllers.GlacialSkaterController
                    
                    if skaterController and not oldUpdate then
                        oldUpdate = skaterController.updateMomentum
                        
                        -- Hook updateMomentum: always proxy to original with MAX momentum (100)
                        -- This makes the original code:
                        --   1. Set self.momentum = clamp(100, 0, 100) = 100
                        --   2. Fire momentumChanged(100) for UI
                        --   3. Send MomentumUpdate packet to server with {momentumValue = 100}
                        --   4. Apply HIGH_SPEED_SKATING status effect (momentum >= 95)
                        --   5. Set SprintController speed to getMomentumSpeed(100) = 27
                        skaterController.updateMomentum = function(self, p2, p3)
                            return oldUpdate(self, 100, "newValue")
                        end
                        
                        local SprintController = Knit.Controllers.SprintController
                        local RunService = game:GetService("RunService")
                        
                        KrystalHeartbeat = RunService.Heartbeat:Connect(function()
                            -- Remove blockSprint modifiers that Krystal re-applies on every respawn
                            if SprintController then
                                local mod = SprintController:getMovementStatusModifier()
                                if mod and mod.modifiers then
                                    for i = #mod.modifiers, 1, -1 do
                                        if type(mod.modifiers[i]) == "table" and mod.modifiers[i].blockSprint then
                                            mod:removeModifier(mod.modifiers[i])
                                        end
                                    end
                                end
                            end
                            
                            -- Force momentum update every frame so packets keep flowing
                            -- even when the original Heartbeat bails (speed > 100 studs/sec while flying)
                            if skaterController and oldUpdate then
                                pcall(oldUpdate, skaterController, 100, "newValue")
                            end
                        end)
                    end
                end)
            else
                if skaterController and oldUpdate then
                    skaterController.updateMomentum = oldUpdate
                    oldUpdate = nil
                end
                if KrystalHeartbeat then
                    KrystalHeartbeat:Disconnect()
                    KrystalHeartbeat = nil
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

run(function()
vape.Categories.World:CreateModule({
	Name = 'Anti-AFK',
	Function = function(callback)
		if callback then
			for _, v in getconnections(lplr.Idled) do
				v:Disconnect()
			end

			for _, v in getconnections(runService.Heartbeat) do
				if type(v.Function) == 'function' and table.find(debug.getconstants(v.Function), remotes.AfkStatus) then
					v:Disconnect()
				end
			end

			bedwars.Client:Get(remotes.AfkStatus):SendToServer({
				afk = false
			})
		end
	end,
	Tooltip = 'Lets you stay ingame without getting kicked'
})
end)

run(function()
local AutoSuffocate
local Range
local LimitItem

local function fixPosition(pos)
	return bedwars.BlockController:getBlockPosition(pos) * 3
end

AutoSuffocate = vape.Categories.World:CreateModule({
	Name = 'AutoSuffocate',
	Function = function(callback)
		if callback then
			repeat
				local item = store.hand.toolType == 'block' and store.hand.tool.Name or not LimitItem.Enabled and getWool()

				if item then
					local plrs = entitylib.AllPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Players = true
					})

					for _, ent in plrs do
						local needPlaced = {}

						for _, side in Enum.NormalId:GetEnumItems() do
							side = Vector3.fromNormalId(side)
							if side.Y ~= 0 then continue end

							side = fixPosition(ent.RootPart.Position + side * 2)
							if not getPlacedBlock(side) then
								table.insert(needPlaced, side)
							end
						end

						if #needPlaced < 3 then
							table.insert(needPlaced, fixPosition(ent.Head.Position))
							table.insert(needPlaced, fixPosition(ent.RootPart.Position - Vector3.new(0, 1, 0)))

							for _, pos in needPlaced do
								if not getPlacedBlock(pos) then
									task.spawn(bedwars.placeBlock, pos, item)
									break
								end
							end
						end
					end
				end

				task.wait(0.09)
			until not AutoSuffocate.Enabled
		end
	end,
	Tooltip = 'Places blocks on nearby confined entities'
})
Range = AutoSuffocate:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 20,
	Default = 20,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
LimitItem = AutoSuffocate:CreateToggle({
	Name = 'Limit to Items',
	Default = true
})
end)

run(function()
local AutoTool
local old, event

local function switchHotbarItem(block)
	if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
		local tool, slot = store.tools[bedwars.ItemMeta[block.Name].block.breakType], nil
		if tool then
			for i, v in store.inventory.hotbar do
				if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
			end

			if hotbarSwitch(slot) then
				if inputService:IsMouseButtonPressed(0) then 
					event:Fire() 
				end
				return true
			end
		end
	end
end

AutoTool = vape.Categories.World:CreateModule({
	Name = 'AutoTool',
	Function = function(callback)
		if callback then
			event = Instance.new('BindableEvent')
			AutoTool:Clean(event)
			AutoTool:Clean(event.Event:Connect(function()
				contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
			end))
			old = bedwars.BlockBreaker.hitBlock
			bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
				local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
				if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then return end
				return old(self, maid, raycastparams, ...)
			end
		else
			bedwars.BlockBreaker.hitBlock = old
			old = nil
		end
	end,
	Tooltip = 'Automatically selects the correct tool'
})
end)

run(function()
local BedProtector

local function getBedNear()
	local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
	for _, v in collectionService:GetTagged('bed') do
		if (localPosition - v.Position).Magnitude < 20 and v:GetAttribute('Team'..(lplr:GetAttribute('Team') or -1)..'NoBreak') then
			return v
		end
	end
end

local function getBlocks()
	local blocks = {}
	for _, item in store.inventory.inventory.items do
		local block = bedwars.ItemMeta[item.itemType].block
		if block then
			table.insert(blocks, {item.itemType, block.health})
		end
	end
	table.sort(blocks, function(a, b) 
		return a[2] > b[2]
	end)
	return blocks
end

local function getPyramid(size, grid)
	local positions = {}
	for h = size, 0, -1 do
		for w = h, 0, -1 do
			table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
			table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
			table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
			table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
		end
	end
	return positions
end

BedProtector = vape.Categories.World:CreateModule({
	Name = 'BedProtector',
	Function = function(callback)
		if callback then
			local bed = getBedNear()
			bed = bed and bed.Position or nil
			if bed then
				for i, block in getBlocks() do
					for _, pos in getPyramid(i, 3) do
						if not BedProtector.Enabled then break end
						if getPlacedBlock(bed + pos) then continue end
						bedwars.placeBlock(bed + pos, block[1], false)
					end
				end
				if BedProtector.Enabled then 
					BedProtector:Toggle() 
				end
			else
				notif('BedProtector', 'Unable to locate bed', 5)
				BedProtector:Toggle()
			end
		end
	end,
	Tooltip = 'Automatically places strong blocks around the bed.'
})
end)

run(function()
local ChestSteal
local Range
local Open
local Skywars
local Delays = {}

local function lootChest(chest)
	chest = chest and chest.Value or nil
	local chestitems = chest and chest:GetChildren() or {}
	if #chestitems > 1 and (Delays[chest] or 0) < tick() then
		Delays[chest] = tick() + 0.2
		bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(chest)

		for _, v in chestitems do
			if v:IsA('Accessory') then
				task.spawn(function()
					pcall(function()
						bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
					end)
				end)
			end
		end

		bedwars.Client:GetNamespace('Inventory'):Get('SetObservedChest'):SendToServer(nil)
	end
end

ChestSteal = vape.Categories.World:CreateModule({
	Name = 'ChestSteal',
	Function = function(callback)
		if callback then
			local chests = collection('chest', ChestSteal)
			repeat task.wait() until store.queueType ~= 'bedwars_test'
			if (not Skywars.Enabled) or store.queueType:find('skywars') then
				repeat
					if entitylib.isAlive and store.matchState ~= 2 then
						if Open.Enabled then
							if bedwars.AppController:isAppOpen('ChestApp') then
								lootChest(lplr.Character:FindFirstChild('ObservedChestFolder'))
							end
						else
							local localPosition = entitylib.character.RootPart.Position
							for _, v in chests do
								if (localPosition - v.Position).Magnitude <= Range.Value then
									lootChest(v:FindFirstChild('ChestFolderValue'))
								end
							end
						end
					end
					task.wait(0.1)
				until not ChestSteal.Enabled
			end
		end
	end,
	Tooltip = 'Grabs items from near chests.'
})
Range = ChestSteal:CreateSlider({
	Name = 'Range',
	Min = 0,
	Max = 18,
	Default = 18,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
Open = ChestSteal:CreateToggle({Name = 'GUI Check'})
Skywars = ChestSteal:CreateToggle({
	Name = 'Only Skywars',
	Function = function()
		if ChestSteal.Enabled then
			ChestSteal:Toggle()
			ChestSteal:Toggle()
		end
	end,
	Default = true
})
end)

run(function()
local Schematica
local File
local Mode
local Transparency
local parts, guidata, poschecklist = {}, {}, {}
local point1, point2

for x = -3, 3, 3 do
	for y = -3, 3, 3 do
		for z = -3, 3, 3 do
			if Vector3.new(x, y, z) ~= Vector3.zero then
				table.insert(poschecklist, Vector3.new(x, y, z))
			end
		end
	end
end

local function checkAdjacent(pos)
	for _, v in poschecklist do
		if getPlacedBlock(pos + v) then return true end
	end
	return false
end

local function getPlacedBlocksInPoints(s, e)
	local list, blocks = {}, bedwars.BlockController:getStore()
	for x = (e.X > s.X and s.X or e.X), (e.X > s.X and e.X or s.X) do
		for y = (e.Y > s.Y and s.Y or e.Y), (e.Y > s.Y and e.Y or s.Y) do
			for z = (e.Z > s.Z and s.Z or e.Z), (e.Z > s.Z and e.Z or s.Z) do
				local vec = Vector3.new(x, y, z)
				local block = blocks:getBlockAt(vec)
				if block and block:GetAttribute('PlacedByUserId') == lplr.UserId then
					list[vec] = block
				end
			end
		end
	end
	return list
end

local function loadMaterials()
	for _, v in guidata do 
		v:Destroy() 
	end
	local suc, read = pcall(function() 
		return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
	end)

	if suc and read then
		local items = {}
		for _, v in read do 
			items[v[2]] = (items[v[2]] or 0) + 1 
		end
		
		for i, v in items do
			local holder = Instance.new('Frame')
			holder.Size = UDim2.new(1, 0, 0, 32)
			holder.BackgroundTransparency = 1
			holder.Parent = Schematica.Children
			local icon = Instance.new('ImageLabel')
			icon.Size = UDim2.fromOffset(24, 24)
			icon.Position = UDim2.fromOffset(4, 4)
			icon.BackgroundTransparency = 1
			icon.Image = bedwars.getIcon({itemType = i}, true)
			icon.Parent = holder
			local text = Instance.new('TextLabel')
			text.Size = UDim2.fromOffset(100, 32)
			text.Position = UDim2.fromOffset(32, 0)
			text.BackgroundTransparency = 1
			text.Text = (bedwars.ItemMeta[i] and bedwars.ItemMeta[i].displayName or i)..': '..v
			text.TextXAlignment = Enum.TextXAlignment.Left
			text.TextColor3 = uipallet.Text
			text.TextSize = 14
			text.FontFace = uipallet.Font
			text.Parent = holder
			table.insert(guidata, holder)
		end
		table.clear(read)
		table.clear(items)
	end
end

local function save()
	if point1 and point2 then
		local tab = getPlacedBlocksInPoints(point1, point2)
		local savetab = {}
		point1 = point1 * 3
		for i, v in tab do
			i = bedwars.BlockController:getBlockPosition(CFrame.lookAlong(point1, entitylib.character.RootPart.CFrame.LookVector):PointToObjectSpace(i * 3)) * 3
			table.insert(savetab, {
				{
					x = i.X, 
					y = i.Y, 
					z = i.Z
				}, 
				v.Name
			})
		end
		point1, point2 = nil, nil
		writefile(File.Value, httpService:JSONEncode(savetab))
		notif('Schematica', 'Saved '..getTableSize(tab)..' blocks', 5)
		loadMaterials()
		table.clear(tab)
		table.clear(savetab)
	else
		local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
		if mouseinfo and mouseinfo.target then
			if point1 then
				point2 = mouseinfo.target.blockRef.blockPosition
				notif('Schematica', 'Selected position 2, toggle again near position 1 to save it', 3)
			else
				point1 = mouseinfo.target.blockRef.blockPosition
				notif('Schematica', 'Selected position 1', 3)
			end
		end
	end
end

local function load(read)
	local mouseinfo = bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
	if mouseinfo and mouseinfo.target then
		local position = CFrame.new(mouseinfo.placementPosition * 3) * CFrame.Angles(0, math.rad(math.round(math.deg(math.atan2(-entitylib.character.RootPart.CFrame.LookVector.X, -entitylib.character.RootPart.CFrame.LookVector.Z)) / 45) * 45), 0)

		for _, v in read do
			local blockpos = bedwars.BlockController:getBlockPosition((position * CFrame.new(v[1].x, v[1].y, v[1].z)).p) * 3
			if parts[blockpos] then continue end
			local handler = bedwars.BlockController:getHandlerRegistry():getHandler(v[2]:find('wool') and getWool() or v[2])
			if handler then
				local part = handler:place(blockpos / 3, 0)
				part.Transparency = Transparency.Value
				part.CanCollide = false
				part.Anchored = true
				part.Parent = workspace
				parts[blockpos] = part
			end
		end
		table.clear(read)

		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for i, v in parts do
					if (i - localPosition).Magnitude < 60 and checkAdjacent(i) then
						if not Schematica.Enabled then break end
						if not getItem(v.Name) then continue end
						bedwars.placeBlock(i, v.Name, false)
						task.delay(0.1, function()
							local block = getPlacedBlock(i)
							if block then
								v:Destroy()
								parts[i] = nil
							end
						end)
					end
				end
			end
			task.wait()
		until getTableSize(parts) <= 0

		if getTableSize(parts) <= 0 and Schematica.Enabled then
			notif('Schematica', 'Finished building', 5)
			Schematica:Toggle()
		end
	end
end

Schematica = vape.Categories.World:CreateModule({
	Name = 'Schematica',
	Function = function(callback)
		if callback then
			if not File.Value:find('.json') then
				notif('Schematica', 'Invalid file', 3)
				Schematica:Toggle()
				return
			end

			if Mode.Value == 'Save' then
				save()
				Schematica:Toggle()
			else
				local suc, read = pcall(function() 
					return isfile(File.Value) and httpService:JSONDecode(readfile(File.Value)) 
				end)

				if suc and read then
					load(read)
				else
					notif('Schematica', 'Missing / corrupted file', 3)
					Schematica:Toggle()
				end
			end
		else
			for _, v in parts do 
				v:Destroy() 
			end
			table.clear(parts)
		end
	end,
	Tooltip = 'Save and load placements of buildings'
})
File = Schematica:CreateTextBox({
	Name = 'File',
	Function = function()
		loadMaterials()
		point1, point2 = nil, nil
	end
})
Mode = Schematica:CreateDropdown({
	Name = 'Mode',
	List = {'Load', 'Save'}
})
Transparency = Schematica:CreateSlider({
	Name = 'Transparency',
	Min = 0,
	Max = 1,
	Default = 0.7,
	Decimal = 10,
	Function = function(val)
		for _, v in parts do 
			v.Transparency = val 
		end
	end
})
end)

run(function()
local ArmorSwitch
local Mode
local Targets
local Range

ArmorSwitch = vape.Categories.Inventory:CreateModule({
	Name = 'ArmorSwitch',
	Function = function(callback)
		if callback then
			if Mode.Value == 'Toggle' then
				repeat
					local state = entitylib.EntityPosition({
						Part = 'RootPart',
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Wallcheck = Targets.Walls.Enabled
					}) and true or false

					for i = 0, 2 do
						if (store.inventory.inventory.armor[i + 1] ~= 'empty') ~= state and ArmorSwitch.Enabled then
							bedwars.Store:dispatch({
								type = 'InventorySetArmorItem',
								item = store.inventory.inventory.armor[i + 1] == 'empty' and state and getBestArmor(i) or nil,
								armorSlot = i
							})
							vapeEvents.InventoryChanged.Event:Wait()
						end
					end
					task.wait(0.1)
				until not ArmorSwitch.Enabled
			else
				ArmorSwitch:Toggle()
				for i = 0, 2 do
					bedwars.Store:dispatch({
						type = 'InventorySetArmorItem',
						item = store.inventory.inventory.armor[i + 1] == 'empty' and getBestArmor(i) or nil,
						armorSlot = i
					})
					vapeEvents.InventoryChanged.Event:Wait()
				end
			end
		end
	end,
	Tooltip = 'Puts on / takes off armor when toggled for baiting.'
})
Mode = ArmorSwitch:CreateDropdown({
	Name = 'Mode',
	List = {'Toggle', 'On Key'}
})
Targets = ArmorSwitch:CreateTargets({
	Players = true,
	NPCs = true
})
Range = ArmorSwitch:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 30,
	Default = 30,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end
})
end)

run(function()
local AutoBank
local UIToggle
local UI
local Chests
local Items = {}

local function addItem(itemType, shop)
	local item = Instance.new('ImageLabel')
	item.Image = bedwars.getIcon({itemType = itemType}, true)
	item.Size = UDim2.fromOffset(32, 32)
	item.Name = itemType
	item.BackgroundTransparency = 1
	item.LayoutOrder = #UI:GetChildren()
	item.Parent = UI
	local itemtext = Instance.new('TextLabel')
	itemtext.Name = 'Amount'
	itemtext.Size = UDim2.fromScale(1, 1)
	itemtext.BackgroundTransparency = 1
	itemtext.Text = ''
	itemtext.TextColor3 = Color3.new(1, 1, 1)
	itemtext.TextSize = 16
	itemtext.TextStrokeTransparency = 0.3
	itemtext.Font = Enum.Font.Arial
	itemtext.Parent = item
	Items[itemType] = {Object = itemtext, Type = shop}
end

local function refreshBank(echest)
	for i, v in Items do
		local item = echest:FindFirstChild(i)
		v.Object.Text = item and item:GetAttribute('Amount') or ''
	end
end

local function nearChest()
	if entitylib.isAlive then
		local pos = entitylib.character.RootPart.Position
		for _, chest in Chests do
			if (chest.Position - pos).Magnitude < 20 then
				return true
			end
		end
	end
end

local function handleState()
	local chest = replicatedStorage.Inventories:FindFirstChild(lplr.Name..'_personal')
	if not chest then return end

	local mapCF = workspace.MapCFrames:FindFirstChild((lplr:GetAttribute('Team') or 1)..'_spawn')
	if mapCF and (entitylib.character.RootPart.Position - mapCF.Value.Position).Magnitude < 80 then
		for _, v in chest:GetChildren() do
			local item = Items[v.Name]
			if item then
				task.spawn(function()
					bedwars.Client:GetNamespace('Inventory'):Get('ChestGetItem'):CallServer(chest, v)
					refreshBank(chest)
				end)
			end
		end
	else
		for _, v in store.inventory.inventory.items do
			local item = Items[v.itemType]
			if item then
				task.spawn(function()
					bedwars.Client:GetNamespace('Inventory'):Get('ChestGiveItem'):CallServer(chest, v.tool)
					refreshBank(chest)
				end)
			end
		end
	end
end

AutoBank = vape.Categories.Inventory:CreateModule({
	Name = 'AutoBank',
	Function = function(callback)
		if callback then
			Chests = collection('personal-chest', AutoBank)
			UI = Instance.new('Frame')
			UI.Size = UDim2.new(1, 0, 0, 32)
			UI.Position = UDim2.fromOffset(0, -240)
			UI.BackgroundTransparency = 1
			UI.Visible = UIToggle.Enabled
			UI.Parent = vape.gui
			AutoBank:Clean(UI)
			local Sort = Instance.new('UIListLayout')
			Sort.FillDirection = Enum.FillDirection.Horizontal
			Sort.HorizontalAlignment = Enum.HorizontalAlignment.Center
			Sort.SortOrder = Enum.SortOrder.LayoutOrder
			Sort.Parent = UI
			addItem('iron', true)
			addItem('gold', true)
			addItem('diamond', false)
			addItem('emerald', true)
			addItem('void_crystal', true)

			repeat
				local hotbar = lplr.PlayerGui:FindFirstChild('hotbar')
				hotbar = hotbar and hotbar['1']:FindFirstChild('HotbarHealthbarContainer')
				if hotbar then
					UI.Position = UDim2.fromOffset(0, (hotbar.AbsolutePosition.Y + guiService:GetGuiInset().Y) - 40)
				end

				local newState = nearChest()
				if newState then
					handleState()
				end

				task.wait(0.1)
			until (not AutoBank.Enabled)
		else
			table.clear(Items)
		end
	end,
	Tooltip = 'Automatically puts resources in ender chest'
})
UIToggle = AutoBank:CreateToggle({
	Name = 'UI',
	Function = function(callback)
		if AutoBank.Enabled then
			UI.Visible = callback
		end
	end,
	Default = true
})
end)

run(function()
local AutoBuy
local Sword
local Armor
local Upgrades
local TierCheck
local BedwarsCheck
local GUI
local SmartCheck
local Custom = {}
local CustomPost = {}
local UpgradeToggles = {}
local Functions, id = {}
local Callbacks = {Custom, Functions, CustomPost}
local npctick = tick()

local swords = {
	'wood_sword',
	'stone_sword',
	'iron_sword',
	'diamond_sword',
	'emerald_sword'
}

local armors = {
	'none',
	'leather_chestplate',
	'iron_chestplate',
	'diamond_chestplate',
	'emerald_chestplate'
}

local axes = {
	'none',
	'wood_axe',
	'stone_axe',
	'iron_axe',
	'diamond_axe'
}

local pickaxes = {
	'none',
	'wood_pickaxe',
	'stone_pickaxe',
	'iron_pickaxe',
	'diamond_pickaxe'
}

local function getShopNPC()
	local shop, items, upgrades, newid = nil, false, false, nil
	if entitylib.isAlive then
		local localPosition = entitylib.character.RootPart.Position
		for _, v in store.shop do
			if (v.RootPart.Position - localPosition).Magnitude <= 20 then
				shop = v.Upgrades or v.Shop or nil
				upgrades = upgrades or v.Upgrades
				items = items or v.Shop
				newid = v.Shop and v.Id or newid
			end
		end
	end
	return shop, items, upgrades, newid
end

local function canBuy(item, currencytable, amount)
	amount = amount or 1
	if not currencytable[item.currency] then
		local currency = getItem(item.currency)
		currencytable[item.currency] = currency and currency.amount or 0
	end
	if item.ignoredByKit and table.find(item.ignoredByKit, store.equippedKit or '') then return false end
	if item.lockedByForge or item.disabled then return false end
	if item.require and item.require.teamUpgrade then
		if (bedwars.Store:getState().Bedwars.teamUpgrades[item.require.teamUpgrade.upgradeId] or -1) < item.require.teamUpgrade.lowestTierIndex then
			return false
		end
	end
	return currencytable[item.currency] >= (item.price * amount)
end

local function buyItem(item, currencytable)
	if not id then return end
	notif('AutoBuy', 'Bought '..bedwars.ItemMeta[item.itemType].displayName, 3)
	bedwars.Client:Get('BedwarsPurchaseItem'):CallServerAsync({
		shopItem = item,
		shopId = id
	}):andThen(function(suc)
		if suc then
			bedwars.SoundManager:playSound(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
			bedwars.Store:dispatch({
				type = 'BedwarsAddItemPurchased',
				itemType = item.itemType
			})
			bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
		end
	end)
	currencytable[item.currency] -= item.price
end

local function buyUpgrade(upgradeType, currencytable)
	if not Upgrades.Enabled then return end
	local upgrade = bedwars.TeamUpgradeMeta[upgradeType]
	local currentUpgrades = bedwars.Store:getState().Bedwars.teamUpgrades[lplr:GetAttribute('Team')] or {}
	local currentTier = (currentUpgrades[upgradeType] or 0) + 1
	local bought = false

	for i = currentTier, #upgrade.tiers do
		local tier = upgrade.tiers[i]
		if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then continue end

		if canBuy({currency = 'diamond', price = tier.cost}, currencytable) then
			notif('AutoBuy', 'Bought '..(upgrade.name == 'Armor' and 'Protection' or upgrade.name)..' '..i, 3)
			bedwars.Client:Get('RequestPurchaseTeamUpgrade'):CallServerAsync(upgradeType)
			currencytable.diamond -= tier.cost
			bought = true
		else
			break
		end
	end

	return bought
end

local function buyTool(tool, tools, currencytable)
	local bought, buyable = false
	tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge

	for i = tool, #tools do
		local v = bedwars.Shop.getShopItem(tools[i], lplr)
		if canBuy(v, currencytable) then
			if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
				if Armor.Enabled then
					local currentarmor = store.inventory.inventory.armor[2]
					currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
					if (table.find(armors, currentarmor) or 3) < 3 then break end
				end
				if Sword.Enabled then
					if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
				end
			end
			bought = true
			buyable = v
		end
		if TierCheck.Enabled and v.nextTier then break end
	end

	if buyable then
		buyItem(buyable, currencytable)
	end

	return bought
end

AutoBuy = vape.Categories.Inventory:CreateModule({
	Name = 'AutoBuy',
	Function = function(callback)
		if callback then
			repeat task.wait() until store.queueType ~= 'bedwars_test'
			if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end

			local lastupgrades
			AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
				if (npctick - tick()) > 1 then npctick = tick() end
			end))

			repeat
				local npc, shop, upgrades, newid = getShopNPC()
				id = newid
				if GUI.Enabled then
					if not (bedwars.AppController:isAppOpen('BedwarsItemShopApp') or bedwars.AppController:isAppOpen('TeamUpgradeApp')) then
						npc = nil
					end
				end

				if npc and lastupgrades ~= upgrades then
					if (npctick - tick()) > 1 then npctick = tick() end
					lastupgrades = upgrades
				end

				if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
					local currencytable = {}
					local waitcheck
					for _, tab in Callbacks do
						for _, callback in tab do
							if callback(currencytable, shop, upgrades) then
								waitcheck = true
							end
						end
					end
					npctick = tick() + (waitcheck and 0.4 or math.huge)
				end

				task.wait(0.1)
			until not AutoBuy.Enabled
		else
			npctick = tick()
		end
	end,
	Tooltip = 'Automatically buys items when you go near the shop'
})
Sword = AutoBuy:CreateToggle({
	Name = 'Buy Sword',
	Function = function(callback)
		npctick = tick()
		Functions[2] = callback and function(currencytable, shop)
			if not shop then return end

			if store.equippedKit == 'dasher' then
				swords = {
					[1] = 'wood_dao',
					[2] = 'stone_dao',
					[3] = 'iron_dao',
					[4] = 'diamond_dao',
					[5] = 'emerald_dao'
				}
			elseif store.equippedKit == 'ice_queen' then
				swords[5] = 'ice_sword'
			elseif store.equippedKit == 'ember' then
				swords[5] = 'infernal_saber'
			elseif store.equippedKit == 'lumen' then
				swords[5] = 'light_sword'
			end

			return buyTool(store.tools.sword, swords, currencytable)
		end or nil
	end
})
Armor = AutoBuy:CreateToggle({
	Name = 'Buy Armor',
	Function = function(callback)
		npctick = tick()
		Functions[1] = callback and function(currencytable, shop)
			if not shop then return end
			local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
			currentarmor = currentarmor and currentarmor.itemType or 'none'
			return buyTool({itemType = currentarmor}, armors, currencytable)
		end or nil
	end,
	Default = true
})
AutoBuy:CreateToggle({
	Name = 'Buy Axe',
	Function = function(callback)
		npctick = tick()
		Functions[3] = callback and function(currencytable, shop)
			if not shop then return end
			return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
		end or nil
	end
})
AutoBuy:CreateToggle({
	Name = 'Buy Pickaxe',
	Function = function(callback)
		npctick = tick()
		Functions[4] = callback and function(currencytable, shop)
			if not shop then return end
			return buyTool(store.tools.stone, pickaxes, currencytable)
		end or nil
	end
})
Upgrades = AutoBuy:CreateToggle({
	Name = 'Buy Upgrades',
	Function = function(callback)
		for _, v in UpgradeToggles do
			v.Object.Visible = callback
		end
	end,
	Default = true
})
local count = 0
for i, v in bedwars.TeamUpgradeMeta do
	local toggleCount = count
	table.insert(UpgradeToggles, AutoBuy:CreateToggle({
		Name = 'Buy '..(v.name == 'Armor' and 'Protection' or v.name),
		Function = function(callback)
			npctick = tick()
			Functions[5 + toggleCount + (v.name == 'Armor' and 20 or 0)] = callback and function(currencytable, shop, upgrades)
				if not upgrades then return end
				if v.disabledInQueue and table.find(v.disabledInQueue, store.queueType) then return end
				return buyUpgrade(i, currencytable)
			end or nil
		end,
		Darker = true,
		Default = (i == 'ARMOR' or i == 'DAMAGE')
	}))
	count += 1
end
TierCheck = AutoBuy:CreateToggle({Name = 'Tier Check'})
BedwarsCheck = AutoBuy:CreateToggle({
	Name = 'Only Bedwars',
	Function = function()
		if AutoBuy.Enabled then
			AutoBuy:Toggle()
			AutoBuy:Toggle()
		end
	end,
	Default = true
})
GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
SmartCheck = AutoBuy:CreateToggle({
	Name = 'Smart check',
	Default = true,
	Tooltip = 'Buys iron armor before iron axe'
})
AutoBuy:CreateTextList({
	Name = 'Item',
	Placeholder = 'priority/item/amount/after',
	Function = function(list)
		table.clear(Custom)
		table.clear(CustomPost)
		for _, entry in list do
			local tab = entry:split('/')
			local ind = tonumber(tab[1])
			if ind then
				(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
					if not shop then return end

					local v = bedwars.Shop.getShopItem(tab[2], lplr)
					if v then
						local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
						item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
						if item > 0 and canBuy(v, currencytable, item) then
							for _ = 1, item do
								buyItem(v, currencytable)
							end
							return true
						end
					end
				end
			end
		end
	end
})
end)

run(function()
local AutoConsume
local Health
local SpeedPotion
local Apple
local ShieldPotion

local function consumeCheck(attribute)
	if entitylib.isAlive then
		if SpeedPotion.Enabled and (not attribute or attribute == 'StatusEffect_speed') then
			local speedpotion = getItem('speed_potion')
			if speedpotion and (not lplr.Character:GetAttribute('StatusEffect_speed')) then
				for _ = 1, 4 do
					if bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = speedpotion.tool}) then break end
				end
			end
		end

		if Apple.Enabled and (not attribute or attribute:find('Health')) then
			if (lplr.Character:GetAttribute('Health') / lplr.Character:GetAttribute('MaxHealth')) <= (Health.Value / 100) then
				local apple = getItem('orange') or (not lplr.Character:GetAttribute('StatusEffect_golden_apple') and getItem('golden_apple')) or getItem('apple')
				
				if apple then
					bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
						item = apple.tool
					})
				end
			end
		end

		if ShieldPotion.Enabled and (not attribute or attribute:find('Shield')) then
			if (lplr.Character:GetAttribute('Shield_POTION') or 0) == 0 then
				local shield = getItem('big_shield') or getItem('mini_shield')

				if shield then
					bedwars.Client:Get(remotes.ConsumeItem):CallServerAsync({
						item = shield.tool
					})
				end
			end
		end
	end
end

AutoConsume = vape.Categories.Inventory:CreateModule({
	Name = 'AutoConsume',
	Function = function(callback)
		if callback then
			AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(consumeCheck))
			AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
				if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
					consumeCheck(attribute)
				end
			end))
			consumeCheck()
		end
	end,
	Tooltip = 'Automatically heals for you when health or shield is under threshold.'
})
Health = AutoConsume:CreateSlider({
	Name = 'Health Percent',
	Min = 1,
	Max = 99,
	Default = 70,
	Suffix = '%'
})
SpeedPotion = AutoConsume:CreateToggle({
	Name = 'Speed Potions',
	Default = true
})
Apple = AutoConsume:CreateToggle({
	Name = 'Apple',
	Default = true
})
ShieldPotion = AutoConsume:CreateToggle({
	Name = 'Shield Potions',
	Default = true
})
end)

run(function()
local AutoHotbar
local Mode
local Clear
local List
local Active

local function CreateWindow(self)
	local selectedslot = 1
	local window = Instance.new('Frame')
	window.Name = 'HotbarGUI'
	window.Size = UDim2.fromOffset(660, 465)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.BackgroundColor3 = uipallet.Main
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Visible = false
	window.Parent = vape.gui.ScaledGui
	local title = Instance.new('TextLabel')
	title.Name = 'Title'
	title.Size = UDim2.new(1, -10, 0, 20)
	title.Position = UDim2.fromOffset(math.abs(title.Size.X.Offset), 12)
	title.BackgroundTransparency = 1
	title.Text = 'AutoHotbar'
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = uipallet.Text
	title.TextSize = 13
	title.FontFace = uipallet.Font
	title.Parent = window
	local divider = Instance.new('Frame')
	divider.Name = 'Divider'
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.fromOffset(0, 40)
	divider.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
	divider.BorderSizePixel = 0
	divider.Parent = window
	addBlur(window)
	local modal = Instance.new('TextButton')
	modal.Text = ''
	modal.BackgroundTransparency = 1
	modal.Modal = true
	modal.Parent = window
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = window
	local close = Instance.new('ImageButton')
	close.Name = 'Close'
	close.Size = UDim2.fromOffset(24, 24)
	close.Position = UDim2.new(1, -35, 0, 9)
	close.BackgroundColor3 = Color3.new(1, 1, 1)
	close.BackgroundTransparency = 1
	close.Image = getcustomasset('newvape/assets/new/close.png')
	close.ImageColor3 = color.Light(uipallet.Text, 0.2)
	close.ImageTransparency = 0.5
	close.AutoButtonColor = false
	close.Parent = window
	close.MouseEnter:Connect(function()
		close.ImageTransparency = 0.3
		tween:Tween(close, TweenInfo.new(0.2), {
			BackgroundTransparency = 0.6
		})
	end)
	close.MouseLeave:Connect(function()
		close.ImageTransparency = 0.5
		tween:Tween(close, TweenInfo.new(0.2), {
			BackgroundTransparency = 1
		})
	end)
	close.MouseButton1Click:Connect(function()
		window.Visible = false
		vape.gui.ScaledGui.ClickGui.Visible = true
	end)
	local closecorner = Instance.new('UICorner')
	closecorner.CornerRadius = UDim.new(1, 0)
	closecorner.Parent = close
	local bigslot = Instance.new('Frame')
	bigslot.Size = UDim2.fromOffset(110, 111)
	bigslot.Position = UDim2.fromOffset(11, 71)
	bigslot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
	bigslot.Parent = window
	local bigslotcorner = Instance.new('UICorner')
	bigslotcorner.CornerRadius = UDim.new(0, 4)
	bigslotcorner.Parent = bigslot
	local bigslotstroke = Instance.new('UIStroke')
	bigslotstroke.Color = color.Light(uipallet.Main, 0.034)
	bigslotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bigslotstroke.Parent = bigslot
	local slotnum = Instance.new('TextLabel')
	slotnum.Size = UDim2.fromOffset(80, 20)
	slotnum.Position = UDim2.fromOffset(25, 200)
	slotnum.BackgroundTransparency = 1
	slotnum.Text = 'SLOT 1'
	slotnum.TextColor3 = color.Dark(uipallet.Text, 0.1)
	slotnum.TextSize = 12
	slotnum.FontFace = uipallet.Font
	slotnum.Parent = window
	for i = 1, 9 do
		local slotbkg = Instance.new('TextButton')
		slotbkg.Name = 'Slot'..i
		slotbkg.Size = UDim2.fromOffset(51, 52)
		slotbkg.Position = UDim2.fromOffset(89 + (i * 55), 382)
		slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		slotbkg.Text = ''
		slotbkg.AutoButtonColor = false
		slotbkg.Parent = window
		local slotimage = Instance.new('ImageLabel')
		slotimage.Size = UDim2.fromOffset(32, 32)
		slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
		slotimage.BackgroundTransparency = 1
		slotimage.Image = ''
		slotimage.Parent = slotbkg
		local slotcorner = Instance.new('UICorner')
		slotcorner.CornerRadius = UDim.new(0, 4)
		slotcorner.Parent = slotbkg
		local slotstroke = Instance.new('UIStroke')
		slotstroke.Color = color.Light(uipallet.Main, 0.04)
		slotstroke.Thickness = 2
		slotstroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		slotstroke.Enabled = i == selectedslot
		slotstroke.Parent = slotbkg
		slotbkg.MouseEnter:Connect(function()
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		end)
		slotbkg.MouseLeave:Connect(function()
			slotbkg.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
		end)
		slotbkg.MouseButton1Click:Connect(function()
			window['Slot'..selectedslot].UIStroke.Enabled = false
			selectedslot = i
			slotstroke.Enabled = true
			slotnum.Text = 'SLOT '..selectedslot
		end)
		slotbkg.MouseButton2Click:Connect(function()
			local obj = self.Hotbars[self.Selected]
			if obj then
				window['Slot'..i].ImageLabel.Image = ''
				obj.Hotbar[tostring(i)] = nil
				obj.Object['Slot'..i].Image = '	'
			end
		end)
	end
	local searchbkg = Instance.new('Frame')
	searchbkg.Size = UDim2.fromOffset(496, 31)
	searchbkg.Position = UDim2.fromOffset(142, 80)
	searchbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
	searchbkg.Parent = window
	local search = Instance.new('TextBox')
	search.Size = UDim2.new(1, -10, 0, 31)
	search.Position = UDim2.fromOffset(10, 0)
	search.BackgroundTransparency = 1
	search.Text = ''
	search.PlaceholderText = ''
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.TextColor3 = uipallet.Text
	search.TextSize = 12
	search.FontFace = uipallet.Font
	search.ClearTextOnFocus = false
	search.Parent = searchbkg
	local searchcorner = Instance.new('UICorner')
	searchcorner.CornerRadius = UDim.new(0, 4)
	searchcorner.Parent = searchbkg
	local searchicon = Instance.new('ImageLabel')
	searchicon.Size = UDim2.fromOffset(14, 14)
	searchicon.Position = UDim2.new(1, -26, 0, 8)
	searchicon.BackgroundTransparency = 1
	searchicon.Image = getcustomasset('newvape/assets/new/search.png')
	searchicon.ImageColor3 = color.Light(uipallet.Main, 0.37)
	searchicon.Parent = searchbkg
	local children = Instance.new('ScrollingFrame')
	children.Name = 'Children'
	children.Size = UDim2.fromOffset(500, 240)
	children.Position = UDim2.fromOffset(144, 122)
	children.BackgroundTransparency = 1
	children.BorderSizePixel = 0
	children.ScrollBarThickness = 2
	children.ScrollBarImageTransparency = 0.75
	children.CanvasSize = UDim2.new()
	children.Parent = window
	local windowlist = Instance.new('UIGridLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.FillDirectionMaxCells = 9
	windowlist.CellSize = UDim2.fromOffset(51, 52)
	windowlist.CellPadding = UDim2.fromOffset(4, 3)
	windowlist.Parent = children
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		children.CanvasSize = UDim2.fromOffset(0, windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale)
	end)
	table.insert(vape.Windows, window)

	local function createitem(id, image)
		local slotbkg = Instance.new('TextButton')
		slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		slotbkg.Text = ''
		slotbkg.AutoButtonColor = false
		slotbkg.Parent = children
		local slotimage = Instance.new('ImageLabel')
		slotimage.Size = UDim2.fromOffset(32, 32)
		slotimage.Position = UDim2.new(0.5, -16, 0.5, -16)
		slotimage.BackgroundTransparency = 1
		slotimage.Image = image
		slotimage.Parent = slotbkg
		local slotcorner = Instance.new('UICorner')
		slotcorner.CornerRadius = UDim.new(0, 4)
		slotcorner.Parent = slotbkg
		slotbkg.MouseEnter:Connect(function()
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.04)
		end)
		slotbkg.MouseLeave:Connect(function()
			slotbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.02)
		end)
		slotbkg.MouseButton1Click:Connect(function()
			local obj = self.Hotbars[self.Selected]
			if obj then
				window['Slot'..selectedslot].ImageLabel.Image = image
				obj.Hotbar[tostring(selectedslot)] = id
				obj.Object['Slot'..selectedslot].Image = image
			end
		end)
	end

	local function indexSearch(text)
		for _, v in children:GetChildren() do
			if v:IsA('TextButton') then
				v:ClearAllChildren()
				v:Destroy()
			end
		end

		if text == '' then
			for _, v in {'diamond_sword', 'diamond_pickaxe', 'diamond_axe', 'shears', 'wood_bow', 'wool_white', 'fireball', 'apple', 'iron', 'gold', 'diamond', 'emerald'} do
				createitem(v, bedwars.ItemMeta[v].image)
			end
			return
		end

		for i, v in bedwars.ItemMeta do
			if text:lower() == i:lower():sub(1, text:len()) then
				if not v.image then continue end
				createitem(i, v.image)
			end
		end
	end

	search:GetPropertyChangedSignal('Text'):Connect(function()
		indexSearch(search.Text)
	end)
	indexSearch('')

	return window
end

vape.Components.HotbarList = function(optionsettings, children, api)
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	local optionapi = {
		Type = 'HotbarList',
		Hotbars = {},
		Selected = 1
	}
	local hotbarlist = Instance.new('TextButton')
	hotbarlist.Name = 'HotbarList'
	hotbarlist.Size = UDim2.fromOffset(220, 40)
	hotbarlist.BackgroundColor3 = optionsettings.Darker and (children.BackgroundColor3 == color.Dark(uipallet.Main, 0.02) and color.Dark(uipallet.Main, 0.04) or color.Dark(uipallet.Main, 0.02)) or children.BackgroundColor3
	hotbarlist.Text = ''
	hotbarlist.BorderSizePixel = 0
	hotbarlist.AutoButtonColor = false
	hotbarlist.Parent = children
	local textbkg = Instance.new('Frame')
	textbkg.Name = 'BKG'
	textbkg.Size = UDim2.new(1, -20, 0, 31)
	textbkg.Position = UDim2.fromOffset(10, 4)
	textbkg.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
	textbkg.Parent = hotbarlist
	local textbkgcorner = Instance.new('UICorner')
	textbkgcorner.CornerRadius = UDim.new(0, 4)
	textbkgcorner.Parent = textbkg
	local textbutton = Instance.new('TextButton')
	textbutton.Name = 'HotbarList'
	textbutton.Size = UDim2.new(1, -2, 1, -2)
	textbutton.Position = UDim2.fromOffset(1, 1)
	textbutton.BackgroundColor3 = uipallet.Main
	textbutton.Text = ''
	textbutton.AutoButtonColor = false
	textbutton.Parent = textbkg
	textbutton.MouseEnter:Connect(function()
		tween:Tween(textbkg, TweenInfo.new(0.2), {
			BackgroundColor3 = color.Light(uipallet.Main, 0.14)
		})
	end)
	textbutton.MouseLeave:Connect(function()
		tween:Tween(textbkg, TweenInfo.new(0.2), {
			BackgroundColor3 = color.Light(uipallet.Main, 0.034)
		})
	end)
	local textbuttoncorner = Instance.new('UICorner')
	textbuttoncorner.CornerRadius = UDim.new(0, 4)
	textbuttoncorner.Parent = textbutton
	local textbuttonicon = Instance.new('ImageLabel')
	textbuttonicon.Size = UDim2.fromOffset(12, 12)
	textbuttonicon.Position = UDim2.fromScale(0.5, 0.5)
	textbuttonicon.AnchorPoint = Vector2.new(0.5, 0.5)
	textbuttonicon.BackgroundTransparency = 1
	textbuttonicon.Image = getcustomasset('newvape/assets/new/add.png')
	textbuttonicon.ImageColor3 = Color3.fromHSV(0.46, 0.96, 0.52)
	textbuttonicon.Parent = textbutton
	local childrenlist = Instance.new('Frame')
	childrenlist.Size = UDim2.new(1, 0, 1, -40)
	childrenlist.Position = UDim2.fromOffset(0, 40)
	childrenlist.BackgroundTransparency = 1
	childrenlist.Parent = hotbarlist
	local windowlist = Instance.new('UIListLayout')
	windowlist.SortOrder = Enum.SortOrder.LayoutOrder
	windowlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
	windowlist.Padding = UDim.new(0, 3)
	windowlist.Parent = childrenlist
	windowlist:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		hotbarlist.Size = UDim2.fromOffset(220, math.min(43 + windowlist.AbsoluteContentSize.Y / vape.guiscale.Scale, 603))
	end)
	textbutton.MouseButton1Click:Connect(function()
		optionapi:AddHotbar()
	end)
	optionapi.Window = CreateWindow(optionapi)

	function optionapi:Save(savetab)
		local hotbars = {}
		for _, v in self.Hotbars do
			table.insert(hotbars, v.Hotbar)
		end
		savetab.HotbarList = {
			Selected = self.Selected,
			Hotbars = hotbars
		}
	end

	function optionapi:Load(savetab)
		for _, v in self.Hotbars do
			v.Object:ClearAllChildren()
			v.Object:Destroy()
			table.clear(v.Hotbar)
		end
		table.clear(self.Hotbars)
		for _, v in savetab.Hotbars do
			self:AddHotbar(v)
		end
		self.Selected = savetab.Selected or 1
	end

	function optionapi:AddHotbar(data)
		local hotbardata = {Hotbar = data or {}}
		table.insert(self.Hotbars, hotbardata)
		local hotbar = Instance.new('TextButton')
		hotbar.Size = UDim2.fromOffset(200, 27)
		hotbar.BackgroundColor3 = table.find(self.Hotbars, hotbardata) == self.Selected and color.Light(uipallet.Main, 0.034) or uipallet.Main
		hotbar.Text = ''
		hotbar.AutoButtonColor = false
		hotbar.Parent = childrenlist
		hotbardata.Object = hotbar
		local hotbarcorner = Instance.new('UICorner')
		hotbarcorner.CornerRadius = UDim.new(0, 4)
		hotbarcorner.Parent = hotbar
		for i = 1, 9 do
			local slot = Instance.new('ImageLabel')
			slot.Name = 'Slot'..i
			slot.Size = UDim2.fromOffset(17, 18)
			slot.Position = UDim2.fromOffset(-7 + (i * 18), 5)
			slot.BackgroundColor3 = color.Dark(uipallet.Main, 0.02)
			slot.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
			slot.BorderSizePixel = 0
			slot.Parent = hotbar
		end
		hotbar.MouseButton1Click:Connect(function()
			local ind = table.find(optionapi.Hotbars, hotbardata)
			if ind == optionapi.Selected then
				vape.gui.ScaledGui.ClickGui.Visible = false
				optionapi.Window.Visible = true
				for i = 1, 9 do
					optionapi.Window['Slot'..i].ImageLabel.Image = hotbardata.Hotbar[tostring(i)] and bedwars.getIcon({itemType = hotbardata.Hotbar[tostring(i)]}, true) or ''
				end
			else
				if optionapi.Hotbars[optionapi.Selected] then
					optionapi.Hotbars[optionapi.Selected].Object.BackgroundColor3 = uipallet.Main
				end
				hotbar.BackgroundColor3 = color.Light(uipallet.Main, 0.034)
				optionapi.Selected = ind
			end
		end)
		local close = Instance.new('ImageButton')
		close.Name = 'Close'
		close.Size = UDim2.fromOffset(16, 16)
		close.Position = UDim2.new(1, -23, 0, 6)
		close.BackgroundColor3 = Color3.new(1, 1, 1)
		close.BackgroundTransparency = 1
		close.Image = getcustomasset('newvape/assets/new/closemini.png')
		close.ImageColor3 = color.Light(uipallet.Text, 0.2)
		close.ImageTransparency = 0.5
		close.AutoButtonColor = false
		close.Parent = hotbar
		local closecorner = Instance.new('UICorner')
		closecorner.CornerRadius = UDim.new(1, 0)
		closecorner.Parent = close
		close.MouseEnter:Connect(function()
			close.ImageTransparency = 0.3
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 0.6
			})
		end)
		close.MouseLeave:Connect(function()
			close.ImageTransparency = 0.5
			tween:Tween(close, TweenInfo.new(0.2), {
				BackgroundTransparency = 1
			})
		end)
		close.MouseButton1Click:Connect(function()
			local ind = table.find(self.Hotbars, hotbardata)
			local obj = self.Hotbars[self.Selected]
			local obj2 = self.Hotbars[ind]
			if obj and obj2 then
				obj2.Object:ClearAllChildren()
				obj2.Object:Destroy()
				table.remove(self.Hotbars, ind)
				ind = table.find(self.Hotbars, obj)
				self.Selected = table.find(self.Hotbars, obj) or 1
			end
		end)
	end

	api.Options.HotbarList = optionapi

	return optionapi
end

local function getBlock()
	local clone = table.clone(store.inventory.inventory.items)
	table.sort(clone, function(a, b)
		return a.amount < b.amount
	end)

	for _, item in clone do
		local block = bedwars.ItemMeta[item.itemType].block
		if block and not block.seeThrough then
			return item
		end
	end
end

local function getCustomItem(v)
	if v == 'diamond_sword' then
		local sword = store.tools.sword
		v = sword and sword.itemType or 'wood_sword'
	elseif v == 'diamond_pickaxe' then
		local pickaxe = store.tools.stone
		v = pickaxe and pickaxe.itemType or 'wood_pickaxe'
	elseif v == 'diamond_axe' then
		local axe = store.tools.wood
		v = axe and axe.itemType or 'wood_axe'
	elseif v == 'wood_bow' then
		local bow = getBow()
		v = bow and bow.itemType or 'wood_bow'
	elseif v == 'wool_white' then
		local block = getBlock()
		v = block and block.itemType or 'wool_white'
	end

	return v
end

local function findItemInTable(tab, item)
	for slot, v in tab do
		if item.itemType == getCustomItem(v) then
			return tonumber(slot)
		end
	end
end

local function findInHotbar(item)
	for i, v in store.inventory.hotbar do
		if v.item and v.item.itemType == item.itemType then
			return i - 1, v.item
		end
	end
end

local function findInInventory(item)
	for _, v in store.inventory.inventory.items do
		if v.itemType == item.itemType then
			return v
		end
	end
end

local function dispatch(...)
	bedwars.Store:dispatch(...)
	vapeEvents.InventoryChanged.Event:Wait()
end

local function sortCallback()
	if Active then return end
	Active = true
	local items = (List.Hotbars[List.Selected] and List.Hotbars[List.Selected].Hotbar or {})

	for _, v in store.inventory.inventory.items do
		local slot = findItemInTable(items, v)
		if slot then
			local olditem = store.inventory.hotbar[slot]
			if olditem.item and olditem.item.itemType == v.itemType then continue end
			if olditem.item then
				dispatch({
					type = 'InventoryRemoveFromHotbar',
					slot = slot - 1
				})
			end

			local newslot = findInHotbar(v)
			if newslot then
				dispatch({
					type = 'InventoryRemoveFromHotbar',
					slot = newslot
				})
				if olditem.item then
					dispatch({
						type = 'InventoryAddToHotbar',
						item = findInInventory(olditem.item),
						slot = newslot
					})
				end
			end

			dispatch({
				type = 'InventoryAddToHotbar',
				item = findInInventory(v),
				slot = slot - 1
			})
		elseif Clear.Enabled then
			local newslot = findInHotbar(v)
			if newslot then
			   	dispatch({
					type = 'InventoryRemoveFromHotbar',
					slot = newslot
				})
			end
		end
	end

	Active = false
end

AutoHotbar = vape.Categories.Inventory:CreateModule({
	Name = 'AutoHotbar',
	Function = function(callback)
		if callback then
			task.spawn(sortCallback)
			if Mode.Value == 'On Key' then
				AutoHotbar:Toggle()
				return
			end

			AutoHotbar:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(sortCallback))
		end
	end,
	Tooltip = 'Automatically arranges hotbar to your liking.'
})
Mode = AutoHotbar:CreateDropdown({
	Name = 'Activation',
	List = {'Toggle', 'On Key'},
	Function = function()
		if AutoHotbar.Enabled then
			AutoHotbar:Toggle()
			AutoHotbar:Toggle()
		end
	end
})
Clear = AutoHotbar:CreateToggle({Name = 'Clear Hotbar'})
List = AutoHotbar:CreateHotbarList({})
end)

run(function()
local Value
local oldclickhold, oldshowprogress

local FastConsume = vape.Categories.Inventory:CreateModule({
	Name = 'FastConsume',
	Function = function(callback)
		if callback then
			oldclickhold = bedwars.ClickHold.startClick
			oldshowprogress = bedwars.ClickHold.showProgress
			bedwars.ClickHold.startClick = function(self)
				self.startedClickTime = tick()
				local handle = self:showProgress()
				local clicktime = self.startedClickTime
				bedwars.RuntimeLib.Promise.defer(function()
					task.wait(self.durationSeconds * (Value.Value / 40))
					if handle == self.handle and clicktime == self.startedClickTime and self.closeOnComplete then
						self:hideProgress()
						if self.onComplete then self.onComplete() end
						if self.onPartialComplete then self.onPartialComplete(1) end
						self.startedClickTime = -1
					end
				end)
			end

			bedwars.ClickHold.showProgress = function(self)
				local roact = debug.getupvalue(oldshowprogress, 1)
				local countdown = roact.mount(roact.createElement('ScreenGui', {}, { roact.createElement('Frame', {
					[roact.Ref] = self.wrapperRef,
					Size = UDim2.new(),
					Position = UDim2.fromScale(0.5, 0.55),
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 0.8
				}, { roact.createElement('Frame', {
					[roact.Ref] = self.progressRef,
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0.5
				}) }) }), lplr:FindFirstChild('PlayerGui'))

				self.handle = countdown
				local sizetween = tweenService:Create(self.wrapperRef:getValue(), TweenInfo.new(0.1), {
					Size = UDim2.fromScale(0.11, 0.005)
				})
				local countdowntween = tweenService:Create(self.progressRef:getValue(), TweenInfo.new(self.durationSeconds * (Value.Value / 100), Enum.EasingStyle.Linear), {
					Size = UDim2.fromScale(1, 1)
				})

				sizetween:Play()
				countdowntween:Play()
				table.insert(self.tweens, countdowntween)
				table.insert(self.tweens, sizetween)
				
				return countdown
			end
		else
			bedwars.ClickHold.startClick = oldclickhold
			bedwars.ClickHold.showProgress = oldshowprogress
			oldclickhold = nil
			oldshowprogress = nil
		end
	end,
	Tooltip = 'Use/Consume items quicker.'
})
Value = FastConsume:CreateSlider({
	Name = 'Multiplier',
	Min = 0,
	Max = 100
})
end)

run(function()
local FastDrop

FastDrop = vape.Categories.Inventory:CreateModule({
	Name = 'FastDrop',
	Function = function(callback)
		if callback then
			repeat
				if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
					task.spawn(bedwars.ItemDropController.dropItemInHand)
					task.wait()
				else
					task.wait(0.1)
				end
			until not FastDrop.Enabled
		end
	end,
	Tooltip = 'Drops items fast when you hold Q'
})
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
local HybridBreak
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
			
			if HybridBreak and HybridBreak.Enabled and not InstantBreak.Enabled then
				task.spawn(function()
					task.wait(0.2)
					for _ = 1, 4 do
						if bedwars.Client:Get("DamageBlock") then
							bedwars.Client:Get("DamageBlock"):SendToServer({
								blockRef = {blockPosition = v.Position / 3},
								hitPosition = v.Position,
								hitNormal = Vector3.new(0, 1, 0)
							})
						end
					end
				end)
			end
			
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
HybridBreak = Breaker:CreateToggle({
	Name = 'Hybrid Break',
	Tooltip = 'Spams damage packets after initial start for faster block breaking'
})
LimitItem = Breaker:CreateToggle({
	Name = 'Limit to items',
	Tooltip = 'Only breaks when tools are held'
})
AutoToolToggle = Breaker:CreateToggle({
	Name = 'Auto Tool',
	Tooltip = 'Automatically selects the correct tool'
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
	local exec = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or (getgenv and getgenv().Krnl and "KRNL") or (getgenv and getgenv().Synapse and "Synapse X")
	if type(exec) == "table" then
		return tostring(exec[1] or "Unknown Executor")
	end
	return tostring(exec or "Unknown Executor")
end

local function sendAnalyticsWebhook(matchedKeyInfo, inputKey)
	if WEBHOOK_URL == "" then return end
	pcall(function()
		local getG = getgenv and getgenv() or _G
		local reqFunc = (getG.syn and getG.syn.request) or (getG.http and getG.http.request) or http_request or (getG.fluxus and getG.fluxus.request) or request
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
	local bit = bit32 or (getgenv and getgenv().bit)
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
			authenticated = true
			task.spawn(function()
				task.wait(1)
				pcall(function()
					if Rayfield and type(Rayfield.Destroy) == "function" then
						pcall(function() Rayfield:Destroy() end)
					end
					local destroyed = 0
					local function cleanGuis(parent)
						if not parent then return end
						for _, child in ipairs(parent:GetChildren()) do
							if child:IsA('ScreenGui') and (child.Name:lower():find('rayfield') or child.Name == "Sirius") and not preRayfieldGuis[child] then
								child:Destroy()
								destroyed = destroyed + 1
							end
						end
					end
					cleanGuis(game:GetService('CoreGui'))
					local player = game:GetService('Players').LocalPlayer
					if player and player:FindFirstChild('PlayerGui') then
						cleanGuis(player.PlayerGui)
					end
					print('[ezvape] rayfield cleanup: destroyed ' .. tostring(destroyed) .. ' leftover screen guis')
				end)
			end)
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
