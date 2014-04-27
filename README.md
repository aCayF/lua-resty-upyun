# 又拍云 lua SDK

又拍云存储lua SDK，基于 [又拍云存储HTTP REST API接口](http://docs.upyun.com/api/http_api/)，[nginx](http://nginx.org/)，[ngx_lua](https://github.com/openresty/lua-nginx-module) 开发。

**下载地址：**

* []()
* []()

**更新说明**

## 目录
* [云存储基础接口](#云存储基础接口)
  * [准备操作](#准备操作)
  * [上传文件](#上传文件)
  * [下载文件](#下载文件)
  * [获取文件信息](#获取文件信息)
  * [删除文件](#删除文件)
  * [创建目录](#创建目录)
  * [删除目录](#删除目录)
  * [获取目录文件列表](#获取目录文件列表)
  * [获取使用量情况](#获取使用量情况)
* [图片处理接口](#图片处理接口)
  * [缩略图](#缩略图)
  * [图片裁剪](#图片裁剪)
  * [图片旋转](#图片旋转)
* [错误代码表](#错误代码表)


<a name="云存储基础接口"></a>
## 云存储基础接口

<a name="准备操作"></a>
### 准备操作

##### 创建空间
大家可通过[又拍云主站](https://www.upyun.com/login.php)创建自己的个性化空间。具体教程请参见[“创建空间”](http://wiki.upyun.com/index.php?title=创建空间)。

##### 初始化UpYun
```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            endpoint = 0, --接入点
                            author = "U" --认证方式
                            }
            local upyun = yun:new(config)

            ...
        ';
    }
```

在使用`lua SDK`中的任何操作之前，都必须先按上述方式创建一个`upyun`本地变量。

若不了解`授权操作员`，请参见[“授权操作员”](http://wiki.upyun.com/index.php?title=创建操作员并授权)

##### 选择最优的接入点
根据国内的网络情况，又拍云存储API目前提供了电信、联通网通、移动铁通三个接入点。

在upyun初始化前，可以通过`endpoint`配置项进行设置。若没有明确进行设置，`upyun`默认将根据网络条件自动选择接入点。

接入点有四个值可选：

* **endpoint = 0** ：根据网络条件自动选择接入点
* **endpoint = 1** ：电信接入点
* **endpoint = 2** ：联通网通接入点
* **endpoint = 3** ：移动铁通接入点

_**注：**建议大家根据服务器网络状况，手动设置合理的接入点已获取最佳的访问速度。_

##### 选择http请求认证方式
根据用户需求，又拍云存储API目前提供了HTTP基本认证，又拍云签名认证两种认证方式，用户可以自行选择一种，为确保安全性，建议使用又拍云签名认证方式。

在upyun初始化前，可以通过`author`配置项进行设置。若没有明确进行设置，`upyun`默认将采用又拍云签名认证方式。

认证方式有两个值可选：

* **author = "B"** ：HTTP基本认证
* **author = "U"** ：又拍云签名认证
