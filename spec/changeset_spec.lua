local tracedoc = require("tracedoc")

describe("changeset tests", function()
    local plain_data = {
        level = 10,
        name = "Player",
        title = "",
        hp = 100,
        hp_max = 100,
    }
    local doc = nil

    local print_buf = {}
    local function _print(...)
        -- print(...)
        table.insert(print_buf, table.concat({...}, "\t"))
    end

    local function get_print_content()
        return table.concat(print_buf, "\n")
    end

    local function clear_print_buf()
        print_buf = {}
    end

    local function trim_lines(str)
        return str:gsub("^%s+", ""):gsub("\n%s+", "\n")
    end

    local spies = {}
    local function create_spy(name, func)
        local s = spy.new(func)
        spies[name] = s
        return function(...)
            return s(...)
        end
    end

    local function clear_spies()
        spies = {}
    end

    before_each(function()
        doc = tracedoc.new(plain_data) 
        clear_print_buf()
        clear_spies()
    end)

    after_each(function()
        doc = nil
    end)

    test("test mapchange/mapupdate", function()
        local mapping = tracedoc.changeset {
            {
                "LEVEL",
                create_spy("level", function(doc, level)
                    _print("level = " .. level)
                end),
                "level",
            },
            {
                "HP",
                create_spy("hp", function(doc, hp)
                    _print("hp = " .. hp)
                end),
                "hp",
            },
            {
                "HP_MAX",
                create_spy("hp_max", function(doc, hp_max, buff)
                    local hp_max_modify = buff and buff.hp_max_modify or 0
                    hp_max_modify = hp_max_modify or 0
                    _print("hp_max = " .. hp_max + hp_max_modify)
                end),
                "hp_max",
                "buff",
            },
            {
                "ITEM",
                create_spy("item", function(doc, items)
                    _print("items count = " .. tracedoc.len(items))
                end),
                "items",
            },
            {
                "NAME",
                create_spy("name", function(doc, name, title)
                    local full_name = name
                    if title and #title > 0 then
                        full_name = full_name .. " - " .. title
                    end
                    _print("name = " .. full_name)
                end),
                "name",
                "title",
            },
            {
                -- no tag
                create_spy("no_tag", function(doc, hp)
                end),
                "hp",
            },
        }

        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.level).was_called_with(doc, plain_data.level)
        assert.spy(spies.hp).was_called_with(doc, plain_data.hp)
        assert.spy(spies.hp_max).was_called_with(doc, plain_data.hp_max, nil)
        assert.spy(spies.name).was_called_with(doc, plain_data.name, plain_data.title)
        clear_print_buf();

        doc.hp = doc.hp + 10
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.hp).was_called_with(doc, plain_data.hp + 10)
        assert.are.same(get_print_content(), trim_lines(
            [[hp = 110]]))
        clear_print_buf();

        doc.title = "Super Man"
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.name).was_called_with(doc, plain_data.name, "Super Man")
        assert.are.same(get_print_content(), trim_lines(
            [[name = Player - Super Man]]))
        clear_print_buf();     

        doc.items = {1, 2, 3}
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.item).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[items count = 3]]))
        clear_print_buf()

        doc.buff = { hp_max_modify = 100}
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.hp_max).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[hp_max = 200]]))
        clear_print_buf()

        -- filter LEVEL tag
        tracedoc.mapupdate(doc, mapping, "LEVEL")
        assert.spy(spies.level).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[level = 10]]))
        clear_print_buf()

        -- filter no tag
        tracedoc.mapupdate(doc, mapping, "")
        assert.spy(spies.no_tag).was_called()
        clear_print_buf();

        -- filter all tag
        tracedoc.mapupdate(doc, mapping)
        assert.spy(spies.level).was_called()
        assert.spy(spies.hp).was_called()
        assert.spy(spies.item).was_called()
        assert.spy(spies.name).was_called()
    end)
    
    test("support for reading a non-exist field", function()
        local mapping = tracedoc.changeset {
            {
                "HP_MAX",
                create_spy("hp_max", function(doc, hp_max, hp_max_modify)
                    hp_max_modify = hp_max_modify or 0
                    _print("hp_max = " .. hp_max + hp_max_modify)
                end),
                "hp_max",
                "buff.hp_max_modify",   -- not exist yet
            },
        }

        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.hp_max).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[hp_max = 100]]))
        clear_print_buf()

        doc.buff = { hp_max_modify = 100 }  -- buff.hp_max_modify added
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies.hp_max).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[hp_max = 200]]))
        clear_print_buf()
    end)

    test("support for apply changes to multiple changesets", function()
        local mapping1 = tracedoc.changeset {
            {
                "HP",
                create_spy("hp1", function(doc, hp)
                    _print("mapping1: hp = " .. hp)
                end),
                "hp",
            },
        }

        local mapping2 = tracedoc.changeset {
            {
                "HP",
                create_spy("hp2", function(doc, hp)
                    _print("mapping2: hp = " .. hp)
                end),
                "hp",
            },
        }

        local changes = tracedoc.commit(doc, {})
        tracedoc.mapchange_without_commit(doc, mapping1, changes)
        assert.spy(spies.hp1).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[mapping1: hp = 100]]))
        clear_print_buf()

        tracedoc.mapchange_without_commit(doc, mapping2, changes)
        assert.spy(spies.hp2).was_called()
        assert.are.same(get_print_content(), trim_lines(
            [[mapping2: hp = 100]]))
        clear_print_buf()
    end)

    test("for issue #4", function()
        local doc = tracedoc.new {d = true, e = 1}
        tracedoc.commit(doc)
        local mapping = tracedoc.changeset {
            { create_spy("issue#4", function(doc, d, e) _print("changed") end), "d", "e" }
        }
        doc.d = false
        tracedoc.mapchange(doc, mapping)
        assert.spy(spies["issue#4"]).was_called()
    end)
end)
