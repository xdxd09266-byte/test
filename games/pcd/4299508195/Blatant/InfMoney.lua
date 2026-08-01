local InfMoney = {}
local moduleEnabled = false
local lplr = game.Players.LocalPlayer
local rs = game:GetService("ReplicatedStorage")

local function getMoney()
    return lplr.leaderstats and lplr.leaderstats.Money and lplr.leaderstats.Money.Value or 0
end

-- Approach 1: sell_car spam (sell car repeatedly)
local function trySellCarExploit()
    local sellCar = rs:FindFirstChild("sell_car")
    if not sellCar then return false end
    local myCar = workspace.Cars:FindFirstChild(lplr.Name)
    if not myCar then return false end
    
    for i = 1, 10 do
        pcall(function() sellCar:FireServer(lplr.Name) end)
        task.wait()
    end
    return true
end

-- Approach 2: finish remote spam (fake job completion)
local function tryFinishExploit()
    local finish = rs:FindFirstChild("finish")
    if not finish then return false end
    
    for i = 1, 20 do
        pcall(function()
            finish:FireServer({[1] = "Complete", job = "taxi", amount = 99999})
            finish:FireServer("Complete")
            finish:FireServer(999999)
        end)
        task.wait(0.1)
    end
    return true
end

-- Approach 3: GiveCurrency spam with various payloads
local function tryGiveCurrencyExploit()
    local giveCurrency = rs.JobSystem and rs:FindFirstChild("JobSystem").GiveCurrency
    if not giveCurrency then return false end
    
    for i = 1, 10 do
        pcall(function()
            giveCurrency:FireServer(999999)
            giveCurrency:FireServer({amount = 999999, reason = "job"})
            giveCurrency:FireServer({currency = "Money", amount = 999999})
            giveCurrency:FireServer(lplr, 999999)
        end)
        task.wait(0.1)
    end
    return true
end

-- Approach 4: ZmianaPostepu (Progress Change) exploit
local function tryProgressExploit()
    local zmiana = rs:FindFirstChild("ZmianaPostepu")
    if not zmiana then return false end
    
    for i = 1, 10 do
        pcall(function()
            zmiana:FireServer({progress = 100, complete = true})
            zmiana:FireServer("DeliverPackage", 100)
            zmiana:FireServer("TaxiMission", 100)
        end)
        task.wait(0.1)
    end
    return true
end

-- Approach 5: Dealership buy/sell loop exploit
local function tryDealershipExploit()
    local dealership = rs.Remotes and rs.Remotes:FindFirstChild("Dealership")
    if not dealership then return false end
    
    for i = 1, 10 do
        pcall(function()
            dealership:FireServer("Sell", lplr.Name)
            dealership:FireServer("Refund", lplr.Name)
            dealership:FireServer("BuyBack", lplr.Name)
        end)
        task.wait(0.1)
    end
    return true
end

-- Approach 6: paintshop refund exploit
local function tryPaintExploit()
    local paintshop = rs:FindFirstChild("paintshop")
    if not paintshop then return false end
    
    for i = 1, 10 do
        pcall(function()
            paintshop:FireServer("Refund", "all")
            paintshop:FireServer("RefundAll")
            paintshop:FireServer({action = "refund", item = "all"})
        end)
        task.wait(0.1)
    end
    return true
end

-- Monitor money changes and log successful exploits
local moneyCon
local function startMonitor()
    if moneyCon then moneyCon:Disconnect() end
    moneyCon = lplr.leaderstats.Money:GetPropertyChangedSignal("Value"):Connect(function()
        if getMoney() > 1000 then
            warn("InfMoney: Money changed to " .. getMoney())
        end
    end)
end

-- Auto-execute all methods in a loop
local function runAll()
    while moduleEnabled do
        local before = getMoney()
        
        tryFinishExploit()
        tryGiveCurrencyExploit()
        tryProgressExploit()
        tryDealershipExploit()
        tryPaintExploit()
        trySellCarExploit()
        
        if getMoney() > before then
            warn("InfMoney: +" .. (getMoney() - before) .. " money!")
        end
        
        task.wait(3)
    end
end

-- Visual-only: hook leaderstats display (no crash metatable approach)
local function visualOnly()
    -- Simply spam the remote approaches and hope one sticks
    spawn(function()
        while moduleEnabled do
            tryFinishExploit()
            tryGiveCurrencyExploit()
            tryProgressExploit()
            tryDealershipExploit()
            tryPaintExploit()
            task.wait(2)
        end
    end)
end

function InfMoney.Start()
    if moduleEnabled then return end
    moduleEnabled = true
    startMonitor()
    
    warn("InfMoney: Running all exploit methods...")
    visualOnly()
    
    -- Also attempt sell_car every 5 seconds if we have a car
    spawn(function()
        while moduleEnabled do
            trySellCarExploit()
            task.wait(5)
        end
    end)
end

function InfMoney.Stop()
    moduleEnabled = false
    if moneyCon then
        moneyCon:Disconnect()
        moneyCon = nil
    end
end

return InfMoney
