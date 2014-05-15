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
