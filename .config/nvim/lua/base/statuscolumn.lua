local M = {}

---@param group string
---@param text string
local function paint(group, text)
	return "%#" .. group .. "#" .. text
end

---@param lnum integer
---@return string? git, string? other
local function signs(lnum)
	local slots = {}

	local marks = vim.api.nvim_buf_get_extmarks(0, -1, { lnum - 1, 0 }, { lnum - 1, -1 }, {
		details = true,
		type = "sign",
	})

	for _, mark in ipairs(marks) do
		local sign = mark[4]

		if sign.sign_text then
			local group = sign.sign_hl_group or "SignColumn"
			local slot = group:find("^GitSigns") and "git" or "other"
			local priority = sign.priority or 0

			if not slots[slot] or priority > slots[slot].priority then
				slots[slot] = { drawn = paint(group, sign.sign_text), priority = priority }
			end
		end
	end

	return slots.git and slots.git.drawn, slots.other and slots.other.drawn
end

function M.render()
	local base = (vim.v.relnum == 0 and vim.wo.cursorline) and "CursorLineSign" or "SignColumn"
	local blank = paint(base, "  ")

	if vim.v.virtnum ~= 0 then
		return blank .. blank .. "%l "
	end

	local git, other = signs(vim.v.lnum)

	return (git or blank) .. (other or blank) .. "%l "
end

return M
