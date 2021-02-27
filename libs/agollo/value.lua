local _M = {}

local cjson_safe = require "cjson.safe"

function _M.new(raw, val)
    local mt = { __index = _M}
    local obj = {
        raw = raw,
        val = val,
    }
    return setmetatable(obj, mt)
end

function _M.String(self)
    return self.raw
end

function _M.Int(self)
    if self.val then
        return self.val
    end
    
    self.val = math.modf(tonumber(self.raw))
    return self.val
end

function _M.Float(self)
    if self.val then
        return self.val
    end
    
    self.val = tonumber(self.raw)
    return self.val
end

function _M.Json(self)
    if self.val then
        return self.val
    end
    
    self.val = cjson_safe.decode(self.raw)
    return self.val
end

function _M.Boolean(self)
    if self.val then
        return self.val
    end
    
    self.val = "true" == self.raw and true or false
    return self.val
end

return _M
