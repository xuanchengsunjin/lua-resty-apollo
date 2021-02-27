local _M = {}

local localFileApolloPollRepository,err = require "libs.agollo.repository.localFileApolloPollRepository".new()
if not localFileApolloPollRepository then
    error("localFileApolloPollRepository failed" .. tostring(err))
end

local remoteLongPolllRepository, err = require "libs.agollo.repository.RemoteApolloLongPollRepository".new()
if not remoteLongPolllRepository then
    error("remoteLongPolllRepository failed" .. tostring(err))
end

--- 单例模式
function _M.CreateLocalFileApolloPollRepository()
    return localFileApolloPollRepository
end

--- 单例模式
function _M.CreateRemoteApolloLongPollRepository()
    return remoteLongPolllRepository
end

function _M.CreateRemoteApolloRepository(nameSpace, app_id)
    return require "libs.agollo.repository.remoteApolloRepository".new(nameSpace, app_id)
end

return _M