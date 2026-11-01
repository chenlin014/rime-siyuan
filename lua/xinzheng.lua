local key_conv = require("common/key_conv")
local casing = require("common/casing")

local M = {}
local first_char = nil
local first_word = nil

M.proc = {}

function M.proc.init(env)
	local config = env.engine.schema.config
	env.alphabet = config:get_string("speller/alphabet") or ""
	env.initials = config:get_string("speller/initials") or env.alphabet
	env.max_code_length = config:get_int("speller/max_code_length") or 100
	env.special_symbol = config:get_string("xinzheng/special_symbol") or ""

	local special_keys = config:get_list("xinzheng/special_keys")
	if special_keys then
		env.is_special_key = {}
		for i=1, special_keys.size do
			local key = special_keys:get_value_at(i-1)
			if key then
				env.is_special_key[key.value] = true
			end
		end
	end
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

	if back_seg:has_tag("abc") and seg_length >= env.max_code_length then
		if key_sym and env.alphabet:find(key_sym,1,true) then
			if context:get_option("up_first_char") and first_char then
				env.engine:commit_text(first_char)
				context:clear()
			elseif context:get_option("up_first_word") and first_word then
				env.engine:commit_text(first_word)
				context:clear()
			elseif commit_text and key_sym ~= env.special_symbol then
				env.engine:commit_text(commit_text)
				context:clear()
			end
		elseif key_repr == "space" then
			if context:get_option("up_first_char") and first_word then
				env.engine:commit_text(first_word)
				context:clear()
				return 1
			elseif context:get_option("up_first_word") and first_char then
				env.engine:commit_text(first_char)
				context:clear()
				return 1
			end
		end
	elseif env.is_special_key[key_repr] and input:match("^[a-z]$") then
		env.engine:commit_text(input)
		context:clear()
		return 1
	end

	return 2
end

M.filter = {}

function M.filter.init(env)
	local context = env.engine.context
end

function M.filter.func(input, env)
	local context = env.engine.context
	first_char = nil
	first_word = nil

	for cand in input:iter() do
		if utf8.len(cand.text) == 1 then
			first_char = first_char or cand.text
		elseif utf8.len(cand.text) > 1 then
			first_word = first_word or cand.text
		end
		yield(cand)
	end
end

return M
