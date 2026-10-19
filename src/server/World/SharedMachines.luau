--!strict
-- The one Neon maker and one Mega maker for the server.

local SharedMachines = {}

local models: { [string]: Model } = {}

function SharedMachines.set(id: string, model: Model)
	models[id] = model
end

function SharedMachines.all(): { [string]: Model }
	return models
end

return SharedMachines
