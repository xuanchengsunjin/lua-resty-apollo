--- 配置中心暴露的对外统一服务
--- author jim_sun

local _M = {}

local CONST = require "libs.agollo.const.config_const"
local ConfigFatory = require "libs.agollo.configFactory"
local config_util = require "libs.agollo.util"

function _M.new(app_id)
    if not app_id then
        error("configservice new missing app_id")
        return nil, "missing app_id"
    end
    local obj = { app_id = app_id, configMap = {}}
    return setmetatable(obj, { __index = _M })
end

--- @param nameSpace string|list|nil
--- @param no_need_hotUpdate 1:不需要热更新,默认需要
function _M.GetConfig(self, nameSpace, no_need_hotUpdate)
    nameSpace = nameSpace or CONST.DEFAULT_NAMESPACE
    local config,err
    if "string" == type(nameSpace) then
        if self.configMap[nameSpace] then
            return self.configMap[nameSpace]
        end
        config,err = ConfigFatory.GetConfigByNameSpace(nameSpace, self.app_id, no_need_hotUpdate)
    elseif "table" == type(nameSpace) then
        config,err = ConfigFatory.GetConfigByNameSpaceList(nameSpace, self.app_id)
    else
        config,err = ConfigFatory.GetConfigByNameSpace(nameSpace, self.app_id)
    end
    if not config then
        ngx.log(ngx.ERR, "get config error:" .. tostring(err))
        error("get config error:" .. tostring(err))
    end

    -- if not no_need_hotUpdate then
    --     self:RegistHotUpdate(config)
    -- end
    self.configMap[nameSpace] = config
    return config,err
end

--- @param nameSpace string|list|nil
-- function _M.GetConfigFile(self, nameSpace)
--     local config,err
--     nameSpace = nameSpace or CONST.DEFAULT_NAMESPACE
--     if "string" == type(nameSpace) then
--         config,err = ConfigFatory.GetConfigFileByNameSpace(nameSpace, self.app_id)
--     elseif "table" == type(nameSpace) then
--         config,err = ConfigFatory.GetConfigFileByNameSpaceList(nameSpace, self.app_id)
--     else
--         config,err = ConfigFatory.GetConfigFileByNameSpace(nameSpace, self.app_id)
--     end
--     if not config then
--         ngx.log(ngx.ERR, "get config error:" .. err)
--         error("get config error:" .. err)
--     end
--     return config,err
-- end

-- 注册需要热更新的配置实例
-- function _M.RegistHotUpdate(self, config)
--     table.insert(self.hotUpdateConfigList, config)
-- end

-- 启动守护进程热更新任务
function _M.ExcutePrivilegeHotUpdateTask(self)
    -- apollo配置仓库工厂
    local ReposityFactory = require "libs.agollo.repository.configRepositoryFactory"
    local repository,err = ReposityFactory.CreateRemoteApolloLongPollRepository()
    if repository then
        repository:ExcuteTimerTask()
        return true
    else
        return nil, err
    end
    -- ngx.log(ngx.INFO, "NotifyHotUpdateTask")
    -- for _, config in pairs(self.hotUpdateConfigList) do
    --     if config and config.registTask then
    --         config:registTask()
    --     end
    -- end
end

-- 启动热更新任务
function _M.ExcuteWorkerSubmitHotUpdateTask(self)
    local ReposityFactory = require "libs.agollo.repository.configRepositoryFactory"
    local repository,err = ReposityFactory.CreateLocalFileApolloPollRepository()
    if repository then
        repository:ExcuteTimerTask()
        return true
    else
        return nil, err
    end
    -- ngx.log(ngx.INFO, "NotifySubmitHotUpdateTask")
    -- for _, config in pairs(self.hotUpdateConfigList) do
    --     if config and config.submitUpdateTask then
    --         config:submitUpdateTask()
    --     end
    -- end
end

return _M