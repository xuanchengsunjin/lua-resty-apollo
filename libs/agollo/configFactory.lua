local _M = {}

local CONFIG = require "libs.agollo.config"
-- apollo配置仓库工厂
local ReposityFactory = require "libs.agollo.repository.configRepositoryFactory"

--- 根据nameSpace获取Config
--- @return Config,err
function _M.GetConfigByNameSpace(nameSpace, app_id, no_need_hotUpdate)
    if not nameSpace or "string" ~= type(nameSpace) or not app_id then
        return nil, "nameSpace invalid format" 
    end

    local remote_repository, err = ReposityFactory.CreateRemoteApolloRepository(nameSpace, app_id)
    if not remote_repository then 
        return nil, err
    end

    local config,err = CONFIG.new(nameSpace, remote_repository, app_id)
    if not config then
        return nil, err
    end

    if not no_need_hotUpdate then
        local localFileApolloPollRepository, err = ReposityFactory.CreateLocalFileApolloPollRepository()
        if not localFileApolloPollRepository then
            return nil, err
        end

        
        local ok,err = localFileApolloPollRepository:addApolloConfigChangeListener(config)
        if not ok then
            return nil, err
        end

        -- 如果需要配置热更新
        -- 添加配置变化监听器
        -- local ok,err = remote_repository:addConfigChangeListener(config)
        -- if not ok then
        --     return nil, err
        -- end

                -- 如果需要配置热更新
        -- 添加配置变化监听器
        local ok,err = remote_repository:addConfigChangeListener(localFileApolloPollRepository)
        if not ok then
            return nil, err
        end

        -- local ok,err = remote_repository:addApolloConfigChangeListener(localFileApolloPollRepository)
        -- if not ok then
        --     return nil, err
        -- end

        local remoteApolloPollRepository, err = ReposityFactory.CreateRemoteApolloLongPollRepository()
        if not remoteApolloPollRepository then
            return nil, err
        end

        local ok,err = remoteApolloPollRepository:addApolloConfigChangeListener(remote_repository)
        if not ok then
            return nil, err
        end
    end

    return config
end

--- 根据nameSpace获取ConfigFile
--- @return ConfigFile
function _M.GetConfigFileByNameSpace(nameSpace, app_id)
    if not nameSpace or "string" ~= type(nameSpace) then
        return nil, "nameSpace invalid format" 
    end

end

--- @return Config
function _M.GetConfigByNameSpaceList(nameSpaceList, app_id)
    if not nameSpaceList or "table" ~= type(nameSpaceList) or not next(nameSpaceList) then
        return nil, "nameSpaceList invalid format" 
    end
end

--- @return ConfigFile
function _M.GetConfigFileByNameSpaceList(nameSpaceList, app_id)
    if not nameSpaceList or "table" ~= type(nameSpaceList) or not next(nameSpaceList) then
        return nil, "nameSpace invalid format" 
    end

end

return _M