--[[
--	NEORG EVENT FILE
--	This file is responsible for dealing with event handling and broadcasting.
--	All modules that subscribe to an event will receive it once it is triggered.
--]]

-- Include the global instance of the logger
local log = require("neorg.external.log")

require("neorg.modules")
require("neorg.external.helpers")
require("neorg.callbacks")

neorg.events = {}

-- Define the base event, all events will derive from this by default
neorg.events.base_event = {

    type = "core.base_event",
    split_type = {},
    content = nil,
    referrer = nil,
    broadcast = true,

    cursor_position = {},
    filename = "",
    filehead = "",
    line_content = "",
}

-- @Summary Splits a full module event path into two
-- @Description The working of this function is best illustrated with an example:
--		If type == 'core.some_plugin.events.my_event', this function will return { 'core.some_plugin', 'my_event' }
-- @Param  type (string) - the full path of a module event
function neorg.events.split_event_type(type)
    local start_str, end_str = type:find("%.events%.")

    local split_event_type = { type:sub(0, start_str - 1), type:sub(end_str + 1) }

    if #split_event_type ~= 2 then
        log.warn("Invalid type name:", type)
        return
    end

    return split_event_type
end

-- @Summary Returns an event template as defined by a module
-- @Description Returns an event template defined in module.events.defined
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  type (string) - a full path to a valid event type (e.g. 'core.module.events.some_event')
function neorg.events.get_event_template(module, type)
    -- You can't get the event template of a type if the type isn't loaded
    if not neorg.modules.is_module_loaded(module.name) then
        log.info("Unable to get event of type", type, "with module", module.name)
        return
    end

    -- Split the event type into two
    local split_type = neorg.events.split_event_type(type)

    if not split_type then
        log.warn("Unable to get event template for event", type, "and module", module.name)
        return
    end

    log.trace("Returning", split_type[2], "for module", split_type[1])

    -- Return the defined event from the specific module
    return neorg.modules.loaded_modules[module.name].events.defined[split_type[2]]
end

-- @Summary Creates an event that derives from neorg.events.base_event
-- @Description Creates a deep copy of the neorg.events.base_event event and returns it with a custom type and referrer
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  name (string) - a relative path to a valid event template
function neorg.events.define(module, name)
    -- Create a copy of the base event and override the values with ones specified by the user

    local new_event = {}

    new_event = vim.deepcopy(neorg.events.base_event)

    if name then
        new_event.type = module.name .. ".events." .. name
    end

    new_event.referrer = module.name

    return new_event
end

-- @Summary Creates an instance of an event type
-- @Description Returns a copy of the event template provided by a module
-- @Param  module (table) - a reference to the module invoking the function
-- @Param  type (string) - a full path to a valid event type (e.g. 'core.module.events.some_event')
-- @Param  content (any) - the content of the event, can be anything from a string to a table to whatever you please
function neorg.events.create(module, type, content)
    -- Get the module that contains the event
    local module_name = neorg.events.split_event_type(type)[1]

    -- Retrieve the template from module.events.defined
    local event_template = neorg.events.get_event_template(
        neorg.modules.loaded_modules[module_name] or { name = "" },
        type
    )

    if not event_template then
        log.warn("Unable to create event of type", type, ". Returning nil...")
        return
    end

    local new_event = vim.deepcopy(event_template)

    new_event.type = type
    new_event.content = content
    new_event.referrer = module.name

    -- Override all the important values
    new_event.split_type = neorg.events.split_event_type(type)
    new_event.filename = vim.fn.expand("%:t")
    new_event.filehead = vim.fn.expand("%:p:h")
    new_event.cursor_position = vim.api.nvim_win_get_cursor(0)
    new_event.line_content = vim.api.nvim_get_current_line()
    new_event.referrer = module.name
    new_event.broadcast = true

    return new_event
end

-- @Summary Broadcasts an event
-- @Description Sends an event to all subscribed modules. The event contains the filename, filehead, cursor position and line content as a bonus.
-- @Param  event (table) - an event, usually created by neorg.events.create()
function neorg.events.broadcast_event(event)
    -- Broadcast the event to all modules
    if not event.split_type then
        log.error("Unable to broadcast event of type", event.type, "- invalid event name")
        return
    end

    -- Let the callback handler know of the event
    neorg.callbacks.handle_callbacks(event)

    -- Loop through all the modules
    for _, current_module in pairs(neorg.modules.loaded_modules) do
        -- If the current module has any subscribed events and if it has a subscription bound to the event's module name then
        if current_module.events.subscribed and current_module.events.subscribed[event.split_type[1]] then
            -- Check whether we are subscribed to the event type
            local evt = current_module.events.subscribed[event.split_type[1]][event.split_type[2]]

            if evt ~= nil and evt == true then
                -- Run the on_event() for that module
                current_module.on_event(event)
            end
        end
    end
end

-- @Summary Sends an event to an individual module
-- @Description Instead of broadcasting to all loaded modules, send_event() only sends to one module
-- @Param  module (table) - a reference to the module invoking the function. Used to verify the authenticity of the function call
-- @Param  recipient (string) - the name of a loaded module that will be the recipient of the event
-- @Param  event (table) - an event, usually created by neorg.events.create()
function neorg.events.send_event(recipient, event)
    -- If the recipient is not loaded then there's no reason to send an event to it
    if not neorg.modules.is_module_loaded(recipient) then
        log.warn("Unable to send event to module", recipient, "- the module is not loaded.")
        return
    end

    -- Set the broadcast variable to false since we're not invoking broadcast_event()
    event.broadcast = false

    -- Let the callback handler know of the event
    neorg.callbacks.handle_callbacks(event)

    -- Get the recipient module and check whether it's subscribed to our event
    local mod = neorg.modules.loaded_modules[recipient]

    if mod.events.subscribed and mod.events.subscribed[event.split_type[1]] then
        local evt = mod.events.subscribed[event.split_type[1]][event.split_type[2]]

        -- If it is then trigger the module's on_event() function
        if evt ~= nil and evt == true then
            mod.on_event(event)
        end
    end
end
