local module = {}

local _cameraCache = {}

function module.createCam(props)
  if not props then return end 

  local cam_folder = workspace.cam_folder
  if not cam_folder then 
    cam_folder = Instance.new("Folder")
    cam_folder.Name = "cams_folder"
  end

  for _, cam in ipairs(cam_folder:GetChildren()) do 
    if cam and cam:IsA("")
end

function module.get()
	for _, c in pairs(_cameraCache) do 
    if c and c.Parent then 
      local data = {
        Name = c.Name,
        CFrame = c.CFrame,
        Parent = c.Parent
      }
      return data 
    end
end

return module
