--- lua_plus ---
function base.camera_focus(unit:unit)
    ---@ui 设定相机视角跟随单位~1~
    ---@description 设定相机跟随
    ---@applicable action
    ---@belong camera
    ---@keyword 相机 跟随
    base.game:camera_focus(unit)
end

function base.camera_lock()
    ---@ui 锁定相机视角
    ---@description 锁定相机视角
    ---@applicable action
    ---@belong camera
    ---@keyword 相机 锁定
    base.game.lock_camera()
end

function base.camera_unlock()
    ---@ui 解锁相机视角
    ---@description 解锁相机视角
    ---@applicable action
    ---@belong camera
    ---@keyword 相机 解锁
    base.game.unlock_camera()
end

function base.camera_is_locked() boolean
    ---@ui 判断相机视角是否锁定
    ---@description 判断相机视角是否锁定
    ---@applicable value
    ---@belong camera
    ---@keyword 相机 锁定
    return base.game.is_camera_locked()
end

function base.set_camera_attribute(key:string, value:unknown, time:number)
    ---@ui 设定相机~1~的属性为~2~，过渡时间为~3~秒
    ---@description 设置相机属性
    ---@applicable action
    ---@belong camera
    ---@keyword 相机 镜头 属性
    base.game:set_camera_attribute(key, value, time)
end
