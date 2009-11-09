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
void kprobe_exec_main();
extern u32 kprobe_probe;
registers* kprobe(kprobe_init pre, kprobe_main main); 

}

u32 clocks, cmin, cmax, iter;
u32 wait_cycles;
u32 exceptions;

void kprobe_exec_init(registers *regs)
{
	regs->gpr[0] = wait_cycles;
}

registers* kprobe_hl()
{
	int retries = 100;
	for (wait_cycles = 0xFF; wait_cycles > 10; wait_cycles--)
	{
		for (int i = 0; i < 3; i++)
		{
			registers *regs = kprobe(kprobe_exec_init, kprobe_exec_main);
			u32 pc = regs->gpr[15];
			u32 gate = regs->gpr[1];
			if ((pc == gate) || (pc == gate + 4))
				continue;
			if (regs->gpr[0] != 0)
			{
				exceptions++;
				wait_cycles += 4;
				retries--;
				if (retries == 0)
					return 0;
				break;
			}
			return regs;
		}
	}
	return 0;
}

int main(void)
{
	cmin = 0xFFFFFFFF;
	cmax = 0;
	iter = 0;
	exceptions = 0;
	
	PrintConsole topScreen;
	PrintConsole bottomScreen;
	
	videoSetMode(MODE_0_2D);
	videoSetModeSub(MODE_0_2D);

	vramSetBankA(VRAM_A_MAIN_BG);
	vramSetBankC(VRAM_C_SUB_BG);

	consoleInit(&topScreen, 3,BgType_Text4bpp, BgSize_T_256x256, 31, 0, true, true);
	consoleInit(&bottomScreen, 3,BgType_Text4bpp, BgSize_T_256x256, 31, 0, false, true);

	consoleSelect(&topScreen);
	
	kprobe_probe =  0xE3A01008; // mov r1, #8

	for (int iter = 0;;iter++)
	{	
		registers *regs;
		regs = kprobe_hl();
		swiWaitForVBlank();
		iprintf("\x1b[2;0H");
		if (regs)
		{
			for (int i = 0; i < 16; i++)
				iprintf("r%02i = %08X\n", i, regs->gpr[i]);
		} else iprintf("FAILED!\n");
		iprintf("\nIteration: %i\nexceptions: %i", iter, exceptions);
	}
	return 0;
}
