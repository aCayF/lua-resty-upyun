-- Copyright (C) Lice Pan (aCayF)

local md5 = ngx.md5
local base64 = ngx.encode_base64
local http_time = ngx.http_time
local time_sec = ngx.time
local tcp = ngx.socket.tcp
local read_body = ngx.req.read_body
local get_body_data = ngx.req.get_body_data
local ngx_match = ngx.re.match
local ngx_gmatch = ngx.re.gmatch
local ngx_print = ngx.print
local str_sub = string.sub
local lower = string.lower
local byte = string.byte
local concat = table.concat
local insert = table.insert
local tostring = tostring
local tonumber = tonumber
local setmetatable = setmetatable
local type = type
local pairs = pairs

local HTTP_1_1 = " HTTP/1.1\r\n"

local _M = { _VERSION = '0.0.1' }

local mt = { __index = _M }

local host_list = {
    "v0.api.upyun.com",
    "v1.api.upyun.com",
    "v2.api.upyun.com",
    "v3.api.upyun.com"
}

local gmkerl_format = {
    type =   {
               type = {
                       "required",
                       ["fix_width"]="allowed", ["fix_height"]="allowed",
                       ["fix_width_or_height"]="allowed",
                       ["fix_both"]="allowed", ["fix_max"]="allowed",
                       ["fix_min"]="allowed", ["fix_scale"]="allowed"
                      },
               value = {
                        "required",
                        "([1-9][0-9]*)|([1-9][0-9]*x[1-9][0-9]*)"
                       },
               quality = {
                          "optional",
                          "[1-9][0-9]*"
                         },
               unsharp = {
                          "optional",
                          ["true"]="allowed", ["false"]="allowed"
                         },
               thumbnail = {
                            "optional",
                            "[A-Za-z0-9.]+"
                           },
               ["exif-switch"] = {
                                  "optional",
                                  ["true"]="allowed", ["false"]="allowed"
                                 }
             },
    rotate = {
               rotate = {
                         "required",
                         ["auto"]="allowed", ["90"]="allowed",
                         ["180"]="allowed", ["270"]="allowed"
                        }
             },
    crop =   {
               crop = {
                       "required",
                       "[0-9]+,[0-9]+,[1-9][0-9]*,[1-9][0-9]*"
                      },
               ["exif-switch"] = {
                                  "optional",
                                  ["true"]="allowed", ["false"]="allowed"
                                 }
             }
}



local function _rev_headers(sock)
    -- return headers, err
    local headers = {}

    while true do
        local line = sock:receive()
        local m, err = ngx_match(line, [[^([\w-]+)\s*:\s*(.+)$|(^\s*$)]])
        if err then
            return nil, "failed to parse recived header " .. err
        end

        if not m then
            return nil, "invalid recieved header : " .. line
        end

        if m[3] then
            break
        end

        headers[m[1]] = m[2]
    end

    return headers
end



local function _receive_length(sock, length)
    -- return chunk, err
    local chunk, err = sock:receive(length)
    if not chunk then
        return nil, err
    end

    return chunk
end



local function _receive_chunked(sock, maxsize)
    -- return chunks, err
    local chunks = {}

    local size = 0
    local done = false
    repeat
        local str, err = sock:receive() --receive until \r\n
        if not str then
            return nil, err
        end

        local length = tonumber(str, 16)

        if not length then
            return nil, "unable to read chunksize"
        end

        size = size + length
        if maxsize and size > maxsize then
            return nil, 'exceeds maxsize'
        end

        if length > 0 then
            local str, err = sock:receive(length)
            if not str then
                return nil, err
            end
            --print(str)
            insert(chunks, str)
        else
            done = true
        end

        -- read the \r\n
        sock:receive(2)
    until done

    return concat(chunks)
end



local function _receive(sock)
    -- return {}, err
    local line, err = sock:receive()
    if not line then
        return nil, err
    end

    local status = tonumber(str_sub(line, 10, 12))

    local headers, err = _rev_headers(sock)
    if not headers then
        return nil, err
    end

    local length = tonumber(headers["Content-Length"])
    local body, err
    --TODO
    local maxsize = 8096
    local keepalive = true

    if length then
        body, err = _receive_length(sock, length)
    else
        local encoding = headers["Transfer-Encoding"]
        if encoding and lower(encoding) == "chunked" then
            body, err = _receive_chunked(sock, maxsize)
        end
    end

    if err then
        return nil, err
    end

    local connection = headers["Connection"]
    connection = connection and lower(connection) or nil
    if connection == "close" then
        keepalive = false
    end

    if keepalive then
        sock:setkeepalive()
    else
        sock:close()
    end

    if status ~= 200 then
        local info = body
        if not info then
            info = str_sub(line, 14, -1)
        end

        return nil, info
    end

    return { status = status, headers = headers, body = body }
end



local function _req_header(method, path, headers, extra)
    -- return req
    local req = {
        method,
        " "
    }

    -- Append path
    insert(req, path)

    -- Append version
    insert(req, HTTP_1_1)

    -- Append headers
    for key, value in pairs(headers) do
        insert(req, key .. ": " .. value .. "\r\n")
    end

    -- Append extra
    if extra ~= {} and extra ~= nil then
        for key, value in pairs(extra) do
            insert(req, key .. ": " .. value .. "\r\n")
        end
    end

    -- Close headers
    insert(req, "\r\n")

    return concat(req)
end



local function _request(sock, method, path, headers, body, extra)
    -- return {}, err
    local host = headers.Host
    if not sock then
        return nil, "not initialized yet"
    end

    sock:settimeout(5000)

    local ok, err = sock:connect(host, 80)
    if not ok then
        return nil, err
    end

    -- Build and send request header
    local header = _req_header(method, path, headers, extra)
    local bytes, err = sock:send(header)
    if not bytes then
        return nil, err
    end

    -- Send the body if there is one
    if body and body.content then
        local bytes, err = sock:send(body.content)
        if not bytes then
            return nil, err
        end
    end

    return _receive(sock)
end



local function _upyun_request(self, method, path, headers, body, extra)
    local sock = self.sock
    local author_mode = self.author_mode
    local length = headers["Content-Length"]
    local signature

    if author_mode == "U" then
        signature = md5(method .. "&" .. path .. "&" .. headers.Date
                        .. "&" .. length
                        .. "&" .. md5(self.passwd))

        headers.Authorization = headers.Authorization .. signature
    end

    return _request(sock, method, path, headers, body, extra)
end



local function _is_dir(path)
    -- return true or false
    return str_sub(path, -1, -1) == "/"
end



local function _parse_gmkerl(gmkerl, extra)
    -- return ok, err
    local expect_format = true
    local format

    for k, v in pairs(gmkerl_format) do
        -- find the format
        if gmkerl[k] and gmkerl[k] ~= "" then
            if not expect_format then
                return nil, "duplicated format"
            end

            format = v
            expect_format = false
        end
    end

    if expect_format then
        return nil, "invalid gmkerl"
    end

    for k, v in pairs(format) do
        local value = tostring(gmkerl[k])
        if value == "nil" or value == "" then
            if v[1] == "required" then
                return nil, "missing required arg : " .. k
            end

            --do nothing to optinal arg
        else
            if v[value] ~= "allowed" then
                if not v[2] then
                    return nil, 'invalid value "'
                                .. value .. '" to ' .. k
                end

                -- regex is stored in the v[2]
                local m ,err = ngx_match(value, v[2])
                if err then
                    return nil, "error occurs when matching "
                                .. value .. " with " .. v[2]
                end

                if not m then
                    return nil, 'invalid value "'
                                .. value .. '" to ' .. k
                end

                value = m[0]
            end

            extra["x-gmkerl-" .. k] = value
        end
    end

    return true
end



local function _format_path(path, legal_path)
    -- return path, err
    if not path or type(path) ~= "string" or path == "" then
        return nil, "invalid path : " .. path
    end

    if legal_path == "dir" and not _is_dir(path) then
        return nil, path .. " is not a legal directory name"
    end

    if legal_path == "file" and _is_dir(path)then
        return nil, path .. " is not a legal file name"
    end

    -- checking is not needed when legal_path is "dir_or_file"

    -- pre insert a "/" if needed
    path = str_sub(path, 1, 1) == "/" and path or "/" .. path

    return path
end



local function _parse_upyun_option(option, extra, content)
    -- return modified extra
    local mkdir = tostring(option.mkdir)
    local omd5 = tostring(option.md5)
    local secret = option.secret
    local otype = option.type

    if mkdir == "true" or mkdir == "false" then
        extra["Mkdir"] = mkdir
    end

    if omd5 == "true" then
        extra["Content-MD5"] = md5(content)
    end

    if type(secret) == "string" then
        extra["Content-Secret"] = secret
    end

    if type(otype) == "string" then
        extra["Content-Type"] = otype
    end
end



local function _parse_upyun_headers(headers, regex)
    -- return info, err
    if not headers or type(headers) ~= "table" then
        return nil, "missing recieved headers"
    end

    local info = {}
    for k, v in pairs(headers) do
        
        local m, err = ngx_match(k, regex)
        if err then
            return nil, "failed to parse upyun headers " .. err
        end

        if m then
            info[m[1]] = v
        end
    end

    return info
end



local function _parse_upyun_body(body)
    -- return info, err
    if not body or type(body) ~= "string" then
        return nil, "missing recieved body"
    end

    local iterator, err = ngx_gmatch(body, [[([^\n\t]+)(\n|\t|$)]])
    if not iterator then
        return nil, err
    end

    local i = 1
    local j = 1
    local file
    local info = {}
    local key = {"name", "type", "size", "lastmodified"}
    while true do
        local m, err = iterator()
        if err then
            return nil, err
        end

        if not m then
            break
        end

        if j == 1 then
            info[i] = {}
            file = info[i]
        end

        file[key[j]] = m[1]
        j = j + 1

        if m[2] == "\n" then
            if j ~= 5 then
                return nil, "invalid upyun body " .. body
            end

            i = i + 1
            j = 1
        end
    end

    return info
end



function _M.new(self, config)
    local user = config.user
    local passwd = config.passwd
    local endpoint = config.endpoint and tonumber(config.endpoint) + 1 or 1
    local author = config.author and lower(config.author) or nil

    if not user or type(user) ~= "string" or user == "" then
        return nil, "invalid user"
    end

    if not passwd or type(passwd) ~= "string" or passwd == "" then
        return nil, "invalid passwd"
    end

    if endpoint > 4 then
        return nil, "invalid endpoint"
    end

    -- explicit "basic" sets author_mode to Basic
    local author_mode = "U"
    if author == "basic" then
        author_mode = "B"
        author = "Basic " .. base64(user .. ":" .. passwd)
    else
        author = "UpYun " .. user .. ":"
    end

    -- file to be uploaded is stored in the request body
    read_body()
    local content = get_body_data()
    local file = ngx.req.get_body_file()
    if file then
        local f, err = io.open(file, "r")
        if not f then
            return nil, err
        end

        content = f:read("*a")
        f:close()
    end

    --if not content then
    --    return nil, "request body is expected"
    --end

    --TODO ngx.updatetime?
    local date = http_time(time_sec())
    if not date then
        return nil, "failed to get current time"
    end

    local sock = tcp()
    if not sock then
        return nil, "failed to create a TCP socket"
    end

    return setmetatable ({
        sock = sock,
        user = user,
        passwd = passwd,
        author_mode = author_mode,
        headers = {
          Authorization = author,
          Host = host_list[endpoint],
          Date = date,
          ["Content-Length"] = "0"
        },
        body = {content = content},
    }, mt)
end



function _M.upload_file(self, path, gmkerl, option)
    -- return info, err
    local headers = self.headers
    local author = headers.Authorization
    local body = self.body
    local content = body.content
    local legal_path = "file"
    local extra = {}
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    if gmkerl and type(gmkerl) == "table" and gmkerl ~= {} then
        local ok, err = _parse_gmkerl(gmkerl, extra)
        if not ok then
            return nil, err
        end

    end

    -- file to be uploaded is stored in the request body
    if not content or content == "" then
        return nil, "request body is expected"
    end

    if option and type(option) == "table" then
        _parse_upyun_option(option, extra, content)
    end

    headers["Content-Length"] = tostring(#content)

    ret, err = _upyun_request(self, "PUT", path, headers, body, extra)
    if not ret then
        return nil, err
    end

    ret, err = _parse_upyun_headers(ret.headers, [[^x-upyun-([\w-]+)$]])
    if not ret then
        return nil, err
    end

    -- write the original author back as header.Authorization
    -- may be changed in the _upyun_request()
    headers.Authorization = author
    headers["Content-Length"] = "0"

    return ret
end



function _M.download_file(self, path)
    -- return file, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "file"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    ret, err = _upyun_request(self, "GET", path, headers)
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return ret.body
end



function _M.get_fileinfo(self, path)
    -- return info, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "file"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    ret, err = _upyun_request(self, "HEAD", path, headers)
    if not ret then
        return nil, err
    end

    ret, err = _parse_upyun_headers(ret.headers, [[^x-upyun-file-([\w-]+)$]])
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return ret
end



function _M.remove_file(self, path)
    -- return ok, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "dir_or_file"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    ret, err = _upyun_request(self, "DELETE", path, headers)
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return true
end



function _M.make_dir(self, path, option)
    -- return ok, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "dir"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    local extra = { Folder = "true" }
    if option and type(option) == "table" then
        _parse_upyun_option(option, extra)
    end

    ret, err = _upyun_request(self, "POST", path, headers, nil, extra)
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return true
end



function _M.read_dir(self, path)
    -- return items, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "dir"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    ret, err = _upyun_request(self, "GET", path, headers)
    if not ret then
        return nil, err
    end

    ret, err = _parse_upyun_body(ret.body)
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return ret
end



function _M.get_usage(self, path)
    -- return usage, err
    local headers = self.headers
    local author = headers.Authorization
    local legal_path = "dir_or_file"
    local ret, err

    path, err = _format_path(path, legal_path)
    if not path then
        return nil, err
    end

    path = path .. "?usage"

    ret, err = _upyun_request(self, "GET", path, headers)
    if not ret then
        return nil, err
    end

    headers.Authorization = author

    return ret.body
end



return _M
