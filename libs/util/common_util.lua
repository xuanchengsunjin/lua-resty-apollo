local _M = {}

local localIP

function _M.GetEnvFromFile(key, FilePath)
    local file_path = FilePath or "/usr/local/openresty/nginx/conf/" .. key .. ".txt"
    local fp, err = io.open(file_path, "rb")
    if not err then
        local val =  string.match(fp:read("*a"), "[%w_\\.:]+")
        fp:close()
        return val
    end
    return nil, err
end

function _M.GetLocalIP()
    if localIP then
        return localIP
    end

    local socket = require("socket")
    local function GetAdd(hostname)
        local ip, resolved = socket.dns.toip(hostname)
        local ListTab = {}
        if resolved and "table" == type(resolved) then
            for k, v in ipairs(resolved.ip) do
                table.insert(ListTab, v)
            end
        end
        return ListTab
    end
    local ip = GetAdd(socket.dns.gethostname())
    if ip and "table" == type(ip) and next(ip) and unpack(ip) then
        localIP = unpack(ip)
        return localIP
    else
        localIP = "127.0.0.1"
    end
    return "127.0.0.1" 
end
return _M