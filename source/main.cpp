#include <nds.h>
#include <stdio.h>

extern "C" {
u32 kprobe_entry(); 
}

u32 clocks, cmin, cmax, iter;

void output()
{
	iprintf("\x1b[2;0Hlast: %i\ncmin: %i\ncmax : %i\niteration: %i", clocks, cmin, cmax, iter);
}

int main(void)
{
	cmin = 0xFFFFFFFF;
	cmax = 0;
	iter = 0;
	
	PrintConsole topScreen;
	PrintConsole bottomScreen;
	
	videoSetMode(MODE_0_2D);
	videoSetModeSub(MODE_0_2D);

	vramSetBankA(VRAM_A_MAIN_BG);
	vramSetBankC(VRAM_C_SUB_BG);

	consoleInit(&topScreen, 3,BgType_Text4bpp, BgSize_T_256x256, 31, 0, true, true);
	consoleInit(&bottomScreen, 3,BgType_Text4bpp, BgSize_T_256x256, 31, 0, false, true);

	consoleSelect(&topScreen);

	for (;;)
	{
		clocks = kprobe_entry();
		iter++;
		if (clocks > cmax)
			cmax = clocks;
		if (clocks < cmin)
			cmin = clocks;
		swiWaitForVBlank();
		output();
	}
	return 0;
}
