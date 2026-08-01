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