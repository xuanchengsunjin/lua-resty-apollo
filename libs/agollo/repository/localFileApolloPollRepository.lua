--- 保存的apolo配置文件作为repository源
---
---

local _M = {}

local config_util = require "libs.agollo.util"
local cjson_safe = require "cjson.safe"
local resty_lock = require "resty.lock"

--- 构造函数
function _M.new()
    local obj = {}
    obj.listener_map = {}
    local cluster_name = config_util.GetClusterName()
    if not cluster_name then
        return nil, "mising cluster_name"
    end
    obj.cluster_name = cluster_name
    obj.nameSpaceAppIDMap = table.new(0, 2) -- 定时任务里需要监听的nameSpace
    -- obj.nameSpaceList = table.new(2, 0) -- 定时任务里需要监听的nameSpace
    obj.notificarionIdMap = table.new(0, 2)
    
    local tal = setmetatable(obj, {__index = _M})
    return tal
end

--- 添加监听器
function _M.addApolloConfigChangeListener(self, listener)
    -- table.insert(self.listener_list, listener)
    local nameSpace = listener:GetNameSpace()
    
    local list = self.listener_map[nameSpace] or {}
    table.insert(list, listener)
    self.listener_map[nameSpace] = list
    local app_id = listener:GetAppID()
    return self:registTask(nameSpace, app_id)
end

local function _timer_flush(premature, self)
    local lock, err = resty_lock:new("config_shared", {exptime = 10, timeout = 0.005})
    if not lock then
        ngx.log(ngx.ERR, "localfile_resty_lock_new_failed,err:", tostring(err))
        return
    end
    local lock_key = "local_file_poll_lock" .. (ngx.worker.id() or 999)
    local elapsed, err = lock:lock(lock_key)
    ngx.log(ngx.INFO, "localfile_lock========:elapsed:", tostring(elapsed)," err:", err, " key:", lock_key)
    if not elapsed then
        -- 获取锁失败
        ngx.log(ngx.INFO, "localfile_resty_lock_lock_failed,err:", tostring(err))
        return
    end

    if next(self.nameSpaceAppIDMap) then
        for app_id,nameSpaceList in pairs(self.nameSpaceAppIDMap) do
            if app_id and nameSpaceList then
                ngx.log(ngx.INFO, "-----------self.nameSpaceList:" .. cjson_safe.encode(nameSpaceList))
                for _, nameSpace in pairs(nameSpaceList) do
                    if nameSpace then
                        local newNotificarionId = config_util.GetNotificationIdFromLocal(app_id, nameSpace)
                        local oldNotificarionId = self:getNamespaceNotificarionId(nameSpace)
                        ngx.log(ngx.INFO, "_timer_flush,newNotificarionId:", newNotificarionId," oldNotificarionId:", oldNotificarionId)
                        if newNotificarionId ~= oldNotificarionId then
                            -- 通知注册的监听器
                            local ok, err = self:nofityListener(nameSpace, app_id)
                            if ok then
                                -- 更新nameSpace的NotificationId
                                ngx.log(ngx.INFO, "_timer_flush,newNotificarionId:", newNotificarionId)
                                self:updateNamespaceNotificarionId(nameSpace, newNotificarionId)
                            else
                                ngx.log(ngx.ERR, "_timer_flush,nofityListener_failed,err:", err)
                            end
                        end
                    end
                end
            end
        end
    end
    lock:unlock()
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


function _M.getNamespaceNotificarionId(self, nameSpace)
    return self.notificarionIdMap[nameSpace] or config_util.GetNotificationIdFromLocal(self.app_id, nameSpace)
end

function _M.updateNamespaceNotificarionId(self, nameSpace, notificarionId)
    self.notificarionIdMap[nameSpace] = notificarionId
end

--- 提交openresty定时任务
function _M.ExcuteTimerTask(self)
    local ok, err = ngx.timer.every(2, _timer_flush, self)
    if not ok then
        error(tostring(err))
    end
end

-- 通知注册的监听器
function _M.nofityListener(self, nameSpace, app_id)
    local configFile = config_util.GetConfigFile(app_id, nameSpace)
    -- ngx.log(ngx.ERR, "nofityListener,nameSpace:", nameSpace, ",configFile:", configFile)
    if not configFile then
        ngx.log(ngx.ERR, "_timer_flush_failed,configFile get null")
        return nil, "get configFile failed"
    end

    local configurations = cjson_safe.decode(configFile)
    if configurations == nil or configurations == ngx.null then
        ngx.log(ngx.ERR, "_timer_flush_failed,configFile format error,", tostring(configFile))
        return nil, "_timer_flush_failed,configFile format error,", tostring(configFile)
    end

    local ret, err = config_util.ParseConfigurations(configurations)
    if not ret then
        ngx.log(ngx.ERR, "_timer_flush_failed,ParseConfigurations failed,err:", tostring(err))
        return
    end

    -- 生成事件对象
    local event = {
        nameSpace = nameSpace,
        time = ngx.time(),
        value_map = ret,
        app_id = app_id,
    }

    local listener_list = self.listener_map[nameSpace] or {}
    for _, listener in pairs(listener_list) do
        if listener then
            local ok,err = listener:onConfigChange(event)
            if ok then
                -- 监听器执行成功后,处理相关逻辑
                ngx.log(ngx.INFO, "onConfigChange+++++++++++++++++++++:")
            else
                ngx.log(ngx.ERR, "onConfigChange failed, err:" , tostring(err))
                return nil, err
            end
        end
    end
    return true
    -- self.is_busy = 0
end

--- 监听器onchange
function _M.onConfigChange(self, event)
    if not event or not event.nameSpace or not event.value_map or not event.config_origin_data or not event.app_id then
        ngx.log(ngx.ERR, "local file repository[onConfigChange] param error:", cjson_safe.encode(event))
        return nil, "onConfigChange param error"
    end
  
    -- ngx.log(ngx.ERR, "local file repository[onConfigChange] paraooo:", event.nameSpace, " data:", string.sub(event.config_origin_data, 1, 30))
    local config_origin_data = event.config_origin_data
    local time = event.time
    local nameSpace = event.nameSpace
    local app_id = event.app_id

    --- 更新数据
    local ok,err = config_util.WriteConfigFile(config_origin_data, app_id, nameSpace, time)
    if not ok then
        return nil, err
    end

    return true
end

return _M