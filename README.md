[![Alt text](https://img.shields.io/static/v1?label=Language&message=lua&color=blue)](http://www.lua.org/)![Alt text](https://img.shields.io/static/v1?label=Release&message=V1.0.0&color=yellow)[![Alt text](https://img.shields.io/static/v1?label=Blog&message=csdn&color=blue)](https://blog.csdn.net/weixin_40783338?spm=1000.2115.3001.5343)[![Alt text](https://img.shields.io/static/v1?label=openresty&message=Nginx&color=green)](https://github.com/openresty/lua-nginx-module)



# lua-resty-apollo
------------------------------


### Content

**配置中心**实现配置的集中管理，持久化，通过配置中心，可以方便管理项目配置。对于后台服务而言,配置中心是实现**灰度发布**，配置热更新，优化代码结构。解决传统项目代码通过在项目里通过代码或文件的形式的缺点。在配置中心可以增加不同账户，配置不同**权限**，可以方便**运营、产品**等修改项目配置，更好管理。

配置中心的一般思路是创建一个**config**对象，该对象代表一个**nameSpace**的全部配置，**config**对象属性包含一个**hashMap**,通过**key-value**直观的方式,获取配置，热更新则是通过轮询[apollo](https://github.com/ctripcorp/apollo)服务，更新**hashMap**。然而[Openresty](http://openresty.org/en/)是多进程的web服务,每个**worker进程**的变量互相不影响，无法通过传统的方式实现热更新。

本设计，利用[Openresty](http://openresty.org/en/)**共享内存**实现一个本地配置仓库，每个**worker进程**中的**ConfigService**通过**轮询**的方式，检查更新，而本地配置仓库则是Openresty特权进程的轮询服务实现更新。

-------------------

### 介绍

配置中心数据仓库服务采用apollo,为此先介绍apollo相关概念:

| name             |       note | 
| ------------------------------ | ---------:| 
| app_id       | 项目ID |
| nameSpace         |     命名空间,代表一份配置文件、配置集合 | 

可以去了解一下[Apollo API开发文档](https://ctripcorp.github.io/apollo/#/zh/usage/other-language-client-user-guide)

--------------------------------------

### Installation

```bash

1 将libs目录拷贝至Openresty项目一级目录下，按下面使用说明使用。

```

### 使用


- 1. **修改nginx.conf：**
 
   http模块增加:

```bash
   lua_shared_dict config_shared 30m; # 配置中心需配置的共享内存
   init_worker_by_lua_file 'conf/libs/config/config_init_worker.lua'; # 启动相关定时服务
```
            
- 2. **修改init_by_lua.lua：**
 
   (实例化ConfigService和Config的操作需要在init_by_lua阶段完成，如果apollo服务异常，会自动宣告重启失败,保证服务不受apollo影响)
   (启动Openresty特权进程)

```lua
   local process = require "ngx.process"
   local ok, err = process.enable_privileged_agent()
   -- 检查是否启动成功
   if not ok then
      ngx.log(ngx.ERR, "create privileged process failed")
      error("create privileged process failed")
   end
   -- 获取ConfigService对象,代表一个app_id对应的配置, zdao_midservice为app_id，为全局变量
   MidConfigServive = require "libs.agollo.configService".new("zdao_midservice")
  
   -- 通过ConfigService获取config对象
   LBSConfig = MidConfigServive:GetConfig("zdao_backend.lbs")

```

- 3. **apollo相关配置：**
   通过配置文件的方式:
       /usr/local/openresty/nginx/conf/APOLLO_META_ADDR.txt apollo的metaserver地址 例如:127.0.0.1:8080

- 4. **使用：**
   
```lua 
   local lbs_config = LBSConfig:GetValue("gaude_config"):Json() -- 表示获取nameSpace为zdao_backend.lbs下gaude_config的值,并转化为json对象
```

---------------

#### 相关方法介绍

```lua
    -- 获取ConfigService对象，传参为app_id
    MidConfigServive = require "libs.agollo.configService".new("zdao_midservice")

    -- 通过ConfigService获取config对象,传参为nameSpace
    LBSConfig = MidConfigServive:GetConfig("zdao_backend.lbs")

    -- 通过Config对象获取value对象,传参为key的值
    local value = LBSConfig:GetValue("gaude_config")

    -- value相关方法
    local lbs_config = LBSConfig:GetValue("gaude_config"):Json() -- 转化为table
    local lbs_config = LBSConfig:GetValue("str"):String() -- 转化为string
    local lbs_config = LBSConfig:GetValue("num"):Int() -- 转化为int
    local lbs_config = LBSConfig:GetValue("float"):Float() -- 
    local lbs_config = LBSConfig:GetValue("bool"):Boolean() -- 
```


      