local tracedoc = require("tracedoc")

describe("basic tests", function()
    local plain_data = {
        hp = 50,
        hp_max = 100,
        level = 10,
        skills = {
            123,
            456,
            789,
        },
        pet = {
            name = "dog",
            level = 10,
            hp = 100,
        },
    }
    local doc = nil

    before_each(function()
        doc = tracedoc.new(plain_data) 
    end)

    after_each(function()
        doc = nil
    end)

    it("should call commit after initialize to get initial state", function()
        local changes = tracedoc.commit(doc, {})
        assert.are_not.same(changes, {})
    end)

    it("should support pairs", function()
        local function dump(doc)
            local data = {}
            for k, v in tracedoc.pairs(doc) do
                if type(v) == "table" then
                    data[k] = dump(v)
                else
                    data[k] = v
                end
            end
            return data
        end

        -- before commit
        local dump_data = dump(doc)
        assert.are.same(dump_data, plain_data)

        -- private data should not be accessed by pairs
        assert.is_nil(dump_data._parent)
        assert.is_nil(dump_data._dirty)
        assert.is_nil(dump_data._changes)

        -- after commit
        tracedoc.commit(doc)
        assert.are.same(dump(doc), plain_data)
    end)

    it("should support ipairs", function()
        local function dump(doc)
            local data = {}
            for i, v in tracedoc.ipairs(doc) do
                if type(v) == "table" then
                    table.insert(data, dump(v))
                else
                    table.insert(data, v)
                end
            end
            return data
        end

        -- before commit
        local dump_data = dump(doc.skills)
        assert.are.equal(tracedoc.len(doc.skills), #dump_data, #plain_data.skills)
        assert.are.same(dump_data, plain_data.skills)

        -- after commit
        tracedoc.commit(doc)
        assert.are.equal(tracedoc.len(doc.skills), #dump_data, #plain_data.skills)
        assert.are.same(dump(doc.skills), plain_data.skills)
    end)

    test("field changes", function()
        tracedoc.commit(doc)

        doc.hp = doc.hp + 20
        doc.level = 11

        local changes = tracedoc.commit(doc, {})
        assert.are.same(changes, {
            _n = 2,
            hp = 70,
            level = 11,
        })

        -- test for no change
        changes = tracedoc.commit(doc, {})
        assert.are.same(changes, {})
    end)

    test("field add/remove", function()
        tracedoc.commit(doc)
        doc.mp = 90
        doc.mp_max = 100
        doc.buff = 123

        local changes = tracedoc.commit(doc, {})
        assert.are.same(changes, {
            _n = 3,
            mp = 90,
            mp_max = 100,
            buff = 123,
        })

        doc.buff = nil
        changes = tracedoc.commit(doc, {})
        assert.are.equal(changes.buff, tracedoc.null)
    end)

    test("no change", function()
        tracedoc.commit(doc)

        local changes = tracedoc.commit(doc, {})
        assert.are.same(changes, {})
    end)

    test("table changes", function()
        tracedoc.commit(doc)

        doc.skills = {1, 2}
        doc.pet = {
            name = "cat",
            level = 11,
            hp = 100,
        }
        local changes = tracedoc.commit(doc, {})

        assert.are.equal(changes["skills.1"], 1)
        assert.are.equal(changes["skills.2"], 2)
        assert.are.equal(changes["skills.3"], tracedoc.null)
        assert.are.equal(changes["pet.name"], changes.pet.name, "cat")
        assert.are.equal(changes["pet.level"], changes.pet.level, 11)
        assert.is_nil(changes["pet.hp"])    -- pet.hp not changed
        
        assert.are.equal(tracedoc.len(changes.skills), 2)
        for i, v in tracedoc.ipairs(changes.skills) do
            assert.are.equal(changes["skills." .. i], v)
        end

        assert.are.equal(tracedoc.len(changes.pet), 0)
    end)

    test("opaque table", function()
        tracedoc.opaque(doc.pet, true)
        local changes = tracedoc.commit(doc, {})

        -- pet is opaque, no details
        assert.are.equal(changes["pet"], doc.pet)
        assert.are.equal(changes["pet"].name, "dog")
        assert.is_nil(changes["pet.hp"])
        assert.is_nil(changes["pet.name"])
        assert.is_nil(changes["pet.level"])

        doc.pet = {
            name = "cat",
            level = 11,
            hp = 100,
        }
        changes = tracedoc.commit(doc, {})

        assert.are.equal(changes["pet"], doc.pet)
        assert.are.equal(changes["pet"].name, "cat")
    end)

    test("_dirty state", function()
        assert.is_truthy(doc._dirty)

        -- not dirty after commit
        tracedoc.commit(doc)
        assert.is_falsy(doc._dirty)

        -- assign a same value also makes doc dirty
        doc.level = 10
        assert.is_truthy(doc._dirty)

        doc.hp = 100
        assert.is_truthy(doc._dirty)
        doc.level = 11
        assert.is_truthy(doc._dirty)

        tracedoc.commit(doc)
        assert.is_falsy(doc._dirty)
    end)

    test("sub tracedoc", function()
        tracedoc.commit(doc)

        doc.sub_doc = {
            name = "test"
        }

        local sub_changes = tracedoc.commit(doc.sub_doc, {})
        assert.are.equal(sub_changes.name, "test")

        -- sub doc changes has been commited. so parent doc changes nothing.
        local changes = tracedoc.commit(doc, {})
        assert.are.same(changes, {})
    end)
end)