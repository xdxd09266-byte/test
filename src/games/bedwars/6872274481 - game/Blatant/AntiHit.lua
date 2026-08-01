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
