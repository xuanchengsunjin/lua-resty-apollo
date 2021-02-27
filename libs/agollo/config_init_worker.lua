local process = require "ngx.process"
local ConfigServiveModule = require "libs.agollo.configService"
if process.type() == "privileged agent" then
    -- 在特权进程中启动一些apollo配置中心热更新服务
    -- 定期向apollo客户端查询是否更新,如果有更新,通知监听器更新openresty共享内存
    if ConfigServiveModule then
        ConfigServiveModule.ExcutePrivilegeHotUpdateTask()
    end
elseif process.type() == "worker" then
    -- 在worker进程中启动一些apollo配置中心热更新服务,定期查询openresty共享内存中的notificationId,从openresty共享内存更新本地配置变量
    if ConfigServiveModule then
        ConfigServiveModule.ExcuteWorkerSubmitHotUpdateTask()
    end
end