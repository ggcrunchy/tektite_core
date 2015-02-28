--- This module provides some functionality for Sqlite3 databases.

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
local type = type

-- Exports --
local M = {}

-- Wrapper around common urows()-based pattern with "LIMIT 1"
local function Urows1 (db, name, where)
	local ret

	for _, v in db:urows([[SELECT * FROM ]] .. name .. [[ WHERE ]] .. where .. [[ LIMIT 1]]) do
		ret = v
	end

	return ret
end

--- Gets (at most) one value from a table matching a given key.
-- @tparam Database db
-- @string name Table name.
-- @string key Key associated with value.
-- @string[opt="m_KEY"] column_name Name of key column.
-- @return Value, if found, or **nil** otherwise.
function M.GetOneValueInTable (db, name, key, column_name)
	return Urows1(db, name, (column_name or [[m_KEY]]) .. [[ = ']] .. key .. [[']])
end

-- --
local KeyDataSchema = [[(m_KEY UNIQUE, m_DATA)]]

--
local function EnsureTable (name, schema, def)
	if schema then
		schema = type(schema) == "string" and schema or def

		return [[
			CREATE TABLE IF NOT EXISTS ]] .. name .. schema .. [[;
		]]
	else
		return ""
	end
end

--
local function AuxInsertOrReplace (name, key, data)
	return [[
		INSERT OR REPLACE INTO ]] .. name .. [[ VALUES(']] .. key .. [[', ']] .. data .. [[;');
	]]
end

--- DOCME
function M.InsertOrReplaceKeyData (db, name, key, data, schema)
	db:exec(EnsureTable(name, schema, KeyDataSchema) .. AuxInsertOrReplace(name, key, data))
end

--- Predicate.
-- @tparam Database db
-- @string name Table name.
-- @treturn boolean Table exists?
function M.TableExists (db, name)
	return Urows1(db, "sqlite_master", [[type = 'table' AND name = ']] .. name .. [[']]) or false
end

-- TODO: Incorporate stuff from corona_utils.file, corona_utils.persistence

-- Export the module.
return M