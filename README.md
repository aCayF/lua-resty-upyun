# 又拍云 lua SDK

又拍云存储lua SDK，基于 [又拍云存储HTTP REST API接口](http://docs.upyun.com/api/http_api/)，[nginx](http://nginx.org/)，[ngx_lua](https://github.com/openresty/lua-nginx-module) 开发。

**下载地址：**

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
                            author = "upyun" --认证方式
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

* **endpoint = 0** ：根据网络条件自动选择接入点(默认值)
* **endpoint = 1** ：电信接入点
* **endpoint = 2** ：联通网通接入点
* **endpoint = 3** ：移动铁通接入点

_**注：**建议大家根据服务器网络状况，手动设置合理的接入点已获取最佳的访问速度。_

##### 选择http请求认证方式
根据用户需求，又拍云存储API目前提供了HTTP基本认证，又拍云签名认证两种认证方式，用户可以自行选择一种，为确保安全性，建议使用又拍云签名认证方式。

在upyun初始化前，可以通过`author`配置项进行设置。若没有明确进行设置，`upyun`默认将采用又拍云签名认证方式。

认证方式有两个值可选：

* **author = "basic"** ：HTTP基本认证
* **author = "upyun"** ：又拍云签名认证(默认值)

<a name="上传文件"></a>
### 上传文件

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local savePath = "/acayf-img/sample.jpg"
            local gmkerl = nil
            local options = {
                             mkdir = true, 
                             md5 = true, 
                             secret = "secret", 
                             otype = "JPEG"
                            }
            local info, err = upyun:upload_file(savePath, gmkerl, options)
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end
        ';
    }
```

##### 参数说明
* `savePath`(必须项，不可为`nil`)，要保存到又拍云存储的具体地址
  * 比如`/acayf-img/sample.jpg`表示以`sample.jpg`为文件名保存到`/acayf-img`空间下；
  * 若保存路径为`/sample.jpg`，则表示保存到根目录下，也可以保存到该空间的其他目录下，如`/acayf-img/dir/sample.jpg`；
  * **注意`savePath`的路径必须是以`/`开始的**，下同。
* `gmkerl`(非必须项，可为`nil`)，上传图片时，允许直接对图片进行旋转、裁剪、缩略图等操作，具体请参见[图片处理接口](#图片处理接口)
* `options`(非必须项，可为`nil`)：
  * `mkdir`，表示当不存在父级目录时是否自动创建父级目录（只支持自动创建10级以内的父级目录）
  * `md5`，表示上传文件时是否进行文件的`MD5`校验：若又拍云服务端收到的文件MD5值与用户设置的不一致，将返回 `406 Not Acceptable` 错误。
     对于需要确保上传文件的完整性要求的业务，可以设置该参数。
  * `secret`，用于提供用户密钥，图片类空间若设置过[缩略图版本号](http://wiki.upyun.com/index.php?title=如何创建自定义缩略图)，
     即可使用原图保护功能（**文件类空间无效**）。 原图保护功能需要设置一个自定义的密钥（只有您自己知道，如上面的`secret`）。
     待文件保存成功后，将无法根据`http://空间名.b0.upaiyun.com/文件名`直接访问上传的文件，
     而是需要在 URL 后面加上`缩略图间隔标志符+密钥`进行访问。
     比如当[缩略图间隔标志符](http://wiki.upyun.com/index.php?title=如何使用自定义缩略图)为`!`，密钥为`secret`，
     上传的文件路径为`/dir/sample.jpg`，那么该图片访问 URL 为: `http://空间名.b0.upaiyun.com/dir/sample.jpg!secret`，
     若原图保护密钥若与[缩略图版本号](http://wiki.upyun.com/index.php?title=如何创建自定义缩略图)名称相同，
     则在对外访问时将被视为是缩略图功能，而原图将无法访问，请慎重使用。
  * `otype`，用于指定文件类型，当待上传的文件扩展名不存在，或扩展名不足以判断文件的`Content-Type`时，允许用户自己设置文件的`Content-Type`值。
     又拍云存储默认使用文件名的扩展名进行自动设置。


##### 其他说明
* 具体用户希望上传到又拍云空间的 **文件内容将从用户向`Nginx`发起的请求包体中获得**
* 文件上传成功后，可直接通过`http://空间名.b0.upaiyun.com/文件名`来访问文件
* 图片类空间上传文件后，函数会返回文件的基本信息，可通过`info`返回值来获取：

```
        info["width"]      // 图片宽度
        info["height"]     // 图片高度
        info["frames"]     // 图片帧数
        info["file-type"]  // 图片类型
```

##### 注意事项
* 如果空间内`savePath`已经存在文件，将进行覆盖操作，并且是**不可逆**的。所以如果需要避免文件被覆盖的情况，可以先通过[获取文件信息](#获取文件信息)操作来判断是否已经存在旧文件。
* 图片类空间只允许上传图片类文件，其他文件上传时将返回“不是图片”的错误。
* 如果上传失败，则会抛出异常。

<a name="下载文件"></a>
### 下载文件

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local savePath = "/acayf-img/sample.jpg"
            local ok, err = upyun:download_file(savePath)
            if not ok then
                ngx.say("failed to downlod file : " .. err)
                return
            end
        ';
    }
```

##### 参数说明
* `savePath`：又拍云存储中文件的具体保存地址。比如`/acayf-img/sample.jpg`。

##### 注意事项
* 下载文件时必须确保空间下存在该文件，否则将返回`文件不存在`错误



<a name="获取文件信息"></a>
### 获取文件信息

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local savePath = "/acayf-img/sample.jpg"
            local info, err = upyun:get_fileinfo(savePath)
            if not info then
                ngx.say("failed to get file info : " .. err)
                return
            end
        ';
    }
```

##### 参数说明
* `savePath`：又拍云存储中文件的具体保存地址。比如`/acayf-img/sample.jpg`。

##### 其他说明
* 最终返回的结果保存在`info`变量中，变量中包含了文件的“文件类型”、“文件大小”和“创建日期”信息

```
   * info["type"]; // 文件类型
   * info["size"]; // 文件大小
   * info["date"]; // 创建日期
```

* 若文件不存在，则抛出异常，请做好对结果的判断。



<a name="删除文件"></a>
### 删除文件

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local savePath = "/acayf-file/test.txt"
            local ok, err = upyun:remove_file(savePath)
            if not ok then
                ngx.say("failed to remove file : " .. err)
                return
            end

        ';
    }
```
    
##### 参数说明
* `savePath`：又拍云存储中文件的具体保存地址。比如`/acayf-file/test.txt`。

##### 其他说明
* 删除文件时必须确保空间下存在该文件，否则将返回`文件不存在`的错误



<a name="创建目录"></a>
### 创建目录

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local dir = "/acayf-file/test/"
            local ok, err = upyun:make_dir(dir)
            if not ok then
                ngx.say("failed to make dir : " .. err)
                return
            end

        ';
    }
```
    
##### 参数说明
* `dir`：待创建的目录结构。比如`/acayf-file/test/`



<a name="删除目录"></a>
### 删除目录

```lua
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf", --授权操作员名称
                            passwd = "testupyun", --操作员密码
                            }
            local upyun = yun:new(config)

            local dir = "/acayf-file/test/"
            local ok, err = upyun:remove_file(dir)
            if not ok then
                ngx.say("failed to remove dir : " .. err)
                return
            end

        ';
    }
```

##### 参数说明
* `dir`：待删除的目录结构。比如`/acayf-file/test/`

##### 其他说明
* 该操作只能删除单级目录，不能一次性同时删除多级目录，比如当存在`/dir1/dir2/dir3/`目录时，不能试图只传递`/dir1/`来删除所有目录。
* 若待删除的目录`dir`下还存在任何文件或子目录，将返回`不允许删除`的错误。比如当存在`/dir1/dir2/dir3/`目录时，将无法删除`/dir1/dir2/`目录。
