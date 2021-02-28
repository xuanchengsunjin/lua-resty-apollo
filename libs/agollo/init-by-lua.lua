local process = require "ngx.process"
local ok, err = process.enable_privileged_agent()
-- 检查是否启动成功
if not ok then
    ngx.log(ngx.ERR, "create privileged process failed")
    error("create privileged process failed")
end