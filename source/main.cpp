#include <nds.h>
#include <stdio.h>

extern "C" {
	
struct registers
{
	u32 gpr[16];
};

typedef void (*kprobe_init)(registers *regs);
typedef void (*kprobe_main)(void);

void kprobe_measure_init(registers *regs);
void kprobe_measure_main();
registers* kprobe(kprobe_init pre, kprobe_main main); 

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
		registers *regs = kprobe(kprobe_measure_init, kprobe_measure_main);
		clocks = regs->gpr[0];
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
