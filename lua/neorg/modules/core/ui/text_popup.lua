--[[
	File for creating text popups for the user.
--]]

local module = neorg.modules.extend("core.ui.text_popup")

module.public = {
    -- @Summary Creates a new interactable prompt
    -- @Description Opens a floating window at the specified position and asks for user input
    -- @Param  name (string) - the name of the floating window
    -- @Param  input_text (string) - the input text to prompt the user for input
    -- @Param  callback (function(entered_text)) - a function that gets invoked whenever the user provides some text.
    -- @Param  modifiers (table) - special table to modify certain attributes of the floating window (like centering on the x or y axis)
    -- @Param  config (table) - a config like you would pass into nvim_open_win()
    create_prompt = function(name, input_text, callback, modifiers, config)
        -- If the window already exists then don't create another one
        if module.private.windows[name] then
            return
        end

        -- Create the base cofiguration for the popup window
        local window_config = {
            relative = "win",
            style = "minimal",
            border = "rounded",
        }

        -- Apply any custom modifiers that the user has specified
        window_config = module.public.apply_custom_options(
            modifiers,
            vim.tbl_extend("force", window_config, config or {})
        )

        local buf = vim.api.nvim_create_buf(false, true)

        -- Set the buffer type to "prompt" to give it special behaviour (:h prompt-buffer)
        vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
        vim.api.nvim_buf_set_name(buf, name)

        -- Replace the "simplified" name the user provided with the actual buffer name
        name = vim.api.nvim_buf_get_name(buf)

        -- Create a callback to be invoked on prompt confirmation
        vim.fn.prompt_setcallback(buf, function(content)
            if content:len() > 0 then
                callback(content, {
                    close = function(opts)
                        vim.api.nvim_buf_delete(buf, opts or { force = true })
                    end,
                })
            end
        end)

        -- Make sure to clean up the window if the user leaves the popup at any time
        vim.cmd(
            (
                "autocmd WinLeave,BufLeave,BufDelete <buffer=%s> ++once lua require('neorg.modules.core.ui.module').public.delete_window(%s)"
            ):format(buf, buf)
        )

        -- Construct some custom mappings for the popup
        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":q<CR>", { silent = true, noremap = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "<Tab>", "<CR>", { silent = true, noremap = true })
        vim.api.nvim_buf_set_keymap(buf, "i", "<Tab>", "<CR>", { silent = true, noremap = true })
        vim.api.nvim_buf_set_keymap(buf, "i", "<C-c>", "<Esc>:q<CR>", { silent = true, noremap = true })

        -- If the use has specified some input text then show that input text in the buffer
        if input_text then
            vim.fn.prompt_setprompt(buf, input_text)
        end

        -- Automatically enter insert mode
        vim.api.nvim_feedkeys("i", "t", false)

        -- Create the floating popup window with the prompt buffer
        module.private.windows[name] = vim.api.nvim_open_win(buf, true, window_config)
    end,
}

return module
