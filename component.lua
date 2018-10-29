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
local tostring = tostring
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

--- Add a component to an object.
--
-- TODO: on_add(object, new_type)
-- @param object
-- @param ctype Component type.
-- @treturn boolean The addition succeeded.
-- @see CanAddToObject
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

--- Check whether the object can accept the component.
--
-- TODO: allow_add(new_type, object, existing_type)...
-- @param object
-- @param ctype Component type.
-- @return[1] **true**, meaning the addition would succeed.
-- @return[2] **false**, indicating failure.
-- @treturn string Failure reason.
-- @see AddToObject
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

--- Get the list of interfaces implemented by an object's components.
-- @param object
-- @tparam[opt] table out If provided, this will be populated and used as the return value.
--
-- The final size will be trimmed down to the number of interfaces, if necessary.
-- @treturn {Interface,...} Array of interfaces, with duplicates removed.
-- @see Implements, RegisterType
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

--- Get the list of component types belonging to an object.
-- @param object
-- @tparam[opt] table out If provided, this will be populated and used as the return value.
--
-- The final size will be trimmed down to the number of components, if necessary.
-- @treturn {ComponentType,...} Array of types.
-- @see AddToObject, RegisterType
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

---
-- @param object
-- @param ctype Component type.
-- @treturn boolean Does _ctype_ belong to _object_?
function M.FoundInObject (object, ctype)
    for comp in adaptive.IterSet(Lists[object]) do
        if rawequal(comp, ctype) then
            return true
        end
    end

    return false
end

local function AuxImplements (info, what)
    for i = 1, #(info or "") do
        if rawequal(info[i], what) then
            return true
        end
    end
end

---
-- @param ctype Component type.
-- @param what Interface.
-- @treturn boolean Does _ctype_ implement _what_?
function M.Implements (ctype, what)
    local info = Types[ctype]

    assert(info ~= nil, "Type not registered")

    return AuxImplements(info, what) or false -- coerce nil to false
end

---
-- @param object
-- @param what Interface.
-- @treturn boolean Does _object_ have a component that implements _what_?
function M.ImplementedByObject (object, what)
    for comp in adaptive.IterSet(Lists[object]) do
        if AuxImplements(Types[comp], what) then
            return true
        end
    end

    return false
end

local Locks = meta.Weak("k")

local Inf = 1 / 0

local function NotLocked (locks, ctype)
	local count = locks[ctype] or 0

    return 1 / count ~= 0
end

--- Permanently lock a component into this object.
--
-- This will override any reference counting on the component.
-- @param object
-- @param ctype Component type.
-- @see RefInObject, RemoveAllFromObject, RemoveFromObject, UnrefInObject
function M.LockInObject (object, ctype)
    local locks = Locks[object] or {}

    if NotLocked(locks, ctype) then
		GatherRequiredTypes(ctype) -- n.b. set up before component added

		for rtype in pairs(RequiredTypes) do
			locks[rtype], RequiredTypes[rtype] = Inf
		end
    end

	Locks[object] = locks
end

--- Increment the reference count (starting at 0) on a component. While this count is greater
-- than 0, the component is locked.
--
-- This is a no-op after @{LockInObject} has been called.
-- @see RemoveAllFromObject, RemoveFromObject, UnrefInObject
function M.RefInObject (object, ctype)
    local locks = Locks[object] or {}
	
	if NotLocked(locks, ctype) then
        GatherRequiredTypes(ctype) -- n.b. set up before component added

        for rtype in pairs(RequiredTypes) do
            locks[rtype], RequiredTypes[rtype] = (locks[rtype] or 0) + 1 -- if infinity, left as-is
        end
    end

	Locks[object] = locks
end

local Methods = { add = true, allow_add = true, remove = true }

--- Register a new component type.
-- @tparam ?|table|string As a string, the name of the component.
--
-- Otherwise, a table with one or more of the following:
-- * **name**: The aforesaid name. (Required.)
-- * **interfaces**: Array of interfaces implemented by this component. (Optional.)
-- * **methods**: Table that may contain **add**, **allow\_add**, and **remove** functions. (Optional.)
-- * **requires**: Array of component types that an object must also contain in order to have
-- this component. These need not have been registered yet. (Optional.)
-- @see AddToObject, CanAddToObject, RemoveFromObject
function M.RegisterType (params)
    local ptype, name, interfaces, methods, requires = type(params)

    if ptype == "string" then
        name = params
    else
        assert(ptype == "table", "Expected string or table params")

        name, interfaces, methods, requires = params.name, params.interfaces, params.methods, params.requires
    end

    assert(name ~= nil, "Expected component name")

    if interfaces or methods or requires then
		assert(Types[name] == nil, "Name already in use")
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
		assert(not Types[name], "Complex type already registered") -- previous false okay

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

--- Remove any components from an object that are not locked or referenced, cf. @{RemoveFromObject}.
-- @param object
-- @see LockInObject, RefInObject
function M.RemoveAllFromObject (object)
    local locks = Locks[object]

    if locks then
        local list = Lists[object]

        for comp in adaptive.IterSet(list) do
            if not locks[comp] then
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

--- Remove a component from an object, if not locked or referenced.
--
-- TODO: remove(object, removed_type)
-- @param object
-- @param ctype Component type.
-- @treturn boolean The remove succeeded, i.e. the component existed and was removable?
-- @see LockInObject, RefInObject, RemoveAllFromObject
function M.RemoveFromObject (object, ctype)
    assert(Types[ctype] ~= nil, "Type not registered")

	local locks = Locks[object]

    if locks and locks[ctype] then
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

--- Decrement the reference count for a component, unlocking it if the count falls to 0.
--
-- This is a no-op after @{LockInObject} has been called.
--
-- In a well-behaved implementation, this must follow a previous `RefInObject(object, ctype)` call.
-- @see LockInObject, RemoveAllFromObject, RemoveFromObject
function M.UnrefInObject (object, ctype)
    local locks = Locks[object]

	if locks and NotLocked(locks, ctype) then
        GatherRequiredTypes(ctype) -- n.b. set up before component added

		for rtype in pairs(RequiredTypes) do -- detect improper usage, e.g. unref'ing required type directly
			if not locks[rtype] then
				assert(false, "Bad ref count for component: " .. tostring(rtype))
			end
		end

        for rtype in pairs(RequiredTypes) do
			local new_count = locks[rtype] - 1 -- if infinity, left as-is

            locks[rtype], RequiredTypes[rtype] = new_count > 0 and new_count
        end
    end

	Locks[object] = locks
end

-- Cache module members.
_CanAddToObject_ = M.CanAddToObject
_RemoveFromObject_ = M.RemoveFromObject

-- Export the module.
return M