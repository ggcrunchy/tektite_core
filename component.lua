--- This module provides utilities for components.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local assert = assert
local pairs = pairs
local rawequal = rawequal
local type = type

-- Modules --
local adaptive = require("tektite_core.table.adaptive")
local array_funcs = require("tektite_core.array.funcs")
local meta = require("tektite_core.table.meta")

-- Cached module references --
local _CanAddToObject_
local _RemoveFromObject_

-- Exports --
local M = {}

--
--
--

local RequiredTypes, Types = {}, {}

local function GatherRequiredTypes (ctype)
    RequiredTypes[ctype] = true

    local info = Types[ctype]
    local reqs = info and info.requirements

    if reqs then
        for k in adaptive.IterSet(reqs) do
            if not RequiredTypes[k] then
                GatherRequiredTypes(k)
            end
        end
    end
end

local Lists = meta.Weak("k")

--- DOCME
function M.AddToObject (object, ctype)
    local can_add = _CanAddToObject_(object, ctype)

    if _CanAddToObject_(object, ctype) then
        GatherRequiredTypes(ctype) -- n.b. set up by CanAddToObject()

        local list = Lists[object]

        for rtype in pairs(RequiredTypes) do
            local info = Types[rtype]
            local on_add = info and info.add

            if on_add then
                on_add(object, rtype)
            end

            list, RequiredTypes[rtype] = adaptive.AddToSet(list, ctype)
        end

        Lists[object] = list
    end

    return can_add
end

local function AllowedByCurrentList (list, object, ctype)
    for comp in adaptive.IterSet(list) do
        local info = Types[comp]
        local on_allow_add = info and info.allow_add

        if on_allow_add then
            local ok, err = on_allow_add(ctype, object, comp)

            if not ok then
                return false, err
            end
        end
    end

    return true
end

local function EnsureRequiredTypesInfo (info)
    local req_list = info and info.requirement_list

    if req_list then -- not yet resolved?
        local reqs, rlist = {}, info.requirement_list -- save list in case of error...

        info.requirement_list = nil -- ...but remove it to guard against recursion

        for i = 1, #req_list do
            local rtype = req_list[i]
            local rinfo = Types[rtype]

            if rinfo == nil or not EnsureRequiredTypesInfo(rinfo) then
                info.requirement_list = rlist -- failure, so restore list

                return false
            else
                reqs[rtype] = true
            end
        end

        info.requirements = reqs
    end

    return true
end

--- DOCME
function M.CanAddToObject (object, ctype)
    local list, info = Lists[object], Types[ctype]

    if info == nil then
        return false, "Type not registered"
    elseif adaptive.InSet(list, ctype) then
        return false, "Already present"
    elseif not EnsureRequiredTypesInfo(info) then -- resolve any requirements on first request
        return false, "Required type not registered"
    else
        if info and info.requirements then -- ensure we can add required components, if necessary...
            for rtype in pairs(info.requirements) do
                if not adaptive.InSet(list, rtype) then
                    local ok, err = AllowedByCurrentList(list, object, rtype)

                    if not ok then
                        return false, err
                    end
                end
            end
        end

        return AllowedByCurrentList(list, object, ctype) -- ...as well as the requested one
    end

    return true
end

--- DOCME
function M.GetInterfacesForObject (object, out)
    out = out or {}

    local n = 0

    for comp in adaptive.IterSet(Lists[object]) do
        local info = Types[comp]

        for i = 1, #(info or "") do
            out[n + 1], n = info[i], n + 1
        end
    end

    for i = #out, n + 1, -1 do
        out[i] = nil
    end

    array_funcs.RemoveDups(out)

    return out
end

--- DOCME
function M.GetListForObject (object, out)
    out = out or {}

    local n = 0

    for comp in adaptive.IterSet(Lists[object]) do
        out[n + 1], n = comp, n + 1
    end

    for i = #out, n + 1, -1 do
        out[i] = nil
    end

    return out
end

--- DOCME
function M.FoundInObject (object, ctype)
    for comp in adaptive.IterSet(Lists[object]) do
        if rawequal(comp, ctype) then
            return true
        end
    end

    return false
end

--- DOCME
function M.Implements (ctype, what)
    local info = Types[ctype]

    assert(info ~= nil, "Type not registered")

    for i = 1, #(info or "") do
        if rawequal(info[i], what) then
            return true
        end
    end

    return false
end

--- DOCME
function M.ImplementedByObject (object, what)
    for comp in adaptive.IterSet(Lists[object]) do
        local info = Types[comp]

        for i = 1, #(info or "") do
            if rawequal(info[i], what) then
                return true
            end
        end
    end

    return false
end

local Locks = meta.Weak("k")

--- DOCME
function M.LockInObject (object, ctype)
    local locks = Locks[object]

    if not adaptive.InSet(locks, ctype) then
        GatherRequiredTypes(ctype) -- n.b. set up before component added

        for rtype in pairs(RequiredTypes) do
            locks, RequiredTypes[rtype] = adaptive.AddToSet(locks, rtype)
        end
    end
end

local Methods = { add = true, allow_add = true, remove = true }

--- DOCME
function M.RegisterType (params)
    local ptype, name, interfaces, methods, requires = type(params)

    if ptype == "string" then
        name = params
    else
        assert(ptype == "table", "Expected string or table params")

        name, interfaces, methods, requires = params.name, params.interfaces, params.methods, params.requires
    end

    assert(name ~= nil, "Expected component name")
    assert(Types[name] == nil, "Name already in use")

    if interfaces or methods or requires then
        assert(methods == nil or type(methods) == "table", "Invalid methods")

        local ctype = {}

        for k, v in adaptive.IterSet(methods) do
            assert(Methods[k], "Unsupported method")

            ctype[k] = v
        end

        local reqs

        for i, name in adaptive.IterArray(requires) do
            reqs = reqs or {}
            reqs[i] = name
        end

        ctype.requirement_list = reqs -- put any requirements here for now, but resolve on first use

        for i, name in adaptive.IterArray(interfaces) do
            ctype[i] = name
        end

        array_funcs.RemoveDups(ctype)

        Types[name] = ctype
    else
        Types[name] = false
    end
end

local function AuxRemove (object, comp)
    local info = Types[comp]
    local on_remove = info and info.remove

    if on_remove then
        on_remove(object, comp)
    end
end

--- DOCME
function M.RemoveAllFromObject (object)
    local locks = Locks[object]

    if locks then
        local list = Lists[object]

        for comp in adaptive.IterSet(list) do
            if not adaptive.InSet(locks, comp) then
                AuxRemove(object, comp)

                list = adaptive.RemoveFromSet(list, comp)
            end
        end

        Lists[object] = list
    else
        for comp in adaptive.IterSet(Lists[object]) do
            AuxRemove(object, comp)
        end

        Lists[object] = nil
    end
end

local ToRemove = {}

--- DOCME
function M.RemoveFromObject (object, ctype)
    assert(Types[ctype] ~= nil, "Type not registered")

    if adaptive.InSet(Locks[object], ctype) then
        return false
    end

    local list = Lists[object]
    local exists = adaptive.InSet(list, ctype)

    if exists then
        for comp in adaptive.IterSet(object) do
            ToRemove[comp] = false
        end

        ToRemove[ctype] = true

        repeat
            local any = false

            for dtype, visited in pairs(ToRemove) do
                local info = not visited and Types[dtype]
                local reqs = info and info.requirements

                if reqs then
                    for k in pairs(reqs) do
                        if ToRemove[k] then -- do we depend on something that gets removed?
                            ToRemove[dtype], any = true, true -- must remove self as well

                            break
                        end
                    end
                end
            end
        until not any -- nothing else affected?

        for comp, affected in pairs(ToRemove) do
            if affected then
                AuxRemove(object, comp)

                list = adaptive.RemoveFromSet(list, comp)
            end

            ToRemove[comp] = nil
        end

        Lists[object] = list
    end

    return exists
end

-- Cache module members.
_CanAddToObject_ = M.CanAddToObject
_RemoveFromObject_ = M.RemoveFromObject

-- Export the module.
return M