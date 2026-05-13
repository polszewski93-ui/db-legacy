local Rarities = {
	"NORMAL",
	"RARE",
	"EPIC",
	"LEGENDARY",
	"MYTHICAL"
}

local function getBorder(rarity)
	if rarity == Rarities[1] then
		return "/images/ui/verde"
	elseif rarity == Rarities[2] then
		return "/images/ui/azul"
	elseif rarity == Rarities[3] then
		return "/images/ui/roxo"
	elseif rarity == Rarities[4] then
		return "/images/ui/Slots de Itens"
	elseif rarity == Rarities[5] then
		return "/images/ui/MYTHICAL"
	end

	return "/images/ui/item"
end

function updateItemBorder(itemWidget)
	local item = itemWidget:getItem()

	if item then
		local description = item:getTooltip()
		local rarity = description:match("%[(.-)%]")

		if rarity and rarity ~= "" then
			itemWidget:setImageSource(getBorder(rarity))
		else
			itemWidget:setImageSource("/images/ui/item")
		end
	end
end

function updateItemShader(itemWidget)
	local item = itemWidget:getItem()

	if item then
		local description = item:getTooltip()
		local rarity = description:match("%[(.-)%]")

		if rarity and rarity ~= "" then
			item:setShader(rarity)
		end
	end
end
