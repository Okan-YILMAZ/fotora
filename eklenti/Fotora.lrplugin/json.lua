-- Minimal saf Lua JSON encode/decode.
-- Lightroom'un Lua ortamında yerleşik JSON desteği yok; LrHttp ham string
-- döner. Bu dosya sadece bu eklentinin ihtiyaç duyduğu türleri kapsar:
-- string, number, boolean, nil (null), array, object.

local json = {}

-- ===== ENCODE =====

local escape_map = {
    ['\\'] = '\\\\',
    ['"']  = '\\"',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

local function escape_string(s)
    local out = s:gsub('[%z\1-\31\\"]', function(c)
        return escape_map[c] or string.format('\\u%04x', c:byte())
    end)
    return '"' .. out .. '"'
end

local function is_array(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= 'number' then return false end
        n = n + 1
    end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true
end

local encode_value

local function encode_object(t)
    local parts = {}
    for k, v in pairs(t) do
        table.insert(parts, escape_string(tostring(k)) .. ':' .. encode_value(v))
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

local function encode_array(t)
    local parts = {}
    for i = 1, #t do
        table.insert(parts, encode_value(t[i]))
    end
    return '[' .. table.concat(parts, ',') .. ']'
end

encode_value = function(v)
    local t = type(v)
    if t == 'string' then
        return escape_string(v)
    elseif t == 'number' then
        return tostring(v)
    elseif t == 'boolean' then
        return v and 'true' or 'false'
    elseif t == 'nil' then
        return 'null'
    elseif t == 'table' then
        if next(v) == nil then
            return '{}'
        end
        if is_array(v) then
            return encode_array(v)
        else
            return encode_object(v)
        end
    else
        error('json.encode: desteklenmeyen tip: ' .. t)
    end
end

function json.encode(v)
    return encode_value(v)
end

-- ===== DECODE =====

local decode_value

local function skip_whitespace(s, i)
    local _, j = s:find('^[ \t\n\r]*', i)
    return j + 1
end

-- Unicode kod noktasını UTF-8 baytlarına çevirir (Türkçe karakterler dahil).
local function utf8_encode(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(
            0xC0 + math.floor(code / 0x40),
            0x80 + (code % 0x40)
        )
    elseif code < 0x10000 then
        return string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    else
        return string.char(
            0xF0 + math.floor(code / 0x40000),
            0x80 + (math.floor(code / 0x1000) % 0x40),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    end
end

local function decode_string(s, i)
    -- i, açılış tırnağının konumu (s:sub(i,i) == '"')
    local j = i + 1
    local out = {}
    while true do
        local c = s:sub(j, j)
        if c == '' then
            error('json.decode: sonlandırılmamış string')
        elseif c == '"' then
            return table.concat(out), j + 1
        elseif c == '\\' then
            local nc = s:sub(j + 1, j + 1)
            if nc == 'n' then table.insert(out, '\n')
            elseif nc == 't' then table.insert(out, '\t')
            elseif nc == 'r' then table.insert(out, '\r')
            elseif nc == 'b' then table.insert(out, '\b')
            elseif nc == 'f' then table.insert(out, '\f')
            elseif nc == '"' then table.insert(out, '"')
            elseif nc == '\\' then table.insert(out, '\\')
            elseif nc == '/' then table.insert(out, '/')
            elseif nc == 'u' then
                local hex = s:sub(j + 2, j + 5)
                local code = tonumber(hex, 16) or 63
                if code >= 0xD800 and code <= 0xDBFF and s:sub(j + 6, j + 7) == '\\u' then
                    -- Surrogate çifti (BMP dışı, örn. emoji): iki \u birleşir.
                    local lo = tonumber(s:sub(j + 8, j + 11), 16)
                    if lo and lo >= 0xDC00 and lo <= 0xDFFF then
                        code = 0x10000 + (code - 0xD800) * 0x400 + (lo - 0xDC00)
                        j = j + 6
                    end
                end
                table.insert(out, utf8_encode(code))
                j = j + 4
            else
                table.insert(out, nc)
            end
            j = j + 2
        else
            table.insert(out, c)
            j = j + 1
        end
    end
end

local function decode_number(s, i)
    local m = s:match('^-?%d+%.?%d*[eE]?[+-]?%d*', i)
    return tonumber(m), i + #m
end

decode_value = function(s, i)
    i = skip_whitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then
        return decode_string(s, i)
    elseif c == '{' then
        local obj = {}
        i = skip_whitespace(s, i + 1)
        if s:sub(i, i) == '}' then return obj, i + 1 end
        while true do
            i = skip_whitespace(s, i)
            local key
            key, i = decode_string(s, i)
            i = skip_whitespace(s, i)
            if s:sub(i, i) ~= ':' then error('json.decode: ":" bekleniyordu') end
            i = i + 1
            local val
            val, i = decode_value(s, i)
            obj[key] = val
            i = skip_whitespace(s, i)
            local ch = s:sub(i, i)
            if ch == ',' then
                i = i + 1
            elseif ch == '}' then
                return obj, i + 1
            else
                error('json.decode: "," veya "}" bekleniyordu')
            end
        end
    elseif c == '[' then
        local arr = {}
        i = skip_whitespace(s, i + 1)
        if s:sub(i, i) == ']' then return arr, i + 1 end
        local idx = 1
        while true do
            local val
            val, i = decode_value(s, i)
            arr[idx] = val
            idx = idx + 1
            i = skip_whitespace(s, i)
            local ch = s:sub(i, i)
            if ch == ',' then
                i = i + 1
            elseif ch == ']' then
                return arr, i + 1
            else
                error('json.decode: "," veya "]" bekleniyordu')
            end
        end
    elseif s:sub(i, i + 3) == 'true' then
        return true, i + 4
    elseif s:sub(i, i + 4) == 'false' then
        return false, i + 5
    elseif s:sub(i, i + 3) == 'null' then
        return nil, i + 4
    else
        return decode_number(s, i)
    end
end

function json.decode(s)
    local value = decode_value(s, 1)
    return value
end

return json
