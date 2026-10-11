-- Luau | client executor | Rivals muzzle redirect hook
-- delete script lama, paste ni terus dalam executor

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera

local CFG = {
    fov         = 150,
    smooth      = 0.25,
    pred_factor = 0.07,
    key         = Enum.KeyCode.Q,
    hitbox      = "HumanoidRootPart",
    team_check  = true,
}

local function same_team(p)
    if not CFG.team_check then return false end
    return lp.Team and p.Team and lp.Team == p.Team
end

local function get_target()
    local best, dist = nil, CFG.fov
    for _, p in ipairs(Players:GetPlayers()) do
        if p == lp or same_team(p) then continue end
        local char = p.Character
        if not char then continue end
        local root = char:FindFirstChild(CFG.hitbox)
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then continue end
        local vel  = root.AssemblyLinearVelocity
        local pred = root.Position + vel * CFG.pred_factor
        local screen, vis = cam:WorldToScreenPoint(pred)
        if not vis then continue end
        local d = (Vector2.new(screen.X, screen.Y)
                 - Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)).Magnitude
        if d < dist then dist = d; best = { root = root, pred = pred } end
    end
    return best
end

local ViewModels = workspace:FindFirstChild("ViewModels")

local function get_muzzle_attachments()
    local found = {}
    if not ViewModels then return found end
    for _, model in ipairs(ViewModels:GetDescendants()) do
        if model.Name == "_muzzle" and model:IsA("Attachment") then
            table.insert(found, model)
        end
    end
    return found
end

local stored_cframes = {}

RunService:BindToRenderStep("rivals_muzzle_aim", Enum.RenderPriority.Camera.Value + 1, function()
    if not UserInputService:IsKeyDown(CFG.key) then
        for att, cf in pairs(stored_cframes) do
            pcall(function() att.CFrame = cf end)
        end
        stored_cframes = {}
        return
    end

    local t = get_target()
    if not t then return end

    local muzzles = get_muzzle_attachments()

    for _, att in ipairs(muzzles) do
        if not stored_cframes[att] then
            stored_cframes[att] = att.CFrame
        end
        local origin = att.WorldPosition
        local dir    = (t.pred - origin).Unit
        local parent = att.Parent
        if parent and parent:IsA("BasePart") then
            local world_cf = CFrame.lookAt(origin, origin + dir)
            pcall(function()
                att.CFrame = parent.CFrame:ToObjectSpace(world_cf)
            end)
        end
    end

    local origin_cam = cam.CFrame.Position
    local dir_cam    = (t.pred - origin_cam).Unit
    cam.CFrame = cam.CFrame:Lerp(
        CFrame.lookAt(origin_cam, origin_cam + dir_cam),
        CFG.smooth
    )
end)

lp.CharacterRemoving:Connect(function()
    RunService:UnbindFromRenderStep("rivals_muzzle_aim")
end)

print("[rivals_muzzle_aim] live | hold Q untuk lock")
