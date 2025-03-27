local ui = ui
if ((__lua_state_name ~= 'StateEditor')) and base.local_player and ui.set_rich_text_custom_tag then
    ui.set_rich_text_custom_tag('dn', function(text, value, unit_id)
        if text and #text > 0 then
            local cache = base.eff.cache(text)
            if cache then
                return base.i18n.get_text(cache.Name)
            end
            return text
        end
        if unit_id then
            local item = base.item(unit_id)
            local unit = base.unit(unit_id)
            if item then
                return item:get_show_name()
            end
            if unit then
                return unit:get_show_name()
            end
        end
        return text
    end)
    ui.set_rich_text_custom_tag('tip', function(text, value, unit_id)
        if text and #text > 0 then
            local cache = base.eff.cache(text)
            if cache and cache.Description then
                return base.i18n.get_text(cache.Description)
            end
            return text
        end
        if unit_id then
            local item = base.item(unit_id)
            local unit = base.unit(unit_id)
            if item then
                return item:get_tips()
            end
            if unit then
                return unit:get_tips()
            end
        end
        return text
    end)
    ui.set_rich_text_custom_tag('locale', function(text, value, unit_id)
        return base.i18n.get_text(text)
    end)
    ui.set_rich_text_custom_tag('pn', function(text, value, unit_id)
        if unit_id then
            local unit = base.unit(unit_id)
            if unit then
                return unit:get_owner():get_nick_name()
            end
        end
        if value and #value > 0 then
            local n = tonumber(value)
            if n then
               return base.player(n):get_nick_name()
            end
        end
        return base.local_player():get_nick_name()
    end)
end