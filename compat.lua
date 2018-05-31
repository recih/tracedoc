local pairs = pairs
local ipairs = ipairs

local compat = {}

local function compat_pairs(t)
    local f = pairs

    if type(t) == "table" then
        local mt = debug.getmetatable(t)
        if type(mt) == "table" and type(mt.__pairs) == "function" then
            f = mt.__pairs
        end
    end

    return f(t)
end

local function compat_ipairs(t)
    local f = ipairs

    if type(t) == "table" then
        local mt = debug.getmetatable(t)
        if type(mt) == "table" and type(mt.__ipairs) == "function" then
            f = mt.__ipairs
        end
    end

    return f(t)
end

local function compat_len(t)
    if type(t) ~= "table" then
        return #t
    end

    local mt = debug.getmetatable(t)
    if type(mt) == "table" and type(mt.__len) == "function" then
        return mt.__len(t)
    end

    return #t
end

local function check_mode(mode, prefix)
    local has = { text = false, binary = false }
    for i = 1, #mode do
        local c = mode:sub(i, i)
        if c == "t" then has.text = true end
        if c == "b" then has.binary = true end
    end
    local t = prefix:sub(1, 1) == "\27" and "binary" or "text"
    if not has[t] then
        return "attempt to load a "..t.." chunk (mode is '"..mode.."')"
    end
end

local function compat_load(ld, source, mode, env)
    mode = mode or "bt"
    local chunk, msg
    if type(ld) == "string" then
        if mode ~= "bt" then
            local merr = check_mode(mode, ld)
            if merr then return nil, merr end
        end
        chunk, msg = loadstring(ld, source)
    else
        local ld_type = type(ld)
        if ld_type ~= "function" then
            error("bad argument #1 to 'load' (function expected, got "..
                ld_type..")", 2)
        end
        if mode ~= "bt" then
            local checked, merr = false, nil
            local function checked_ld()
                if checked then
                return ld()
                else
                checked = true
                local v = ld()
                merr = check_mode(mode, v or "")
                if merr then return nil end
                return v
                end
            end
            chunk, msg = load(checked_ld, source)
            if merr then return nil, merr end
        else
            chunk, msg = load(ld, source)
        end
    end
    if not chunk then
        return chunk, msg
    end
    if env ~= nil then
        setfenv(chunk, env)
    end
    return chunk
end

local lua_version = tonumber(_VERSION:match("[%d%.]+"))

compat.pairs = lua_version < 5.2 and compat_pairs or pairs
compat.ipairs = lua_version < 5.2 and compat_ipairs or ipairs
compat.len = lua_version < 5.2 and compat_len or function(t) return #t end
compat.load = lua_version < 5.2 and compat_load or load
if not table.unpack then
    table.unpack = unpack
end

return compat