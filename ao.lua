-- require json module for data serialization
local json = require("json")

-- Initialize state to store time capsules
if not TimeCapsules then
  TimeCapsules = {}
end

-- Helper function to send a reply to the message sender
function Reply(msg, data, tags)
  tags = tags or {}
  if msg.reply then
    msg.reply({ Data = data, Tags = tags })
  else
    ao.send({
      Target = msg.From,
      Data = data,
      Tags = tags
    })
  end
end

-- Handler for creating a new time capsule
Handlers.add(
  "create-capsule",
  Handlers.utils.hasMatchingTag("Action", "CreateCapsule"),
  function(msg)
    -- Validate required fields
    if not msg.Tags["UnlockDate"] then
      return Reply(msg, json.encode({ success = false, error = "Missing unlock date" }))
    end
    
    -- Parse the message data which should contain capsule details
    local capsuleData
    local success, err = pcall(function()
      capsuleData = json.decode(msg.Data)
    end)
    
    if not success or not capsuleData then
      return Reply(msg, json.encode({ success = false, error = "Invalid capsule data format" }))
    end
    
    -- Generate a unique ID for the capsule
    local capsuleId = msg.From .. "-" .. os.time()
    
    -- Store the capsule
    TimeCapsules[capsuleId] = {
      id = capsuleId,
      owner = msg.From,
      message = capsuleData.message,
      unlockDate = msg.Tags["UnlockDate"],
      files = capsuleData.files or {},
      createdAt = os.time()
    }
    
    -- Return the capsule ID to the user
    Reply(msg, json.encode({ 
      success = true, 
      capsuleId = capsuleId 
    }))
  end
)

-- Handler for retrieving a time capsule
Handlers.add(
  "get-capsule",
  Handlers.utils.hasMatchingTag("Action", "GetCapsule"),
  function(msg)
    local capsuleId = msg.Tags["CapsuleId"]
    
    if not capsuleId or not TimeCapsules[capsuleId] then
      return Reply(msg, json.encode({ success = false, error = "Capsule not found" }))
    end
    
    local capsule = TimeCapsules[capsuleId]
    local currentTime = os.time()
    local unlockTime = tonumber(capsule.unlockDate)
    
    -- Fix: Ensure proper comparison of timestamps
    -- Check if the capsule is unlocked (current time must be >= unlock time)
    local isUnlocked = currentTime >= unlockTime
    
    -- If not unlocked, only return metadata
    if not isUnlocked then
      Reply(msg, json.encode({
        success = true,
        capsule = {
          id = capsule.id,
          unlockDate = capsule.unlockDate,
          isUnlocked = false,
          createdAt = capsule.createdAt
        }
      }))
    else
      -- If unlocked, return full capsule data
      Reply(msg, json.encode({
        success = true,
        capsule = {
          id = capsule.id,
          message = capsule.message,
          files = capsule.files,
          unlockDate = capsule.unlockDate,
          isUnlocked = true,
          createdAt = capsule.createdAt
        }
      }))
    end
  end
)

-- Handler for listing a user's capsules
Handlers.add(
  "list-capsules",
  Handlers.utils.hasMatchingTag("Action", "ListCapsules"),
  function(msg)
    local userCapsules = {}
    local currentTime = os.time()
    
    -- Find all capsules owned by the requesting user
    for id, capsule in pairs(TimeCapsules) do
      if capsule.owner == msg.From then
        -- Fix: Ensure proper comparison for isUnlocked status
        local unlockTime = tonumber(capsule.unlockDate)
        local isUnlocked = currentTime >= unlockTime
        
        table.insert(userCapsules, {
          id = capsule.id,
          unlockDate = capsule.unlockDate,
          createdAt = capsule.createdAt,
          isUnlocked = isUnlocked
        })
      end
    end
    
    Reply(msg, json.encode({
      success = true,
      capsules = userCapsules
    }))
  end
)

-- Handler for checking if a capsule exists
Handlers.add(
  "check-capsule",
  Handlers.utils.hasMatchingTag("Action", "CheckCapsule"),
  function(msg)
    local capsuleId = msg.Tags["CapsuleId"]
    
    if not capsuleId then
      return Reply(msg, json.encode({ success = false, error = "Missing capsule ID" }))
    end
    
    local exists = TimeCapsules[capsuleId] ~= nil
    
    Reply(msg, json.encode({
      success = true,
      exists = exists
    }))
  end
)