local FactorySearchAction = {}

local INTERFACE = "factory-search"
-- The interop version this action was written against (Factory Search 1.15.0). Another
-- value means Factory Search may have changed its interface, so the action hides itself
-- rather than call it.
local INTEROP_VERSION = 1

local function product_signal(product)
  if type(product) == "table" and (product.type == "item" or product.type == "fluid") then
    return { type = product.type, name = product.name }
  end
  return nil
end

--- The SignalID Factory Search should search for a candidate.
---
--- A recipe and a resource are mapped the way Factory Search maps them for its own
--- "search the prototype under the cursor" input: a recipe to its main product, or to
--- its only product, and a resource to its first mineable product. No quality is set,
--- so Factory Search's own "all qualities" toggle stays in effect.
---@param candidate table
---@return table|nil  a SignalID; nil when the candidate names no item or fluid
function FactorySearchAction.resolve_signal(candidate)
  if candidate.type == "item" or candidate.type == "fluid" then
    return { type = candidate.type, name = candidate.id }
  elseif candidate.type == "recipe" then
    local recipe = prototypes.recipe[candidate.id]
    if recipe == nil then
      return nil
    end
    local signal = product_signal(recipe.main_product)
    if signal == nil and #recipe.products == 1 then
      signal = product_signal(recipe.products[1])
    end
    return signal
  elseif candidate.type == "resource" then
    local entity = prototypes.entity[candidate.resource_name]
    local mineable = entity and entity.mineable_properties
    local products = mineable and mineable.products
    if products == nil then
      return nil
    end
    return product_signal(products[1])
  end
  return nil
end

--- True when Factory Search's remote interface is loaded and speaks the interop version
--- this action was written against.
---@param caller table  an object with has(interface, fn) and call(interface, fn, ...)
---@return boolean
function FactorySearchAction.interface_ready(caller)
  if not (caller:has(INTERFACE, "search") and caller:has(INTERFACE, "interop_version")) then
    return false
  end
  return caller:call(INTERFACE, "interop_version") == INTEROP_VERSION
end

-- The seam interface_ready's spec replaces: `remote` does not exist under busted.
local remote_caller = {
  has = function(_, interface_name, function_name)
    local functions = remote.interfaces[interface_name]
    return functions ~= nil and functions[function_name] == true
  end,
  call = function(_, interface_name, function_name, ...)
    return remote.call(interface_name, function_name, ...)
  end,
}

-- interface_ready can only change when the mod set changes, and that reloads the Lua
-- state, so this cache is never stale; it is also the same on every peer, so it stays
-- desync-safe despite living outside storage.
local ready = nil

-- Whether Factory Search answers is the same for every candidate, so it gates here;
-- whether one candidate maps to an item or fluid is resolved and reported by execute.
local function is_available(_player_index)
  if ready == nil then
    ready = FactorySearchAction.interface_ready(remote_caller)
  end
  return ready
end

-- Returns a message for Quidquid to show (contract 3) when there is nothing to search.
local function execute(candidate, player_index)
  local player = game.get_player(player_index)
  if player == nil then
    return nil
  end
  local signal = FactorySearchAction.resolve_signal(candidate)
  if signal == nil then
    return { "quidquid-factory-search.unavailable" }
  end
  -- Factory Search's search takes the LuaPlayer itself, not its index.
  remote.call(INTERFACE, "search", player, signal)
  return nil
end

--- Adds the remote interface that prototypes/actions.lua names.
function FactorySearchAction.add_interface()
  remote.add_interface("quidquid-factory-search", { execute = execute, is_available = is_available })
end

return FactorySearchAction
