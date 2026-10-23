local key_conv = require("common/key_conv")
local casing = require("common/casing")

local M = {}

M.proc = {}

function M.proc.init(env)
	local config = env.engine.schema.config
	env.alphabet = config:get_string("speller/alphabet") or ""
	env.initials = config:get_string("speller/initials") or env.alphabet
	env.max_code_length = config:get_int("speller/max_code_length") or 100
	env.special_symbol = config:get_string("xinzheng/special_symbol") or ""
end

function M.proc.fini(env)
end

function M.proc.func(key, env)
	local key_repr = key:repr()
	local key_sym = key_conv.repr2char[key_repr]

	local context = env.engine.context
	local commit_text = context:get_commit_text()
	local input = context.input or ""
	local back_seg = context.composition:back()
	local seg_length = back_seg.length

	if back_seg:has_tag("abc") and key_sym and env.alphabet:find(key_sym,1,true) then
		if input:sub(-1,-1) == env.special_symbol then
			if #input > 1 then
				context:clear()
				context:push_input(input:sub(1,-2)..key_sym)
				return 1
			end
		elseif seg_length >= env.max_code_length then
			if not env.initials:find(key_sym,1,true) then
				if commit_text and key_sym ~= env.special_symbol then
					env.engine:commit_text(commit_text)
					context:clear()
				end
			end
		end
	end

	return 2
end

return M
