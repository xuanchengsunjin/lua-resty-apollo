--[[
    @function: 配置文件中心
]]

local _M = {}

function _M.new()
    local obj = {}
    
    return setmetatable(obj, {__index = _M})
end

return _M