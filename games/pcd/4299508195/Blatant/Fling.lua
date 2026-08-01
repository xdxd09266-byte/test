local Fling = {}
local moduleEnabled = false
local lplr = game.Players.LocalPlayer

-- Internal state
local flingParts = {}
local flingLoops = {}
local selectedTarget = nil

--=== HELPERS ===--

local function getChar(targetName)
    local p = game.Players:FindFirstChild(targetName) or (typeof(targetName) == "Instance" and targetName)
    if typeof(p) == "Instance" and p:IsA("Player") then
        return p.Character
    end
    return workspace:FindFirstChild(targetName)
end

local function getHRP(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
end

local function cleanupFling()
    for _, v in pairs(flingParts) do
        pcall(function() v:Destroy() end)
    end
    flingParts = {}
    for _, v in pairs(flingLoops) do
        pcall(function() v:Disconnect() end)
    end
    flingLoops = {}
end

--=== PLAYER FLING METHODS ===--

-- Method 1: BodyVelocity Weld Fling
-- Weld a part to the target's HRP, add high-velocity BodyVelocity
local function bodyVelocityFling(target, direction)
    local hrp = getHRP(target)
    if not hrp then return false end

    local p = Instance.new("Part")
    p.Size = Vector3.new(2, 2, 2)
    p.Anchored = false
    p.CanCollide = false
    p.Transparency = 1
    p.CFrame = hrp.CFrame
    p.Parent = workspace

    local weld = Instance.new("Weld")
    weld.Part0 = hrp
    weld.Part1 = p
    weld.C0 = CFrame.new(0, 0, 0)
    weld.Parent = p

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = direction * 1000
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.P = 10000
    bv.Parent = p

    table.insert(flingParts, p)
    return true
end

-- Method 2: AlignPosition Fling
-- Forces the target to a distant position instantly
local function alignFling(target, direction)
    local hrp = getHRP(target)
    if not hrp then return false end

    local a = Instance.new("AlignPosition")
    a.Parent = hrp
    a.MaxForce = 9e9
    a.MaxVelocity = 99999
    a.Responsiveness = 200
    a.RigidityEnabled = false
    a.Attachment0 = Instance.new("Attachment")
    a.Attachment0.Parent = hrp
    a.Attachment1 = Instance.new("Attachment")
    a.Attachment1.Parent = hrp
    a.Attachment1.WorldPosition = hrp.Position + direction * 9999

    table.insert(flingParts, a)
    table.insert(flingParts, a.Attachment0)
    table.insert(flingParts, a.Attachment1)

    -- Keep teleporting the target further
    local heart = game:GetService("RunService").Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then
            heart:Disconnect()
            return
        end
        a.Attachment1.WorldPosition = a.Attachment1.WorldPosition + direction * 500
    end)
    table.insert(flingLoops, heart)

    return true
end

-- Method 3: Resize Fling
-- Create parts inside torso, rapidly resize to clip through
local function resizeFling(target)
    local char = (typeof(target) == "Instance" and target:IsA("Model") and target) or nil
    if not char then return false end

    for _, bodyPart in pairs({"Head", "Torso", "UpperTorso", "LowerTorso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}) do
        local part = char:FindFirstChild(bodyPart) or char:FindFirstChild(bodyPart == "Torso" and "HumanoidRootPart" or nil)
        if part and part:IsA("BasePart") then
            local wedge = Instance.new("WedgePart")
            wedge.Size = Vector3.new(1, 1, 1)
            wedge.Anchored = false
            wedge.CanCollide = true
            wedge.Material = Enum.Material.Neon
            wedge.CFrame = part.CFrame
            wedge.Parent = workspace

            local weld = Instance.new("Weld")
            weld.Part0 = part
            weld.Part1 = wedge
            weld.C0 = CFrame.new(0, 0, 0)
            weld.Parent = wedge

            local heart = game:GetService("RunService").Heartbeat:Connect(function()
                if not wedge or not wedge.Parent then
                    heart:Disconnect()
                    return
                end
                local s = wedge.Size
                wedge.Size = Vector3.new(s.X + 5, s.Y + 5, s.Z + 5)
                if s.X > 200 then wedge.Size = Vector3.new(1, 1, 1) end
            end)

            table.insert(flingParts, wedge)
            table.insert(flingLoops, heart)
        end
    end
    return true
end

-- Method 4: ForceField Push (constant collision force)
local function forcePushFling(target, direction)
    local hrp = getHRP(target)
    if not hrp then return false end

    -- Create wall of parts pushing in direction
    for i = 1, 5 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(10, 10, 2)
        p.Anchored = true
        p.CanCollide = true
        p.Transparency = 0.5
        p.Material = Enum.Material.Neon
        p.BrickColor = BrickColor.Red()
        p.CFrame = hrp.CFrame + direction * (5 + i * 3)
        p.Parent = workspace

        local heart = game:GetService("RunService").Heartbeat:Connect(function()
            if not p or not p.Parent then
                heart:Disconnect()
                return
            end
            p.CFrame = p.CFrame + direction * 2
        end)

        table.insert(flingParts, p)
        table.insert(flingLoops, heart)
    end
    return true
end

--=== CAR FLING METHODS ===--

-- Method 1: BodyVelocity on Car
local function carVelocityFling(car, direction)
    local primary = car:FindFirstChild("HumanoidRootPart") or car:FindFirstChildWhichIsA("BasePart")
    if not primary then
        -- Try finding VehicleSeat
        for _, v in pairs(car:GetDescendants()) do
            if v:IsA("VehicleSeat") then
                primary = v:FindFirstChildWhichIsA("BasePart") or v
                break
            end
        end
    end
    if not primary then return false end

    local p = Instance.new("Part")
    p.Size = Vector3.new(3, 3, 3)
    p.Anchored = false
    p.CanCollide = false
    p.Transparency = 1
    p.CFrame = primary.CFrame
    p.Parent = workspace

    local weld = Instance.new("Weld")
    weld.Part0 = primary
    weld.Part1 = p
    weld.C0 = CFrame.new(0, 0, 0)
    weld.Parent = p

    local bv = Instance.new("BodyVelocity")
    bv.Velocity = direction * 1000
    bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.P = 10000
    bv.Parent = p

    table.insert(flingParts, p)
    return true
end

-- Method 2: Car Push Wall
local function carPushFling(car, direction)
    local primary = car:FindFirstChildWhichIsA("BasePart")
    if not primary then return false end

    for i = 1, 3 do
        local p = Instance.new("Part")
        p.Size = Vector3.new(15, 5, 3)
        p.Anchored = true
        p.CanCollide = true
        p.Transparency = 0.5
        p.Material = Enum.Material.Neon
        p.BrickColor = BrickColor.Red()
        p.CFrame = primary.CFrame + direction * (3 + i * 4)
        p.Parent = workspace

        local heart = game:GetService("RunService").Heartbeat:Connect(function()
            if not p or not p.Parent then
                heart:Disconnect()
                return
            end
            p.CFrame = p.CFrame + direction * 3
        end)

        table.insert(flingParts, p)
        table.insert(flingLoops, heart)
    end
    return true
end

-- Method 3: Car Seat Steal + Drive
local function carSeatSteal(car)
    local seat = car:FindFirstChild("DriveSeat", true) or car:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return false end

    local hum = lplr.Character and lplr.Character:FindFirstChildWhichIsA("Humanoid")
    if not hum then return false end

    -- Sit in the seat (steals it from current occupant)
    hum.Sit = true
    seat:Sit(hum)

    -- Control loop: drive forward at full speed
    local heart = game:GetService("RunService").Heartbeat:Connect(function()
        if not seat or not seat.Parent or not hum.Sit then
            heart:Disconnect()
            return
        end
        seat.Throttle = 1
        seat.Steer = 0
    end)
    table.insert(flingLoops, heart)

    return true
end

-- Method 4: Under-car lift fling
local function carLiftFling(car, direction)
    local primary = car:FindFirstChildWhichIsA("BasePart")
    if not primary then return false end

    -- Create floor push from below
    local p = Instance.new("Part")
    p.Size = Vector3.new(20, 2, 20)
    p.Anchored = true
    p.CanCollide = true
    p.Transparency = 0.5
    p.Material = Enum.Material.Neon
    p.Position = primary.Position - Vector3.new(0, 5, 0)
    p.Parent = workspace

    local heart = game:GetService("RunService").Heartbeat:Connect(function()
        if not p or not p.Parent then
            heart:Disconnect()
            return
        end
        p.Position = p.Position + direction * 2
    end)

    table.insert(flingParts, p)
    table.insert(flingLoops, heart)
    return true
end

--=== PUBLIC API ===--

-- Fling a player by name using all methods
function Fling.FlingPlayer(targetName)
    local target = getChar(targetName)
    if not target then
        warn("Fling: Target not found:", targetName)
        return
    end

    local dirs = {
        Vector3.new(0, 1, 0),    -- up
        Vector3.new(1, 0.5, 0),  -- up-right
        Vector3.new(-1, 0.5, 0), -- up-left
        Vector3.new(0, 0.5, 1),  -- up-forward
        Vector3.new(0, 0.5, -1), -- up-back
    }

    for _, dir in pairs(dirs) do
        bodyVelocityFling(target, dir)
        task.wait(0.1)
    end

    alignFling(target, Vector3.new(0, 1, 0))
    resizeFling(target)
    forcePushFling(target, Vector3.new(0, 1, 0))
    forcePushFling(target, Vector3.new(1, 0.5, 0))
    forcePushFling(target, Vector3.new(-1, 0.5, 0))
end

-- Fling a car by owner name
function Fling.FlingCar(ownerName)
    local car = workspace.Cars and workspace.Cars:FindFirstChild(ownerName)
    if not car then
        warn("Fling: Car not found for:", ownerName)
        return
    end

    local dirs = {
        Vector3.new(0, 1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1),
    }

    for _, dir in pairs(dirs) do
        carVelocityFling(car, dir)
        task.wait(0.1)
    end

    carPushFling(car, Vector3.new(0, 1, 0))
    carPushFling(car, Vector3.new(1, 0, 0))
    carPushFling(car, Vector3.new(-1, 0, 0))
    carLiftFling(car, Vector3.new(0, 1, 0))
end

-- Fling ALL nearby players
function Fling.FlingAll()
    for _, p in pairs(game.Players:GetPlayers()) do
        if p ~= lplr then
            local char = getChar(p.Name)
            if char then
                bodyVelocityFling(char, Vector3.new(0, 1, 0))
                task.wait(0.05)
            end
        end
    end
end

-- Fling ALL nearby cars
function Fling.FlingAllCars()
    if not workspace.Cars then return end
    for _, car in pairs(workspace.Cars:GetChildren()) do
        carVelocityFling(car, Vector3.new(0, 1, 0))
        task.wait(0.05)
    end
end

-- Steal a specific car's seat
function Fling.StealCar(ownerName)
    local car = workspace.Cars and workspace.Cars:FindFirstChild(ownerName)
    if not car then
        warn("Fling: No car found for:", ownerName)
        return false
    end
    return carSeatSteal(car)
end

-- Combo: Fling a player + their car simultaneously
function Fling.FlingBoth(targetName)
    -- Fling the player
    Fling.FlingPlayer(targetName)
    -- Fling their car at the same time
    local car = workspace.Cars and workspace.Cars:FindFirstChild(targetName)
    if car then
        for _, dir in pairs({
            Vector3.new(0, 1, 0),
            Vector3.new(1, 0.5, 0),
            Vector3.new(-1, 0.5, 0),
        }) do
            carVelocityFling(car, dir)
            carPushFling(car, dir)
            task.wait(0.05)
        end
    end
end

-- Start auto-flinging nearby players + cars
function Fling.Start()
    if moduleEnabled then return end
    moduleEnabled = true

    spawn(function()
        while moduleEnabled do
            for _, p in pairs(game.Players:GetPlayers()) do
                if p ~= lplr then
                    local char = getChar(p.Name)
                    if char then
                        bodyVelocityFling(char, Vector3.new(0, 1, 0))
                    end

                    local car = workspace.Cars and workspace.Cars:FindFirstChild(p.Name)
                    if car then
                        carVelocityFling(car, Vector3.new(0, 1, 0))
                    end
                end
                task.wait(0.3)
            end
            task.wait(1)
        end
    end)
end

function Fling.Stop()
    moduleEnabled = false
    cleanupFling()
end

return Fling
