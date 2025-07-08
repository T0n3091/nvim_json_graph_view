---@diagnostic disable: undefined-global

local M = {
    expanded = {},
    config = {
        accept_all_files = false,
        max_lines = 5,
        keymaps = {
            expand = "E",
            link_forward = "L",
            link_backward = "B",
            set_as_root = "R",
        }
    },
    render_info = {},
    plugin_name = "JsonGraphView"
}

local EDGE = {
    TOP_LEFT = "┬",
    TOP_LEFT_ROOT = "╭",
    TOP_RIGHT = "╮",
    BOTTOM_LEFT = "╰",
    BOTTOM_RIGHT = "╯",
    TOP_AND_BOTTOM = "─",
    LEFT_AND_RIGHT = "│",
    TOP_SPLITTER = "┬",
    BOTTOM_SPLITTER = "┴",
    CONNECTION = "├"
}

local LINE = {
    TURN_SIDE_FU = "╭",
    TURN_DOWN = "╮",
    TURN_SIDE_FD = "╰",
    TURN_UP = "╯",
    SIDE = "─",
    CROSS = "┼",
    UP_DOWN = "│",
}

local function utf8len(str)
    local _, count = string.gsub(str, "[^\128-\191]", "")
    return count
end

local function escape_string(str)
    return str
        :gsub("\\", "\\\\")
        :gsub("\n", "\\n")
        :gsub("\t", "\\t")
        :gsub("\r", "\\r")
        :gsub("\"", "\\\"")
end

local function appended_table(tbl, add)
    local new = {}

    for k, v in pairs(tbl) do
        new[k] = v
    end

    new[#new + 1] = add

    return new
end

M.GetValAsString = function(val)
    if val == vim.NIL then
        return "null"
    elseif val == vim.empty_dict() then
        return "{}"
    elseif type(val) == "string" then
        return '"' .. escape_string(val) .. '"'
    elseif type(val) == "number" then
        return tostring(val)
    elseif type(val) == "boolean" then
        return tostring(val)
    elseif type(val) == "table" then
        if vim.islist(val) then
            return "[]"
        else
            return "{}"
        end
    end
end

M.GetLenOfValue = function(val)
    if val == vim.NIL then
        return 4
    elseif type(val) == "string" then
        return #val + 2
    elseif type(val) == "number" then
        return #tostring(val)
    elseif type(val) == "boolean" then
        if val then
            return 4
        else
            return 5
        end
    elseif type(val) == "table" then
        return 2
    end
end

M.BuildBoxCap = function(top, max_len_left, first, origin, json_obj, key_set)
    local left
    local right
    local splitter
    local callbacks

    if top then
        if first then
            left = EDGE.TOP_LEFT_ROOT
            callbacks = { {
                M.config.keymaps.link_backward,
                function(opts)
                    M.RenderGraph(opts.json_obj, opts.editor_buf, { opts.editor_buf })
                    M.CursorToRoot()
                end
            } }
        else
            left = EDGE.TOP_LEFT
            callbacks = {
                {
                    M.config.keymaps.link_backward,
                    function(opts)
                        M.JumpToLink(origin[1], origin[2], opts.render_info, true)
                    end
                },
                {
                    M.config.keymaps.set_as_root,
                    function(opts)
                        M.RenderGraph(json_obj, opts.editor_buf, key_set)
                    end
                }
            }
        end

        right = EDGE.TOP_RIGHT
        splitter = EDGE.TOP_SPLITTER
    else
        left = EDGE.BOTTOM_LEFT
        right = EDGE.BOTTOM_RIGHT
        splitter = EDGE.BOTTOM_SPLITTER
    end

    return {
        left .. string.rep(EDGE.TOP_AND_BOTTOM, max_len_left) .. splitter,
        EDGE.TOP_AND_BOTTOM,
        right,
        callbacks
    }
end

M.IsExpanded = function(key_set, dict)
    if dict == nil then
        dict = M.expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            return nil
        end

        dict = dict[key]

        if idx == #key_set then
            return dict[0]
        end
    end
end

M.SetExpanded = function(key_set, val, dict)
    if dict == nil then
        dict = M.expanded
    end

    for idx, key in pairs(key_set) do
        if dict[key] == nil then
            dict[key] = {}
        end

        dict = dict[key]

        if idx == #key_set then
            dict[0] = val
        end
    end
end

M.JumpToLink = function(layer, row, render_info, jump_to_word)
    local col = render_info.col_idxs[layer]
    vim.api.nvim_win_set_cursor(0, { 2, col })

    if row ~= 1 then
        vim.cmd("normal! " .. (row - 1) .. "j")
    end

    if jump_to_word then
        vim.cmd("call search('\\S')")
    end
end

M.TableObject = function(json_obj, out_table, layer_idx, key_set, from_row)
    if out_table[layer_idx] == nil then
        out_table[layer_idx] = { lines = 0, width = 0, boxes = {} }
    end

    local layer = out_table[layer_idx]

    local max_len_left = 0
    local max_len_right = 2
    local text_lines = {}
    local connections = {}

    for key, val in pairs(json_obj) do
        max_len_left = math.max(max_len_left, #tostring(key))
        max_len_right = math.max(max_len_right, M.GetLenOfValue(val))
    end

    layer.width = math.max(layer.width, max_len_left + max_len_right + 3)
    text_lines[#text_lines + 1] = M.BuildBoxCap(
        true,
        max_len_left,
        layer_idx == 1,
        { layer_idx - 1, from_row },
        json_obj,
        key_set
    )

    local line = 1
    for key, val in pairs(json_obj) do
        local left_edge = EDGE.LEFT_AND_RIGHT
        if line == M.config.max_lines + 1 then
            left_edge = "╪"
        end

        if line > M.config.max_lines and (not M.IsExpanded(key_set)) then
            text_lines[#text_lines + 1] = {
                left_edge,
                ".",
                EDGE.LEFT_AND_RIGHT,
                {
                    {
                        M.config.keymaps.expand,
                        function(opts)
                            vim.print(key_set)
                            M.SetExpanded(key_set, true)
                            M.RenderGraph(opts.render_info.shown_obj, opts.editor_buf, opts.render_info.shown_key_set)
                        end
                    }
                }
            }
            break
        else
            line = line + 1

            local collapse_callback
            if line > M.config.max_lines + 1 then
                collapse_callback = {
                    M.config.keymaps.expand,
                    function(opts)
                        vim.print(key_set)
                        M.SetExpanded(key_set, false)
                        M.RenderGraph(opts.render_info.shown_obj, opts.editor_buf, opts.render_info.shown_key_set)
                    end
                }
            end

            local string_key = tostring(key)
            local left = left_edge ..
                string.rep(" ", max_len_left - #string_key) .. string_key .. EDGE.LEFT_AND_RIGHT
            local right = M.GetValAsString(val)

            if right == "{}" or right == "[]" then
                local from = layer.lines + #text_lines + 1
                local to = M.TableObject(val, out_table, layer_idx + 1, appended_table(key_set, key), from)
                text_lines[#text_lines + 1] = {
                    left, "·", right .. EDGE.CONNECTION,
                    {
                        {
                            M.config.keymaps.link_forward,
                            function(opts)
                                M.JumpToLink(layer_idx + 1, to, opts.render_info, false)
                            end
                        },
                        collapse_callback
                    }
                }

                connections[#connections + 1] = {
                    from = from,
                    to = to
                }
            else
                text_lines[#text_lines + 1] = { left, "·", right .. EDGE.LEFT_AND_RIGHT, { collapse_callback } }
            end
        end
    end

    text_lines[#text_lines + 1] = M.BuildBoxCap(false, max_len_left)

    layer.boxes[#layer.boxes + 1] = { connections = connections, text_lines = text_lines, top_line = layer.lines + 1 }
    layer.lines = layer.lines + #text_lines
    return layer.boxes[#layer.boxes].top_line
end

M.ApplyHighlighting = function()
    vim.cmd([[highlight MyOperators guifg=#009900]])

    vim.cmd("syn region String start=+\"+ skip=+\\\\\\\\\\|\\\\\"+ end=+\"+ contains=@Spell")
    vim.cmd([[syn match Identifier /│\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd([[syn match Identifier /╪\s*\zs\w\+\ze\s*│/ contains=@Spell]])
    vim.cmd("syn keyword Keyword null")
    vim.cmd("syn match MyOperators \"[{}\\[\\]]\"")
    vim.cmd("syn match MyOperators \"\\.\"")
    vim.cmd([[syn match Comment "·"]])
    vim.cmd("syn keyword Boolean true false")
    vim.cmd("syn match Number \"[-+]\\=\\%(0\\|[1-9]\\d*\\)\\%(\\.\\d*\\)\\=\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=\\%(\\.\\d\\+\\)\\%([eE][-+]\\=\\d\\+\\)\\=\"")
    vim.cmd("syn match Number \"[-+]\\=0[xX]\\x*\"")
    vim.cmd("syn match Number \"[-+]\\=Infinity\\|NaN\"")
end

M.BuildConnectionsForLayer = function(connections, grid_height)
    local grid = {}
    local grid_cols = 0

    local function add_col_to_grid()
        grid_cols = grid_cols + 1
        for i = 1, grid_height do
            if grid[i] == nil then
                grid[i] = {}
            end

            grid[i][grid_cols] = " "
        end
    end

    local up_cons = {}
    local down_cons = {}
    local flat_cons = {}
    for _, con in pairs(connections) do
        if con.from < con.to then
            down_cons[#down_cons + 1] = con
        elseif con.from > con.to then
            up_cons[#up_cons + 1] = con
        else
            flat_cons[#flat_cons + 1] = con
        end
    end

    for _ = 1, math.max(#up_cons, #down_cons) + 2 do
        add_col_to_grid()
    end

    for _, con in pairs(flat_cons) do
        local col = 1
        while col <= grid_cols do
            grid[con.from][col] = LINE.SIDE
            col = col + 1
        end
    end

    for i = #down_cons, 1, -1 do
        local con = down_cons[i]
        local row = con.from
        local col = 1
        local target = con.to

        local last_was_right = true
        while row ~= target or col ~= grid_cols + 1 do
            local new_is_right
            local new_row
            local new_col

            if row < target
                and grid[row + 1][col] == " "
            then
                new_row = row + 1
                new_col = col
                new_is_right = false
            else
                new_col = col + 1
                new_row = row
                new_is_right = true
            end

            local char
            if last_was_right and new_is_right then
                if grid[row][col] == LINE.UP_DOWN then
                    char = LINE.CROSS
                else
                    char = LINE.SIDE
                end
            elseif last_was_right and (not new_is_right) then
                char = LINE.TURN_DOWN
            elseif (not last_was_right) and new_is_right then
                char = LINE.TURN_SIDE_FD
            else
                if grid[row][col] == LINE.SIDE then
                    char = LINE.CROSS
                else
                    char = LINE.UP_DOWN
                end
            end

            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col
        end
    end

    for i = 1, #up_cons do
        local con = up_cons[i]
        local row = con.from
        local col = 1
        local target = con.to

        local last_was_right = true
        while row ~= target or col ~= grid_cols + 1 do
            local new_is_right
            local new_row
            local new_col


            if row > target
                and grid[row - 1][col] == " "
            then
                new_row = row - 1
                new_col = col
                new_is_right = false
            else
                new_col = col + 1
                new_row = row
                new_is_right = true
            end

            local char
            if last_was_right and new_is_right then
                if grid[row][col] == LINE.UP_DOWN then
                    char = LINE.CROSS
                else
                    char = LINE.SIDE
                end
            elseif last_was_right and (not new_is_right) then
                char = LINE.TURN_UP
            elseif (not last_was_right) and new_is_right then
                char = LINE.TURN_SIDE_FU
            else
                if grid[row][col] == LINE.SIDE then
                    char = LINE.CROSS
                else
                    char = LINE.UP_DOWN
                end
            end


            grid[row][col] = char
            last_was_right = new_is_right
            row = new_row
            col = new_col
        end
    end

    return grid
end

M.BuildConnections = function(output_table)
    local connections = {}

    local layer_grid_height = 0
    for _, layer in pairs(output_table) do
        layer_grid_height = math.max(layer_grid_height, layer.lines)
    end

    for layer_id, layer in pairs(output_table) do
        local layer_connections = {}
        for _, box in pairs(layer.boxes) do
            for _, connection in pairs(box.connections) do
                layer_connections[#layer_connections + 1] = connection
            end
        end

        connections[layer_id] = M.BuildConnectionsForLayer(layer_connections, layer_grid_height)
    end

    return connections
end

M.RenderGraph = function(json_obj, editor_buf, key_set)
    local text_output_table = {}
    local render_info = { line_callbacks = {}, shown_obj = json_obj, shown_key_set = key_set }
    M.TableObject(json_obj, text_output_table, 1, key_set)
    local connections = M.BuildConnections(text_output_table)

    local output_lines = {}
    local line = 1
    local any = true

    while any do
        local lines = {}
        any = false
        for col_idx, col in pairs(text_output_table) do
            local text_line
            if line > col.lines then
                text_line = { string.rep(" ", col.width), {} }
            else
                any = true
                local b_line = line
                for _, box in pairs(col.boxes) do
                    if b_line - #box.text_lines <= 0 then
                        text_line = box.text_lines[b_line]

                        local left, fill, right = text_line[1], text_line[2], text_line[3]

                        local conjoined = left .. right
                        local utf8len_ = utf8len(conjoined)

                        if text_line[4] then
                            local len = string.len(conjoined)
                            text_line[4].limit = len + (col.width - utf8len_) * string.len(fill)
                        end

                        text_line = {
                            left
                            .. string.rep(fill, col.width - utf8len_)
                            .. right, text_line[4]
                        }

                        break
                    end

                    b_line = b_line - #box.text_lines
                end
            end

            local col_connections = connections[col_idx]
            if col_connections ~= nil then
                local section_connection = col_connections[line]
                if section_connection ~= nil then
                    text_line[1] = text_line[1] .. table.concat(section_connection)
                    any = true
                end
            end

            lines[#lines + 1] = text_line
        end

        local set_render_info = render_info.col_idxs == nil

        if set_render_info then
            render_info.col_idxs = {}
        end

        local current_line_callbacks = {}
        local text_line = ""
        for _, section in pairs(lines) do
            local start = string.len(text_line)
            if current_line_callbacks[start] == nil then
                current_line_callbacks[start] = {}
            end

            if section[2] then
                local limit = section[2].limit
                for key, callback in pairs(section[2]) do
                    if key ~= "limit" then
                        callback.limit = limit
                        current_line_callbacks[start][#current_line_callbacks[start] + 1] = callback
                    end
                end
            end

            if set_render_info then
                render_info.col_idxs[#render_info.col_idxs + 1] = start
            end

            text_line = text_line .. section[1]
        end

        output_lines[line] = text_line
        render_info.line_callbacks[line] = current_line_callbacks
        line = line + 1
    end

    vim.api.nvim_buf_set_option(editor_buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(editor_buf, 1, -1, false, output_lines)
    M.ApplyHighlighting()

    vim.api.nvim_buf_set_option(editor_buf, 'modifiable', false)

    M.render_info[editor_buf] = render_info
end

M.SplitView = function()
    local win = vim.api.nvim_get_current_win()
    local total_width = vim.api.nvim_win_get_width(win)

    -- Save and override splitright
    local original_splitright = vim.opt.splitright
    vim.opt.splitright = true
    vim.cmd('vsplit')
    vim.opt.splitright = original_splitright

    local new_win = vim.api.nvim_get_current_win()
    local target_width = total_width - 20
    vim.api.nvim_win_set_width(new_win, target_width)

    local editor_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(new_win, editor_buf)
    vim.api.nvim_win_set_option(new_win, 'number', false)
    vim.api.nvim_win_set_option(new_win, 'relativenumber', false)

    -- Define highlight group for the statusline
    vim.api.nvim_set_hl(0, "JsonViewStatusline", { bg = "#1e1e2e", fg = "#ffffff", bold = true })

    -- Floating statusline setup
    local status_buf = vim.api.nvim_create_buf(false, true)
    local function update_statusline(text)
        vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, { text })
    end
    update_statusline("[JSON VIEW]")

    local status_win = vim.api.nvim_open_win(status_buf, false, {
        relative = "win",
        win = new_win,
        row = 0,
        col = 0,
        width = target_width,
        height = 1,
        anchor = "NW",
        style = "minimal",
        focusable = false,
        noautocmd = true,
        zindex = 50,
    })
    vim.api.nvim_win_set_option(status_win, "winhl", "Normal:JsonViewStatusline")

    -- Cleanup autocommands
    local augroup = vim.api.nvim_create_augroup("JsonViewStatus", { clear = false })

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        group = augroup,
        callback = function(args)
            local closed_win = tonumber(args.match)
            if closed_win == new_win and vim.api.nvim_win_is_valid(status_win) then
                vim.api.nvim_win_close(status_win, true)
            end
        end
    })

    vim.api.nvim_create_autocmd({ "BufWipeout", "BufHidden" }, {
        group = augroup,
        buffer = editor_buf,
        callback = function()
            if vim.api.nvim_win_is_valid(status_win) then
                vim.api.nvim_win_close(status_win, true)
            end
        end
    })

    return editor_buf, update_statusline
end

M.CursorMoved = function(editor_buf, json_obj, file, file_buf, update_statusline)
    local pos = vim.api.nvim_win_get_cursor(0)
    if pos[1] == 1 then
        vim.api.nvim_win_set_cursor(0, { 2, pos[2] })
        pos[1] = 2
    end

    for _, k in pairs(M.config.keymaps) do
        vim.keymap.set("n", k, function()
            vim.notify(k .. " is not valid at this location", "WARN")
        end, { buffer = true })
    end

    local callback_keys = ""
    for start, callback_set in pairs(M.render_info[editor_buf].line_callbacks[pos[1] - 1]) do
        if pos[2] >= start then
            for _, callback in pairs(callback_set) do
                if pos[2] < start + callback.limit then
                    callback_keys = callback_keys .. callback[1]



                    vim.keymap.set("n", callback[1], function()
                        callback[2]({
                            editor_buf = editor_buf,
                            json_obj = json_obj,
                            file = file,
                            file_buf = file_buf,
                            render_info = M.render_info[editor_buf],
                        })
                    end, { buffer = true })
                end
            end
        end
    end

    update_statusline(M.plugin_name .. " [" .. callback_keys .. "]")
end

M.CursorToRoot = function()
    vim.api.nvim_win_set_cursor(0, { 3, 3 })
end

M.ShowJsonWindow = function(file_buf, json_obj, file)
    local editor_buf, update_statusline = M.SplitView();
    update_statusline("True")
    vim.api.nvim_win_set_buf(0, editor_buf)
    M.RenderGraph(json_obj, editor_buf, { editor_buf })
    M.CursorToRoot()

    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = editor_buf,
        callback = function() M.CursorMoved(editor_buf, json_obj, file, file_buf, update_statusline) end,
    })


    vim.notify(M.plugin_name .. " View Opened")
end

M.OpenJsonViewOnBuf = function(bufn)
    local lines = vim.api.nvim_buf_get_lines(bufn, 0, -1, false)
    local json_text = table.concat(lines, "")

    local json_obj;
    local valid = pcall(function()
        json_obj = vim.json.decode(json_text)
    end)

    if valid then
        M.ShowJsonWindow(bufn, json_obj, vim.api.nvim_buf_get_name(0))
    else
        vim.notify("Json text is not valid", "ERROR")
    end
end

M.OpenJsonView = function()
    if vim.bo.filetype == "json" or M.config.accept_all_files then
        local bufn = vim.api.nvim_buf_get_number(0)
        M.OpenJsonViewOnBuf(bufn)
    else
        vim.notify("Buffer does not have filetype json; could not open" .. M.plugin_name .. ".")
    end
end

vim.api.nvim_create_user_command(M.plugin_name, M.OpenJsonView, {})

local function update_table(with, to)
    for k, v in pairs(with) do
        if type(v) == "table" then
            if type(to[k]) == "table" then
                update_table(v, to[k])
            else
                to[k] = v
            end
        else
            to[k] = v
        end
    end
end

M.setup = function(opts)
    update_table(opts, M.config)
end

return M
