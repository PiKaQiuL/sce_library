local io_read = io.read

function base.get_error_info()
    local result, version = io_read(__MAP_NAME, true)
    version = version or '-1'
    return {
        map_name = __MAP_NAME or 'unknown',
        version = tonumber(version)
    }
end