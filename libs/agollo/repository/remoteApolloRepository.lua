local _M = {}

local http = require "libs.http"
local config_util = require "libs.agollo.util"
local cjson_safe = require "cjson.safe"
local ltn12 = require("ltn12")
local Value = require "libs.agollo.value"
local common_util = require "libs.util.common_util"

function _M.new(nameSpace, app_id)
    if not nameSpace or not app_id then
        return nil, "missing nameSpace"
    end
    local obj = {}
    obj.nameSpace = nameSpace
    obj.app_id = app_id
    obj.is_first_pull = 0
    obj.listenerList = {}
    local cluster_name = config_util.GetClusterName()
    local meta_addr = config_util.GetMeatAddress()
    if not meta_addr or not cluster_name then
        return nil, "meta_addr or app_id missing"
    end

    obj.cluster_name = cluster_name
    obj.meta_addr = meta_addr

    return setmetatable(obj, {__index = _M})
end

function _M.getUpstreamRepository(self)
    return self.upstreamRepository
end

function _M.GetNameSpace(self)
    return self.nameSpace
end

function _M.GetAppID(self)
    return self.app_id
end

function _M.GetConfigOriginData(self)
    local app_id = self.app_id
    local cluster_name = self.cluster_name
    local meta_addr = self.meta_addr
    if not meta_addr or not app_id then
        return nil, "meta_addr or app_id missing"
    end
   
    local url = self:AssembleURL(app_id, cluster_name, meta_addr)
    ngx.log(ngx.INFO, "[GetConfigOriginData]:url:", url )

    if self.is_first_pull ~= 0 then
        -- openresty自带tcp可用
        local http = require "libs.http"
        local httpc = http:new()
        local res, err = httpc:request_uri(url, {
            method = "GET",
        })

        if not res then
            ngx.log(ngx.ERR, "GetConfigOriginData failed,err:", tostring(err))
            return nil, err
        end

        if res.status ~= 200 then
            ngx.log(ngx.INFO, "GetConfigOriginData,apollo_res:", cjson_safe.encode(res))
            httpc:close()
            return nil, "GetConfigOriginData exception"
        end

        httpc:close()
        local ret, configurations, err = self:handleApolloResponseData(res.body)
        if not ret then
            return nil, err
        end

        return ret, configurations
    else
        -- 使用luasocket库
        self.is_first_pull = 1
        local http = require("socket.http")
        local response_body = {}
        local res, code, response_headers = http.request{
            url = url,
            method = "GET",
            sink = ltn12.sink.table(response_body),
        }

        if not response_body then
            return nil, "http apollo get configs request error "
        end

        if 200 == code then
            local response_str
            if type(response_body) == "table" then
                response_str = table.concat(response_body)
            else
                response_str = response_body
            end

            ngx.log(ngx.INFO, "[GetConfigOriginData]:response_str:", response_str)
            if "string" ~= type(response_str) then
                return nil, "response_str format error"
            end

            local ret, configurations, err = self:handleApolloResponseData(response_str)
            if not ret then
                return nil, err
            end
            return ret, configurations
        end
        return nil, "bad request"
    end
    return nil, "bad request"
end

--- 处理apollo返回的body
function _M.handleApolloResponseData(self, response_str)
    local data = cjson_safe.decode(response_str)
    if data and next(data) then
        local namespaceName = data.namespaceName
        if namespaceName ~= self.nameSpace then
            return nil, nil, "return namespaceName error"
        end

        local configurations = data.configurations
        if not configurations then
            return nil, nil, "configurations missing"
        end

        local tab = table.new(0, 2)
        for k,v in pairs(configurations) do
            tab[k] = Value.new(v)
        end

        local releaseKey = data.releaseKey
        self.releaseKey = releaseKey
        return tab, cjson_safe.encode(configurations)
    end
end

function _M.AssembleURL(self, app_id, cluster_name, meta_addr)
    local tab = table.new(12, 0)
    table.insert(tab, "http://")
    table.insert(tab, meta_addr)
    table.insert(tab, "/configs/")
    table.insert(tab, app_id)
    table.insert(tab, "/")
    table.insert(tab, cluster_name)
    table.insert(tab, "/")
    table.insert(tab, self.nameSpace)
    table.insert(tab, "?ip=")
    table.insert(tab, common_util.GetLocalIP())
    return table.concat(tab)
end

function _M.addConfigChangeListener(self, listener)
    if not listener then
        return nil, "listener is missing"
    end
    table.insert(self.listenerList, listener)
    return "success"
end

function _M.onConfigChangeListener(self, event)
    if event.nameSpace ~= self:GetNameSpace() then
        return true
    end
    
    if self.listenerList and next(self.listenerList) then
        for _, listener in pairs(self.listenerList) do
            if listener then
                -- 获取最新配置
                local ret, config_origin_data, err = self:GetConfigOriginData()
                if not ret then
                    return nil, err
                end

                local event_obj = {
                    nameSpace = event.nameSpace,
                    time = event.time,
                    value_map = ret,
                    config_origin_data = config_origin_data,
                    app_id = self.app_id,
                }

                -- 通知cofig监听器
                local ok, err = listener:onConfigChange(event_obj)
                if not ok then
                    return nil, err
                end
            end
        end
    end
    return true
end

return _M