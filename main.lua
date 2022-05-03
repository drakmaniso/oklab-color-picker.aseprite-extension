dofile("./ok_color.lua")

local function colorToRGB(c)
    return {
        r = c.red * 0.00392156862745098,
        g = c.green * 0.00392156862745098,
        b = c.blue * 0.00392156862745098
    }
end

local function RGBToColor(rgb)
    return Color(
        math.tointeger(0.5 + 0xff * math.min(math.max(rgb.r, 0.0), 1.0)),
        math.tointeger(0.5 + 0xff * math.min(math.max(rgb.g, 0.0), 1.0)),
        math.tointeger(0.5 + 0xff * math.min(math.max(rgb.b, 0.0), 1.0)),
        255
    )
end

function init(plugin)
    print("Aseprite is initializing the OkLab Color Picker")

    -- we can use "plugin.preferences" as a table with fields for
    -- our plugin (these fields are saved between sessions)
    -- if plugin.preferences.count == nil then
    --     plugin.preferences.count = 0
    -- end

    local output_dialog = Dialog("                    Color Values                    ")
    output_dialog:entry {
        id = "ok-output",
        label = "sRGB",
        text = "",
        focus = true
    }

    local dialog = Dialog("                    OkLab Color Picker                    ")

    local function update_color()
        local hue = dialog.data["ok-hue"]
        local saturation = dialog.data["ok-saturation"]
        local lightness = dialog.data["ok-lightness"]

        local okhsl = {
            h = hue / 360.0,
            s = saturation / 100.0,
            l = lightness / 100.0
        }
        local rgb = ok_color.okhsl_to_srgb(okhsl)

        local index = app.fgColor.index
        local palette = app.activeSprite.palettes[1]

        -- This is a hack to determine if the current
        -- selected color is a palette entry...
        local is_palette_index =
            app.fgColor.red == palette:getColor(index).red and app.fgColor.green == palette:getColor(index).green and
            app.fgColor.blue == palette:getColor(index).blue and
            app.fgColor.alpha == palette:getColor(index).alpha

        if is_palette_index then
            palette:setColor(index, RGBToColor(rgb))
        else
            app.fgColor = RGBToColor(rgb)
        end

        local data = dialog.data
        -- If we have set app.fgColor, update_dialog has been called
        -- and the slider values may have been messed up, so we
        -- need to keep them to the values set by the user.
        data["ok-hue"] = hue
        data["ok-saturation"] = saturation
        data["ok-lightness"] = lightness
        dialog.data = data

        local fg = app.fgColor
        local output_data = output_dialog.data
        output_data["ok-output"] =
            string.format("%1.9f, %1.9f, %1.9f", fg.red / 255.0, fg.green / 255.0, fg.blue / 255.0)
        output_dialog.data = output_data
    end

    dialog:color {
        id = "ok-color",
        label = "",
        color = app.fgColor,
        onchange = function()
            app.fgColor = dialog.data["ok-color"]
        end
    }
    dialog:slider {
        id = "ok-hue",
        label = "H",
        min = 0,
        max = 360,
        value = 0,
        onchange = update_color
    }
    dialog:slider {
        id = "ok-saturation",
        label = "S",
        min = 0,
        max = 100,
        value = 0,
        onchange = update_color
    }
    dialog:slider {
        id = "ok-lightness",
        label = "L",
        min = 0,
        max = 100,
        value = 0,
        onchange = update_color
    }

    local function update_dialog()
        local data = dialog.data
        local fg = app.fgColor
        local okhsl = ok_color.srgb_to_okhsl(colorToRGB(fg))
        data["ok-color"] = fg
        data["ok-hue"] = okhsl.h * 360
        data["ok-saturation"] = okhsl.s * 100
        data["ok-lightness"] = okhsl.l * 100
        dialog.data = data
        local output_data = output_dialog.data
        output_data["ok-output"] =
            string.format("%1.9f, %1.9f, %1.9f", fg.red / 255.0, fg.green / 255.0, fg.blue / 255.0)
        output_dialog.data = output_data
    end

    --
    plugin:newCommand {
        id = "OkLabColorPicker",
        title = "OkLab Color Picker",
        group = "palette_main",
        onclick = function()
            -- plugin.preferences.count = plugin.preferences.count + 1
            update_dialog()
            dialog:show {wait = false}
        end
    }
    plugin:newCommand {
        id = "ColorValues",
        title = "Color Values",
        group = "palette_main",
        onclick = function()
            -- plugin.preferences.count = plugin.preferences.count + 1
            update_dialog()
            output_dialog:show {wait = false}
        end
    }

    app.events:on("fgcolorchange", update_dialog)
end

function exit(plugin)
    -- print("Aseprite is closing my plugin, MyFirstCommand was called " .. plugin.preferences.count .. " times")
end
