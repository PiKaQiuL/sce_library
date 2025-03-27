local function download_and_play(url)
    log.alert('开始下载录像')
    io.download_file(url, 'Replay/replay.zip', function(total, downloaded, speed)
        log.info(('下载中 : %.2f MB / %.2f MB, 下载速度 ： %.2f KB/s'):format(
            downloaded / 1024 / 1024, total / 1024 / 1024, speed / 1024))
    end,
    function(download_code)
        if download_code == 0 then
            log.alert('录像下载成功，准备解压录像')
            io.unzip_file('Replay/replay.zip', 'Replay', function(total, extracted, current)
                log.info(('文件数量 : %d, 已解压 : %d, 正在解压 : %s'):format(total, extracted, current))
            end,
            function(unzip_code)
                if unzip_code == 0 then
                    log.alert('录像解压成功，准备播放录像')
                    ui.vk_key_click(5)
                else
                    log.alert('录像解压失败, error code:', unzip_code)
                end
            end)
        else
            log.alert('录像下载失败, error code:', download_code)
        end
    end)
end

return download_and_play
