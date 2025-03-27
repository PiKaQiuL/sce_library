base.select_indicator = nil

base.game:event('单位-选中', function (_, player, unit)
    if not base.select_indicator_enable then
        return
    end
    if not player or not unit then
        return
    end
    local unit_cache = base.eff.cache(unit:get_name())
    if not unit_cache then
        return
    end
    local unit_attackable_radius = unit_cache.AttackableRadius or 0
    local gameplay = base.eff.cache("$$.gameplay.dflt.root")
    if not gameplay or not gameplay.SelectIndicator then
        return 
    end
    local indicator_link
    if player == unit:get_owner() and gameplay.SelectIndicator['选中自身单位'] then
        indicator_link = gameplay.SelectIndicator['选中自身单位']
    end
    if player:is_ally(unit:get_owner()) and gameplay.SelectIndicator['选中友方单位'] then
        indicator_link = gameplay.SelectIndicator['选中友方单位']
    end
    if player:is_enemy(unit:get_owner()) and gameplay.SelectIndicator['选中敌方单位'] then
        indicator_link = gameplay.SelectIndicator['选中敌方单位']
    end
    if player:is_neutral_to(unit:get_owner()) and gameplay.SelectIndicator['选中中立单位'] then
        indicator_link = gameplay.SelectIndicator['选中中立单位']
    end
    if indicator_link then
        local indicator_cache = base.eff.cache(indicator_link)
        if not indicator_cache then
            return
        end
        local effect_cache
        if indicator_cache.Effect then
            effect_cache = base.eff.cache(indicator_cache.Effect)
        end
        if indicator_cache.Model then
            effect_cache = base.eff.cache(indicator_cache.Model)
        end
        if not effect_cache then
            return
        end
        local effect_radius = effect_cache.AutoScaleBaseRadius or 128
        local effect_scale = indicator_cache.ScaleByParent == 1 and unit_attackable_radius/effect_radius or indicator_cache.Scale or 1
        base.select_indicator = base.actor(indicator_link)
        base.select_indicator:set_scale(effect_scale)
        base.select_indicator:attach_to(unit)
        base.select_indicator:play()
    end
end)

base.game:event('单位-取消选中', function (_, player, unit)
    if base.select_indicator then
        base.select_indicator:destroy()
        base.select_indicator = nil
    end
end)