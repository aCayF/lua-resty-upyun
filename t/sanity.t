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
