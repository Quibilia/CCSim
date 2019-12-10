_DEBUG = false
_RUNNING = true

CCSMStatus, CCSModule = pcall(require, "CCSCommon")
if not CCSMStatus or not CCSModule then error(tostring(CCSModule)) os.exit(1) end
CCSFStatus, CCSCommon = pcall(CCSModule)
if not CCSFStatus or not CCSCommon then error(tostring(CCSCommon)) os.exit(1) end

function main()
	if _DEBUG then
		CCSCommon:rseed()
		testGlyphs()
		testNames()
	end
	while _RUNNING do
		UI:clear()
		UI:printf("\n\n\tCCSIM : Compact Country Simulator\n\n")
		if _DEBUG then UI:printf("\t-- DEBUG MODE ENABLED --\n\n") end
		UI:printf("MAIN MENU\n\n1\t-\tBegin a new simulation.")
		UI:printf("2\t-\tReview the output of a previous simulation.")
		if _DEBUG then UI:printf("3\t-\tExecute a line of lua code.\n") end
		UI:printf("Q\t-\tExit the program.")
		UI:printp("\n > ")

		local datin = UI:readl()
		if datin == "1" then simNew() _RUNNING = false
		elseif datin == "2" then simReview()
		elseif datin == "3" and _DEBUG then debugLine()
		elseif datin:lower() == "q" then _RUNNING = false end
	end

	CCSCommon = nil
	if cursesstatus then curses.endwin() end
end

main()
os.exit(0)
