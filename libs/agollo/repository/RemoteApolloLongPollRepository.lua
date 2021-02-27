--- 向apollo长轮询,挂起http,
--- 当namespace配置发生变化时,通知listener同步最新配置

local _M = {}

local config_util = require "libs.agollo.util"
local config_const = require "libs.agollo.const.config_const"
local cjson_safe = require "cjson.safe"
local resty_lock = require "resty.lock"


function _M.new(app_id)
    local obj = {}
    -- if not app_id then
    --     return nil, "missing app_id"
    -- end
    -- obj.app_id = app_id
    -- obj.is_busy = 0
    obj.listener_list = {}
    local cluster_name = config_util.GetClusterName()
    local meta_addr = config_util.GetMeatAddress()
    if not meta_addr or not cluster_name then
        return nil, "meta_addr or app_id missing"
    end

    obj.cluster_name = cluster_name
    obj.meta_addr = meta_addr

    -- obj.nameSpaceList = table.new(2, 0) -- 定时任务里需要监听的nameSpace
    obj.nameSpaceAppIDMap = table.new(0, 2) -- 定时任务里需要监听的nameSpace
    -- 先尝试从硬盘文件中获取notificationId
    -- local ret = util.GetNotificationIdFromLocal(app_id, nameSpace)
    -- obj.notificationId = tonumber(ret) or config_const.DEFAULT_NOTIFICATION_ID
    -- 持久化notificationId
    -- local ok, err = util.WriteNotificationIdFromLocal(app_id, nameSpace, obj.notificationId)
    -- if err then
    --     return nil,err
    -- end
    return setmetatable(obj, {__index = _M})
end

local function _timer_flush(premature, self)
    local lock, err = resty_lock:new("config_shared", {exptime = 65, timeout = 0.005})
    if not lock then
        ngx.log(ngx.ERR, "resty_lock_new_failed,err:", tostring(err))
        return
    end
    local elapsed, err = lock:lock("remote_poll_lock")
    ngx.log(ngx.INFO, "lock========:elapsed:", tostring(elapsed)," err:", err)
    if not elapsed then
        -- 获取锁失败
        ngx.log(ngx.INFO, "resty_lock_lock_failed,err:", tostring(err))
        return
    end
    if next(self.nameSpaceAppIDMap) then
        for app_id,nameSpaceList in pairs(self.nameSpaceAppIDMap) do
            if app_id and nameSpaceList then
                local url = self:assembleNotificationUrl(app_id, self.cluster_name, self.meta_addr, nameSpaceList)
                ngx.log(ngx.INFO, "assembleNotificationUrl,url:", url)
                local http = require "libs.http"
                local httpc = http:new()
                httpc:set_timeouts(100000, 100000, 100000)
                local res, err = httpc:request_uri(url, {
                    method = "GET",
                    keepalive_timeout = 100,
                })
        
                if not res then
                    ngx.log(ngx.ERR, "notifications_v2 failed,err:", tostring(err))
                    lock:unlock()
                    return
                end
        
                ngx.log(ngx.INFO, "notifications_v2 body,res:", cjson_safe.encode(res.body))
                if res.status ~= 200 then
                    httpc:close()
                    if res.status ~= 304 then
                        ngx.log(ngx.ERR, "notifications_v2 exception,res:", cjson_safe.encode(res), "status:", res.status, "res:", cjson_safe.encode(res))
                        lock:unlock()
                        return nil, "GetConfigOriginData exception"
                    end
                    -- lock:unlock()
                    -- return true
                end
        
                httpc:close()
                local data = cjson_safe.decode(res.body)
                if data and next(data) then
                    for _, info in pairs(data) do
                        local namespaceName = info.namespaceName
                        local notificationId = info.notificationId
                        local messages = info.messages
                        if namespaceName and notificationId then
                            if self.notificationId ~= notificationId then
                                local event = {
                                    nameSpace = namespaceName,
                                    time = ngx.time(),
                                    notificationId = notificationId,
                                    app_id = app_id,
                                }
                                self:nofityListener(event)
                            end
                        end
                    end  
                end
            end
        end
       
        lock:unlock()
    end
end

-- 通知注册的监听器
function _M.nofityListener(self, event)
    for _, listener in pairs(self.listener_list) do
        if listener then
            local ok,err = listener:onConfigChangeListener(event)
            if ok then
                -- 监听器执行成功后,处理相关逻辑
                ngx.log(ngx.INFO, "onConfigChangeListener————————————————————————:")
                -- local ok,err = config_util.WriteNotificationIdFromLocal(self.app_id, event.nameSpace, event.notificationId)
                -- self.notificationId = event.notificationId
            else
                ngx.log(ngx.ERR, "onConfigChangeListener failed, err:" , tostring(err))
                return nil, "onConfigChangeListener notify failed"
            end
        end
    end
    local ok,err = config_util.WriteNotificationIdFromLocal(event.app_id, event.nameSpace, event.notificationId)
    return true
    -- self.is_busy = 0
end

--- 注册openresty定时任务
--- @return boolean,err
function _M.registTask(self, nameSpace, app_id)
    if nameSpace and app_id then
        self.nameSpaceAppIDMap[app_id] = self.nameSpaceAppIDMap[app_id] or table.new(2, 0)
        table.insert(self.nameSpaceAppIDMap[app_id], nameSpace)

        return true
    end

    return nil, "nameSpace or app_id missing"
end

--- 提交openresty定时任务
function _M.ExcuteTimerTask(self)
    local ok, err = ngx.timer.every(2, _timer_flush, self)
    if not ok then
        error(tostring(err))
    end
end

--- 添加监听器
function _M.addApolloConfigChangeListener(self, listener)
    table.insert(self.listener_list, listener)
    local nameSpace = listener:GetNameSpace()
    local app_id = listener:GetAppID()
    return self:registTask(nameSpace, app_id)
end

function _M.assembleNotificationUrl(self, app_id, cluster_name, meta_addr, nameSpaceList)
    local tab = table.new(10, 0)
    table.insert(tab, "http://")
    table.insert(tab, meta_addr)
    table.insert(tab, "/notifications/v2?appId=")
    table.insert(tab, app_id)
    table.insert(tab, "&cluster=")
    table.insert(tab, cluster_name)
    table.insert(tab, "&notifications=")
    local notifications_data = table.new(#nameSpaceList, 0)

    ngx.log(ngx.INFO, "self.nameSpaceList:" .. cjson_safe.encode(nameSpaceList))
    for _, nameSpace in pairs(nameSpaceList) do
        if nameSpace then
            local tab = {
                namespaceName = nameSpace,
                notificationId = config_util.GetNotificationIdFromLocal(app_id, nameSpace),
            }
            table.insert(notifications_data, tab)
        end
    end

    table.insert(tab, ngx.escape_uri(cjson_safe.encode(notifications_data)))
    return table.concat(tab)
end


return _M