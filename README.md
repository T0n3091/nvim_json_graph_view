# nvim_json_graph_view

Many editors have the option to view JSON files as a graph. Neovim, with a
terminal interface, does not have this luxury. While one can't create an
interface like JSON Crack, it is possible to build a similar JSON explorer
using Neovim's terminal interface.

https://github.com/user-attachments/assets/ca8f7021-5048-456a-9d1d-dc32328bbb25

```
╭──────────────────┬──╮╭──┬──┬──────────────────────────────────╮╭──┬──────┬───────────╮
│     JsonGraphView│[]├╯  │ 1│··········"This is a great plugin"││  │  user│·"will try"│
│           Example│{}├╮  │ 2│·············"Look at this number"││  │isTrue│"100% True"│
╰──────────────────┴──╯│  │ 3│······························3467││  ╰──────┴───────────╯
                       │  │ 4│······························null││
                       │  │ 5│···"The Next lines will be hidden"││
                       │  ╪.....................................││
                       │  ╰──┴──────────────────────────────────╯│
                       ╰──┬────────────┬────────────────────────╮│
                          │ empty_array│······················[]││
                          │ empty_table│······················{}││
                          │        test│"This is some test data"├╯
                          ╰────────────┴────────────────────────╯
```

> [!NOTE]
> This plugin is still under development. Breaking changes will be avoided
> unless deemed necessary.

## Setup

lazy.nvim
```lua
return {
    "Owen-Dechow/nvim_json_graph_view",
    opts = {
        -- accept_all_files = false,
        -- -- Allow opening non .json files

        -- max_lines = 5,
        -- -- Number of lines before collapsing

        -- round_units = true,
        -- -- Set the unit style to round

        -- round_connections = true,
        -- -- Set the connection style to round

        -- keymaps = {
            -- expand = "E",
            -- -- Expanding collapsed areas

            -- link_forward = "L",
            -- -- Jump to linked unit

            -- link_backward = "B",
            -- -- Jump back to unit parent

            -- set_as_root = "R",
            -- -- Set current unit as root

            -- quick_action = "<CR>",
            -- -- Aliased to first priority available keymap
        -- }
    }
}
```

## Running

To open a graph view, go to a json file and run `:JsonGraphView`.
The JsonGraphView window will open in a plit window to the right.
