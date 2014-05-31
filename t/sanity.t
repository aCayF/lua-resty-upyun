# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    resolver \$TEST_NGINX_RESOLVER;
};

my $infile = "$pwd/t/sample.jpg";
open my $in, $infile or die "cannot open $infile for reading: $!";
our $sample_jpg = do { local $/; <$in> };
close $in;

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';

no_long_string();
no_diff();

run_tests();

__DATA__

=== TEST 1: upload normal file
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:upload_file("/acayf-file/test.txt")
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            ngx.say("upload file success")
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
upload file success
--- no_error_log
[error]



=== TEST 2: upload normal file with basic authorization
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                            author = "basic"
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:upload_file("/acayf-file/test.txt")
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            ngx.say("upload file success")
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
upload file success
--- no_error_log
[error]



=== TEST 3: upload image file
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local info, err = upyun:upload_file("/acayf-img/sample.jpg")
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end

            for k, v in pairs(info) do
                ngx.say(k .. " : " .. v)
            end
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
frames : 1
width : 400
height : 320
file-type : JPEG
--- no_error_log
[error]



=== TEST 4: upload image file with fix width
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local gmkerl = {
                            type = "fix_width",
                            value = 200,
                            unsharp = true
                           }
            local info, err = upyun:upload_file("/acayf-img/sample_fixwidth.jpg", gmkerl)
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end

            for k, v in pairs(info) do
                ngx.say(k .. " : " .. v)
            end
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
frames : 1
width : 200
height : 160
file-type : JPEG
--- no_error_log
[error]



=== TEST 5: upload image file with rotate
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local gmkerl = {
                            rotate = 90
                           }
            local info, err = upyun:upload_file("/acayf-img/sample_rotate.jpg", gmkerl)
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end

            for k, v in pairs(info) do
                ngx.say(k .. " : " .. v)
            end
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
frames : 1
width : 320
height : 400
file-type : JPEG
--- no_error_log
[error]



=== TEST 6: upload image file with crop
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local gmkerl = {
                            crop = "0,0,200,160"
                           }
            local info, err = upyun:upload_file("/acayf-img/sample_crop.jpg", gmkerl)
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end

            for k, v in pairs(info) do
                ngx.say(k .. " : " .. v)
            end
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
frames : 1
width : 200
height : 160
file-type : JPEG
--- no_error_log
[error]



=== TEST 7: upload image file with options
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                            endpoint = 0,
                           }
            local upyun = yun:new(config)

            local gmkerl = nil
            local options = { mkdir = true, md5 = true, secret = "secret", otype = "JPEG" }
            local info, err = upyun:upload_file("/acayf-img/dir/sample", gmkerl, options)
            if not info then
                ngx.say("failed to upload image file : " .. err)
                return
            end

            for k, v in pairs(info) do
                ngx.say(k .. " : " .. v)
            end
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
frames : 1
width : 400
height : 320
file-type : JPEG
--- no_error_log
[error]



=== TEST 8: download file
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:upload_file("/acayf-file/download.txt")
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            local file
            file, err = upyun:download_file("/acayf-file/download.txt")
            if not file then
                ngx.say("failed to download file : " .. err)
                return
            end

            ngx.say(file)
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
Hello World
--- no_error_log
[error]



=== TEST 9: get file info
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:upload_file("/acayf-file/getfileinfo.txt")
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            local info
            info, err = upyun:get_fileinfo("/acayf-file/getfileinfo.txt")
            if err then
                ngx.say("failed to get file info : " .. err)
                return
            end

            ngx.say("size : " .. info.size)
            ngx.say("type : " .. info.type)
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
size : 11
type : file
--- no_error_log
[error]



=== TEST 10: get image info
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:upload_file("/acayf-img/getimageinfo.jpg")
            if not ok then
                ngx.say("failed to upload image : " .. err)
                return
            end

            local info
            info, err = upyun:get_fileinfo("/acayf-img/getimageinfo.jpg")
            if err then
                ngx.say("failed to get image info : " .. err)
                return
            end

            ngx.say("size : " .. info.size)
            ngx.say("type : " .. info.type)
        ';
    }
--- request eval
"POST /t\n" . $::sample_jpg;
--- timeout: 10s
--- response_body
size : 21001
type : file
--- no_error_log
[error]



=== TEST 11: remove file and dir
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local options = {mkdir = true}
            local gmkerl = nil
            local ok, err = upyun:upload_file("/acayf-file/remove/remove.txt", gmkerl, options)
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            ok, err = upyun:remove_file("/acayf-file/remove/remove.txt")
            if not ok then
                ngx.say("failed to remove file : " .. err)
                return
            end

            ok, err = upyun:remove_file("/acayf-file/remove/")
            if not ok then
                ngx.say("failed to remove file : " .. err)
                return
            end

            ngx.say("remove file and dir success")
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
remove file and dir success
--- no_error_log
[error]



=== TEST 12: make dir
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local ok, err = upyun:make_dir("/acayf-file/makedir/", {mkdir = true})
            if not ok then
                ngx.say("failed to make dir : " .. err)
                return
            end

            ngx.say("make dir success")
        ';
    }
--- request
GET /t
--- timeout: 10s
--- response_body
make dir success
--- no_error_log
[error]



=== TEST 13: read dir
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local options = {mkdir = true}
            local gmkerl = nil
            local ok, err = upyun:upload_file("/acayf-file/readdir/readdir.txt", gmkerl, options)
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            ok, err = upyun:make_dir("/acayf-file/readdir/dir/")
            if not ok then
                ngx.say("failed to make dir : " .. err)
                return
            end

            local info
            info, err = upyun:read_dir("/acayf-file/readdir/")
            if not info then
                ngx.say("failed to read dir : " .. err)
                return
            end

            for _, v in pairs(info) do
                ngx.say(v["name"] .. " : " .. v["type"] .. " " .. v["size"])
            end
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
dir : F 0
readdir.txt : N 11
--- no_error_log
[error]



=== TEST 14: get usage
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local yun = require "resty.upyun"
            local config = {
                            user = "acayf",
                            passwd = "testupyun",
                           }
            local upyun = yun:new(config)

            local options = {mkdir = true}
            local gmkerl = nil
            local ok, err = upyun:upload_file("/acayf-file/usage/usage.txt", gmkerl, options)
            if not ok then
                ngx.say("failed to upload file : " .. err)
                return
            end

            ok, err = upyun:make_dir("/acayf-file/usage/dir/")
            if not ok then
                ngx.say("failed to make dir : " .. err)
                return
            end

            local info
            info, err = upyun:get_usage("/acayf-file/usage/")
            if not info then
                ngx.say("failed to get usage : " .. err)
                return
            end

            ngx.say(info)
        ';
    }
--- request
POST /t
Hello World
--- timeout: 10s
--- response_body
11
--- no_error_log
[error]
