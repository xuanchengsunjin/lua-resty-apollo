--[[
    @function: 配置中心
]]

local _M = {}

local value = require "libs.agollo.value"
local cjson_safe = require "cjson.safe"

function _M.new(nameSpace, repository, app_id)
    local obj = {}

    if not repository or not nameSpace or not app_id then
        return nil, "repository nameSpace app_id misisng"
    end

    obj.nameSpace = nameSpace
    obj.repository = repository
    obj.app_id = app_id

    local tal = setmetatable(obj, {__index = _M})

    local ok,err = tal:initialize() -- 初始化
    if not ok then
        return nil, err
    end

    return tal
end

--- 监听器onchange
function _M.onConfigChange(self, event)
    if not event or not event.nameSpace or not event.value_map or not event.app_id then
        -- ngx.log(ngx.ERR, "onConfigChange param error")e
        return nil, "onConfigChange param error"
    end

    if self:GetAppID() ~= event.app_id or event.nameSpace ~= self:GetNameSpace() then
        return true
    end
    -- ngx.log(ngx.ERR, "self.origin_value_map:", cjson_safe.encode(self.value_map))
    local old_map = self.value_map
    self.value_map = event.value_map
    old_map = nil
    -- ngx.log(ngx.ERR, "self.new_value_map:", cjson_safe.encode(self.value_map))
    return true
end

--- 从配置集合获取key
function _M.GetValue(self, key, defaultValue)
    local v = self.value_map[key]
    if not v then
        return value.new("", defaultValue)
    end
    return v
end

function _M.GetNameSpace(self)
    return self.nameSpace
end

function _M.GetAppID(self)
    return self.app_id
end

--- 初始化
function _M.initialize(self)
    local ret, err = self.repository:GetConfigOriginData()
    if not ret then
        return nil, err
    end

    self.value_map = ret
    return true
end

return _M