local colourValue = require("presets/colour_value")
local slots = require("presets/slots")
local constants = require("constants")
local customisations = {}

-- Dependencies are explicit so editor and native-swap entry points share one path.
function customisations.new(names, colours, icons, iconText)
    local service = {}
    local function failure(message, status, details)
        return false, message, { status = status, details = details }
    end

    function service.apply(changes)
        local writes = {}
        local prepared, preparationError = pcall(function()
            local context = names.getContext()
            assert(context, "Log in before saving customisations.")
            -- Validate every destination before reading snapshots or writing anything.
            for _, change in ipairs(changes) do
                assert(slots.customisable(change.slot), "Invalid preset slot.")
                local value, message = names.normalize(change.name)
                assert(value, message)
                writes[#writes + 1] = { slot = change.slot, kind = "name", value = value,
                    get = function() return names.get(change.slot) or "" end,
                    save = function(v) return names.save(change.slot, v) end }
                if colours then
                    for _, kind in ipairs(constants.colourKinds) do
                        local colour = change[kind]
                        local normalized = colour == "" and "" or colourValue.normalize(colour)
                        assert(normalized, "Invalid colour selection.")
                        writes[#writes + 1] = { slot = change.slot, kind = kind, value = normalized,
                            get = function() return colours.get(change.slot, kind) end,
                            save = function(v) return colours.save(change.slot, kind, v) end }
                    end
                end
                -- Omitted icons preserve existing values for callers that have not
                -- integrated icon editing yet. An explicit "" resets to the number.
                if icons and change.icon ~= nil then
                    local icon, iconMessage = icons.normalize(change.icon)
                    assert(icon ~= nil, iconMessage)
                    assert(slots.valid(change.slot) or icon == "", "Beast of Burden does not support custom icons.")
                    if slots.valid(change.slot) then
                        writes[#writes + 1] = { slot = change.slot, kind = "icon", value = icon,
                            get = function() return icons.get(change.slot) end,
                            save = function(v) return icons.save(change.slot, v) end }
                    end
                end
                if iconText and change.iconText ~= nil then
                    local value, message = iconText.normalize(change.iconText)
                    assert(value ~= nil, message)
                    assert(slots.valid(change.slot) or value == "", "Beast of Burden does not support icon text.")
                    if slots.valid(change.slot) then
                        writes[#writes + 1] = { slot = change.slot, kind = "icon text", value = value,
                            get = function() return iconText.get(change.slot) end,
                            save = function(v) return iconText.save(change.slot, v) end }
                    end
                end
            end
            for _, write in ipairs(writes) do write.old = write.get() end
            assert(names.getContext() == context, "Character changed before saving.")
        end)
        if not prepared then
            return failure(tostring(preparationError), "failed", { tostring(preparationError) })
        end
        for index, write in ipairs(writes) do
            local called, saved, message = pcall(write.save, write.value)
            if not called or not saved then
                local details = { ("slot %d %s: %s"):format(write.slot, write.kind,
                    tostring(called and message or saved)) }
                local recovered = true
                -- Include the failing write: it may have persisted before verification failed.
                for rollback = index, 1, -1 do
                    local previous = writes[rollback]
                    local ok, restored, reason = pcall(previous.save, previous.old)
                    if not ok or not restored then
                        recovered = false
                        details[#details + 1] = ("recovery slot %d %s: %s"):format(
                            previous.slot, previous.kind, tostring(ok and reason or restored))
                    end
                end
                print("[Custom bank presets] Grouped save failed: " .. table.concat(details, "; "))
                return failure(recovered
                    and "Save failed. Previous customisations restored. See the client console."
                    or "Save failed; recovery incomplete. Check customisations and the client console.",
                    recovered and "recovered" or "recovery_failed", details)
            end
        end
        return true, icons and "Customisations saved."
            or (colours and "Name and colours saved." or "Name saved."), { status = "success" }
    end

    function service.save(slot, values)
        return service.apply({ { slot = slot, name = values.name,
            background = values.background, text = values.text, icon = values.icon, iconText = values.iconText } })
    end

    function service.swap(first, second)
        if not slots.valid(first) or not slots.valid(second) then
            return failure("Invalid preset slot.", "failed")
        end
        if first == second then return true, nil, { status = "success" } end
        local ok, changes = pcall(function()
            local context = names.getContext()
            assert(context, "Log in before swapping customisations.")
            local result = {}
            local transfers = {
                { destinationSlot = first, sourceSlot = second },
                { destinationSlot = second, sourceSlot = first },
            }
            for _, transfer in ipairs(transfers) do
                result[#result + 1] = {
                    slot = transfer.destinationSlot,
                    name = names.get(transfer.sourceSlot) or "",
                    background = colours and colours.get(transfer.sourceSlot, "background"),
                    text = colours and colours.get(transfer.sourceSlot, "text"),
                    icon = icons and icons.get(transfer.sourceSlot),
                    iconText = iconText and iconText.get(transfer.sourceSlot),
                }
            end
            assert(names.getContext() == context, "Character changed before swapping.")
            return result
        end)
        if not ok then return failure(tostring(changes), "failed", { tostring(changes) }) end
        return service.apply(changes)
    end
    return service
end

return customisations
