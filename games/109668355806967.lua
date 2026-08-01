local vape = shared.vape
local entitylib = vape.Libraries.entity
local targetinfo = vape.Libraries.targetinfo
local uis = game:GetService("UserInputService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local lplr = players.LocalPlayer
local workspace = game:GetService("Workspace")

local hoplex = {}

-- Load modules here or define game-specific API

return hoplex


run(function()
	local MaceAura = {}
	local runService = game:GetService("RunService")
	local players = game:GetService("Players")
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local lplr = players.LocalPlayer
	
	local function getUnifiedRemote()
	    local lib = replicatedStorage:FindFirstChild("dataLibrary40")
	    if lib then
	        return lib:FindFirstChild("RemotezcuWd")
	    end
	    return nil
	end
	
	local function getTarget(range)
	    local target = nil
	    local shortestDist = range
	    local lpChar = lplr.Character
	    if not lpChar or not lpChar:FindFirstChild("HumanoidRootPart") then return nil end
	    local lpPos = lpChar.HumanoidRootPart.Position
	
	    for _, plr in pairs(players:GetPlayers()) do
	        if plr ~= lplr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") then
	            if plr.Character.Humanoid.Health > 0 then
	                local dist = (plr.Character.HumanoidRootPart.Position - lpPos).Magnitude
	                if dist < shortestDist then
	                    target = plr
	                    shortestDist = dist
	                end
	            end
	        end
	    end
	    return target
	end
	
	local maceAuraConnection
	local lastAttack = 0
	local MaceAuraOptions = {
	    Range = {Value = 18},
	    FaceTarget = {Enabled = true},
	    Speed = {Value = 5} -- Hits per second
	}
	
	shared.mainapi.CreateModule({
	    Name = "MaceAura",
	    Category = "Blatant",
	    Function = function(callback)
	        if callback then
	            local remote = getUnifiedRemote()
	            if not remote then 
	                shared.mainapi.CreateNotification("MaceAura", "Network remote not found!", 5)
	                return
	            end
	
	            maceAuraConnection = runService.Heartbeat:Connect(function()
	                local target = getTarget(MaceAuraOptions.Range.Value)
	                if target then
	                    -- Face target
	                    if MaceAuraOptions.FaceTarget.Enabled and lplr.Character and lplr.Character:FindFirstChild("HumanoidRootPart") then
	                        local lookVector = CFrame.new(lplr.Character.HumanoidRootPart.Position, target.Character.HumanoidRootPart.Position)
	                        lplr.Character.HumanoidRootPart.CFrame = lookVector
	                    end
	
	                    -- Attack based on speed
	                    local currentTime = os.clock()
	                    if currentTime - lastAttack >= (1 / MaceAuraOptions.Speed.Value) then
	                        lastAttack = currentTime
	                        local lpChar = lplr.Character
	                        if lpChar and lpChar:FindFirstChild("HumanoidRootPart") then
	                            local lookDir = (target.Character.HumanoidRootPart.Position - lpChar.HumanoidRootPart.Position).Unit
	                            local meta = {
	                                capturedAt = workspace:GetServerTimeNow(),
	                                lookDirection = lookDir,
	                                selectedSlot = 1
	                            }
	                            -- Spoof swing and hit packets
	                            remote:FireServer("InvokeSwing", "Main", meta)
	                            remote:FireServer("InvokeHitCharacter", target.Character, meta, "HumanoidRootPart", "Main")
	                        end
	                    end
	                end
	            end)
	        else
	            if maceAuraConnection then
	                maceAuraConnection:Disconnect()
	                maceAuraConnection = nil
	            end
	        end
	    end
	})
	
	return MaceAura
	
end)