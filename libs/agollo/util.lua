local util = require "libs.util.common_util"
local value = require "libs.agollo.value"
local config_const = require "libs.agollo.const.config_const"

local _M = {}

-- function _M.GetAppID()
--     return util.GetEnvFromFile("APOLLO_APP_ID")
-- end

--- 获取apollo metaserver address
function _M.GetMeatAddress()
    return util.GetEnvFromFile("APOLLO_META_ADDR")
end

function _M.GetClusterName()
    return util.GetEnvFromFile("CLUSTER_NAME") or "default"
end

--- 从硬盘里获取notificationId
function _M.GetNotificationIdFromLocal(app_id, nameSpace)
    if not app_id or not nameSpace then
        return nil, "param missing"
    end

    local file_name = "apollo_notification_id_" .. app_id .. "_" .. nameSpace

    local notification_id, flags = ngx.shared.config_shared:get(file_name)
    -- ngx.log(ngx.ERR, "notification_id:", notification_id, " app_id:", app_id, " nameSpace:", nameSpace)
    return tonumber(notification_id) or config_const.DEFAULT_NOTIFICATION_ID
    -- local file_path = "/opt/apollo/" .. file_name
    -- local fp, err = io.open(file_path, "rb")
    -- if not err then
    --     local val =  string.match(fp:read("*a"), "[%w_\\.:]+")
    --     fp:close()
    --     return tonumber(val) or config_const.DEFAULT_NOTIFICATION_ID
    -- end

    -- return nil
end

--- 往硬盘里持久化notificationId
function _M.WriteNotificationIdFromLocal(app_id, nameSpace, notificationId)
    if not app_id or not nameSpace or not notificationId then
        return nil, "param missing"
    end

    local file_name = "apollo_notification_id_" .. app_id .. "_" .. nameSpace
    local ok, err = ngx.shared.config_shared:set(file_name, tostring(notificationId))
    ngx.log(ngx.INFO, "notification_id:", notificationId, " app_id:", app_id, " nameSpace:", nameSpace, "ok:", ok, "err:", err)
    if not ok then
        ngx.log(ngx.ERR, "WriteNotificationIdFromLocalFailed,err:", tostring(err))
        return nil, err
    end

    return true
    -- os.execute("mkdir -p /opt/apollo/")


    -- local file_path = "/opt/apollo/" .. file_name
    -- local fp, err = io.open(file_path, "w")
    -- if not err then
    --     fp:write(tostring(notificationId))
    --     fp:close()
    --     return true
    -- else
    --     ngx.log(ngx.ERR, "write apollo notificationId failed,err:", tostring(err))
    --     error("write apollo notificationId failed,err:" .. tostring(err))
    --     return nil, "write apollo notificationId failed,err:" .. tostring(err)
    -- end

    -- return nil
end

--- 解析apollo返回的配置数据
function _M.ParseConfigurations(configurations)
    if not configurations then
        return nil, "configurations missing"
    end

    local tab = table.new(0, 2)
    for k,v in pairs(configurations) do
        tab[k] = value.new(v)
    end
    
    return tab
end

function _M.WriteConfigFile(data, app_id, nameSpace)
    if not data or not app_id or not nameSpace then
        ngx.log(ngx.ERR, "WriteConfigFile,param,missing")
        return nil, "WriteConfigFile,param,missing"
    end
    -- ngx.log(ngx.ERR, "data:" , data)
    local key = app_id .. "_" .. nameSpace .. "_data"
    local ok,err = ngx.shared.config_shared:set(key, data)
    if not ok then
        return nil, err
    end

    return ok
end

function _M.GetConfigFile(app_id, nameSpace)
    local key = app_id .. "_" .. nameSpace .. "_data"
    local config_file, flags = ngx.shared.config_shared:get(key)
    return config_file, flags
end

return _M