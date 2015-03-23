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
local concat = table.concat

-- Cached module references --
local _EnsureTable_

-- Exports --
local M = {}

--- DOCME
function M.CachedReader ()
	local CachedReader = {}

	--- DOCME
	function CachedReader:Begin ()
		self.m_count = 0
	end

	--- DOCME
	function CachedReader:End (db)
		db:exec(concat(self, "", 1, self.m_count))

		for i = #self, self.m_count + 1, -1 do -- try to remove some entries
			self[i] = nil
		end

		self.m_count = 0
	end

	--- DOCME
	function CachedReader:exec (str)
		local count = self.m_count + 1

		self[count] = str

		self.m_count = count
	end

	return CachedReader
end

--- DOCME
function M.DropTable (db, name)
	db:exec([[
		DROP TABLE IF EXISTS ]] .. name .. [[;
	]])
end

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
-- @string[opt="m_KEY"] key_column Name of key column.
-- @return Value, if found, or **nil** otherwise.
function M.GetOneValueInTable (db, name, key, key_column)
	return Urows1(db, name, (key_column or [[m_KEY]]) .. [[ = ']] .. key .. [[']])
end

-- --
local KeyDataColumns = [[m_KEY VARCHAR UNIQUE, m_DATA BLOB]]

--
local function GetColumns (what)
	if what == "key_data" then
		return KeyDataColumns
	end

	return what
end

--- DOCME
function M.EnsureTable (db, name, columns)
	db:exec([[
		CREATE TABLE IF NOT EXISTS ]] .. name .. [[ (]] .. GetColumns(columns) .. [[);
	]])
end

--
local function AuxInsertOrReplace (name, key, data)
	return [[
		INSERT OR REPLACE INTO ]] .. name .. [[ VALUES(']] .. key .. [[', ']] .. data .. [[');
	]]
end

--- DOCME
function M.InsertOrReplace_KeyData (db, name, key, data, columns)
	_EnsureTable_(db, name, columns or "key_data")

	db:exec(AuxInsertOrReplace(name, key, data))
end

--- DOCME
function M.NewTable (db, name, columns)
	db:exec([[
		DROP TABLE IF EXISTS ]] .. name .. [[;
		CREATE TABLE ]] .. name .. [[ (]] .. GetColumns(columns) .. [[);
	]])
end

--- Predicate.
-- @tparam Database db
-- @string name Table name.
-- @treturn boolean Table exists?
function M.TableExists (db, name)
	return Urows1(db, "sqlite_master", [[type = 'table' AND name = ']] .. name .. [[']]) ~= nil
end

-- TODO: Incorporate stuff from corona_utils.file, corona_utils.persistence

-- Cache module members.
_EnsureTable_ = M.EnsureTable

-- Export the module.
return M