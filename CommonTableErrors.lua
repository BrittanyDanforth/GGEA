-- COMMON TABLE SYNTAX ERRORS AND FIXES

-- ❌ WRONG - Using ] to close a table
local wrongTable = {
    item1 = "value1",
    item2 = "value2",
] -- ERROR: Expected '}' got ']'

-- ✅ CORRECT - Using } to close a table
local correctTable = {
    item1 = "value1",
    item2 = "value2",
} -- Correct!

-- ❌ WRONG - Mixing brackets in nested tables
local wrongNested = {
    products = {
        {
            id = 123,
            name = "Product",
        ], -- ERROR: Wrong bracket type!
    },
}

-- ✅ CORRECT - Consistent bracket types
local correctNested = {
    products = {
        {
            id = 123,
            name = "Product",
        }, -- Correct curly brace
    },
}

-- ❌ WRONG - Missing comma
local wrongComma = {
    item1 = "value1"  -- Missing comma here!
    item2 = "value2",
}

-- ✅ CORRECT - All items have commas
local correctComma = {
    item1 = "value1", -- Comma added
    item2 = "value2",
}

-- TO FIX YOUR ERROR:
-- 1. Go to line 375 in your CreateMoneyShop script
-- 2. Look for any ']' that should be '}'
-- 3. Check the lines above and below for matching brackets
-- 4. Make sure all table entries have commas

-- Quick check pattern:
-- { opens a table, } closes a table
-- [ opens an array index, ] closes an array index
-- Never use ] to close a table that was opened with {