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

local function HCLToColor(hue, chroma, lightness)
    local okhsl = {
        h = hue / 360.0,
        s = chroma / 255.0,
        l = lightness / 255.0
    }
    return RGBToColor(ok_color.okhsl_to_srgb(okhsl))
end

local function clamp(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local function wrap(value, min, max)
    local width = max - min
    while value < min do
        value = value + width
    end
    while value >= max do
        value = value - width
    end
    return value
end

local dialog

local state = {}

local function update_color()
    local saved_hue = state.hue
    local saved_chroma = state.chroma
    local saved_lightness = state.lightness

    local okhsl = {
        h = state.hue / 360.0,
        s = state.chroma / 255.0,
        l = state.lightness / 255.0
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

    state.hue = saved_hue
    state.chroma = saved_chroma
    state.lightness = saved_lightness

    if dialog ~= nil then
        dialog:repaint()
    end
end

local function round_state()
    state.hue = math.floor(0.5 + state.hue)
    state.chroma = math.floor(0.5 + state.chroma)
    state.lightness = math.floor(0.5 + state.lightness)
end

local function update_state()
    local okhsl = ok_color.srgb_to_okhsl(colorToRGB(app.fgColor))
    state.hue = math.floor(0.5 + okhsl.h * 360)
    state.chroma = math.floor(0.5 + okhsl.s * 255)
    state.lightness = math.floor(0.5 + okhsl.l * 255)
end

local function update_dialog()
    update_state()
    if dialog ~= nil then
        dialog:repaint()
    end
end

local STEPS_C = 8.0
local STEPS_L = 32.0

local function open_okhcl_dialog(bounds)
    dialog =
        Dialog {
        title = "OkHCL",
        notitlebar = false
    }

    update_state()

    dialog:canvas {
        id = "hue",
        width = 16,
        height = 12,
        vexpand = false,
        autoscaling = true,
        focus = true,
        onpaint = function(ev)
            local gc = ev.context
            if state.is_hue_pressed then
                gc.color = app.theme.color.hot_face
            else
                gc.color = app.theme.color.face
            end
            gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
            gc.color = app.theme.color.text
            local text = string.format("%d", state.hue)
            local measure = gc:measureText(text)
            local x = 1 + (gc.width - measure.width) / 2
            local y = 1 + (gc.height - measure.height) / 2
            gc:fillText(text, x, y)
        end,
        onmousedown = function(ev)
            state.is_hue_pressed = true
            state.pressed_hue = state.hue
            state.pressed_x = ev.x
            state.pressed_y = ev.y
            dialog:repaint()
        end,
        onmouseup = function(ev)
            local delta = ev.y - state.pressed_y
            state.hue = wrap(state.pressed_hue - (delta / 2.0), 0, 360)
            state.is_hue_pressed = false
            round_state()
            update_color()
        end,
        onmousemove = function(ev)
            if state.is_hue_pressed then
                local delta = ev.y - state.pressed_y
                state.hue = wrap(state.pressed_hue - (delta / 2.0), 0, 360)
                round_state()
                dialog:repaint()
            end
        end,
        onwheel = function(ev)
            state.hue = wrap(state.hue - ev.deltaY, 0, 360)
            round_state()
            update_color()
        end
    }

    dialog:canvas {
        id = "chroma",
        width = 16,
        height = 12,
        vexpand = false,
        autoscaling = true,
        onpaint = function(ev)
            local gc = ev.context
            if state.is_chroma_pressed then
                gc.color = app.theme.color.hot_face
            else
                gc.color = app.theme.color.face
            end
            gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
            gc.color = app.theme.color.text
            local text = string.format("%d", state.chroma)
            local width = gc:measureText(text).width
            local measure = gc:measureText(text)
            local x = 1 + (gc.width - measure.width) / 2
            local y = 1 + (gc.height - measure.height) / 2
            gc:fillText(text, x, y)
        end,
        onmousedown = function(ev)
            state.is_chroma_pressed = true
            state.pressed_chroma = state.chroma
            state.pressed_x = ev.x
            state.pressed_y = ev.y
            dialog:repaint()
        end,
        onmouseup = function(ev)
            local delta = ev.y - state.pressed_y
            state.chroma = clamp(state.pressed_chroma - (delta / 2.0), 0, 255)
            state.is_chroma_pressed = false
            round_state()
            update_color()
        end,
        onmousemove = function(ev)
            if state.is_chroma_pressed then
                local delta = ev.y - state.pressed_y
                state.chroma = clamp(state.pressed_chroma - (delta / 2.0), 0, 255)
                round_state()
                dialog:repaint()
            end
        end,
        onwheel = function(ev)
            state.chroma = clamp(state.chroma - ev.deltaY, 0, 255)
            round_state()
            update_color()
            dialog:repaint()
        end
    }

    dialog:canvas {
        id = "lightness",
        width = 16,
        height = 12,
        vexpand = false,
        autoscaling = true,
        onpaint = function(ev)
            local gc = ev.context
            if state.is_lightness_pressed then
                gc.color = app.theme.color.hot_face
            else
                gc.color = app.theme.color.face
            end
            gc:fillRect(Rectangle(0, 0, gc.width, gc.height))
            gc.color = app.theme.color.text
            local text = string.format("%d", state.lightness)
            local width = gc:measureText(text).width
            local measure = gc:measureText(text)
            local x = 1 + (gc.width - measure.width) / 2
            local y = 1 + (gc.height - measure.height) / 2
            gc:fillText(text, x, y)
        end,
        onmousedown = function(ev)
            state.is_lightness_pressed = true
            state.pressed_lightness = state.lightness
            state.pressed_x = ev.x
            state.pressed_y = ev.y
            dialog:repaint()
        end,
        onmouseup = function(ev)
            local delta = ev.y - state.pressed_y
            state.lightness = clamp(state.pressed_lightness - (delta / 2.0), 0, 255)
            state.is_lightness_pressed = false
            round_state()
            update_color()
        end,
        onmousemove = function(ev)
            if state.is_lightness_pressed then
                local delta = ev.y - state.pressed_y
                state.lightness = clamp(state.pressed_lightness - (delta / 2.0), 0, 255)
                round_state()
                dialog:repaint()
            end
        end,
        onwheel = function(ev)
            state.lightness = clamp(state.lightness - ev.deltaY, 0, 255)
            round_state()
            update_color()
            dialog:repaint()
        end
    }

    dialog:newrow()

    dialog:canvas {
        id = "color",
        width = 64,
        height = 32,
        vexpand = false,
        autoscaling = true,
        onpaint = function(ev)
            local gc = ev.context
            gc.color = app.fgColor
            gc:fillRect(Rectangle(0, 0, gc.width / 2, gc.height))
            gc.color = HCLToColor(state.hue, state.chroma, state.lightness)
            gc:fillRect(Rectangle(gc.width / 2, 0, gc.width / 2, gc.height))
        end
    }

    dialog:newrow()

    dialog:canvas {
        id = "chroma-lightness-slider",
        width = 96,
        height = 128,
        vexpand = true,
        autoscaling = true,
        focus = true,
        onpaint = function(ev)
            local gc = ev.context
            state.width = gc.width
            state.height = gc.height
            local w = gc.width / STEPS_C
            local h = gc.height / STEPS_L
            for i = 0, STEPS_C do
                for j = 0, STEPS_L do
                    gc.color = HCLToColor(state.hue, (i / STEPS_C) * 255.0, 255.0 - (j / STEPS_L) * 255.0)
                    gc:fillRect(Rectangle(i * w, j * h, w + 1, h + 1))
                end
            end
            local x = (state.chroma / 255.0) * gc.width
            local y = ((255.0 - state.lightness) / 255.0) * gc.height
            if state.lightness < 128 then
                gc.color = Color {r = 255, g = 255, b = 255, a = 128}
            else
                gc.color = Color {r = 0, g = 0, b = 0, a = 128}
            end
            gc:strokeRect(Rectangle(x - 2, y - 2, 5, 5))
        end,
        onmousedown = function(ev)
            state.is_chroma_lightness_slider_pressed = true
            state.chroma = clamp((ev.x / state.width) * 255.0, 0.0, 255.0)
            state.lightness = 255.0 - clamp((ev.y / state.height) * 255.0, 0.0, 255.0)
            dialog:repaint()
        end,
        onmouseup = function(ev)
            state.is_chroma_lightness_slider_pressed = false
            state.chroma = clamp((ev.x / state.width) * 255.0, 0.0, 255.0)
            state.lightness = 255.0 - clamp((ev.y / state.height) * 255.0, 0.0, 255.0)
            round_state()
            update_color()
        end,
        onmousemove = function(ev)
            if state.is_chroma_lightness_slider_pressed then
                state.chroma = clamp((ev.x / state.width) * 255.0, 0.0, 255.0)
                state.lightness = 255.0 - clamp((ev.y / state.height) * 255.0, 0.0, 255.0)
                round_state()
                dialog:repaint()
            end
        end
    }

    dialog:newrow()

    dialog:canvas {
        id = "hue-slider",
        width = 64,
        height = 13,
        vexpand = false,
        autoscaling = true,
        focus = true,
        onpaint = function(ev)
            local gc = ev.context
            local w = gc.width / 32.0
            for i = 0, 32.0 do
                gc.color = HCLToColor((i / 32.0) * 360.0, state.chroma, state.lightness)
                gc:fillRect(Rectangle(i * w, 0, w + 1, gc.height))
            end
            local x = (state.hue / 360.0) * gc.width
            local y = (gc.height - 7) / 2
            if state.lightness < 128 then
                gc.color = Color {r = 255, g = 255, b = 255, a = 128}
            else
                gc.color = Color {r = 0, g = 0, b = 0, a = 128}
            end
            gc:strokeRect(Rectangle(x - 2, y + 1, 5, 5))
        end,
        onmousedown = function(ev)
            state.is_hue_slider_pressed = true
            state.hue = wrap((ev.x / state.width) * 360.0, 0.0, 360.0)
            dialog:repaint()
        end,
        onmouseup = function(ev)
            state.is_hue_slider_pressed = false
            state.hue = wrap((ev.x / state.width) * 360.0, 0.0, 360.0)
            round_state()
            update_color()
        end,
        onmousemove = function(ev)
            if state.is_hue_slider_pressed then
                state.hue = wrap((ev.x / state.width) * 360.0, 0.0, 360.0)
                round_state()
                dialog:repaint()
            end
        end,
        onwheel = function(ev)
            state.hue = wrap(state.hue - ev.deltaY, 0, 360)
            round_state()
            update_color()
            dialog:repaint()
        end
    }
end

function init(plugin)
    plugin:newCommand {
        id = "OkLabColorPicker",
        title = "OkLab Color Picker",
        group = "palette_main",
        onclick = function()
            dialog:show {wait = false}
            local bounds = plugin.preferences.okhcl_dialog_bounds
            if bounds ~= nil then
                bounds = Rectangle(bounds.x, bounds.y, bounds.width, bounds.height)
                plugin.preferences.okhcl_dialog_bounds = nil
            else
                bounds = dialog.bounds
            end
            if bounds.width < 128 then
                bounds.width = 216
            end
            if bounds.height < 64 then
                bounds.height = 440
            end
            if bounds.x + bounds.width > app.window.width + 16 then
                bounds.x = app.window.width - bounds.width
            end
            if bounds.y + bounds.height > app.window.height + 16 then
                bounds.y = app.window.height - bounds.height
            end
            dialog.bounds = bounds
            update_dialog()
        end
    }

    open_okhcl_dialog()

    app.events:on("sitechange", update_dialog)
    app.events:on("fgcolorchange", update_dialog)
    app.events:on(
        "aftercommand",
        function(ev)
            if ev.name == "Paste" or ev.name == "Undo" or ev.name == "Redo" then
                update_dialog()
            end
        end
    )
end

function exit(plugin)
    if dialog.bounds ~= nil and not dialog.bounds.isEmpty then
        plugin.preferences.okhcl_dialog_bounds = {
            x = dialog.bounds.x,
            y = dialog.bounds.y,
            width = dialog.bounds.width,
            height = dialog.bounds.height
        }
    end
end
