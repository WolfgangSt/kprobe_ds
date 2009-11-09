.text
.align
.cpu arm946e-s

.equ REG_IME, 0x208
.equ REG_IE, 0x210
.equ REG_IF, 0x214
.equ REG_DISPSTAT, 0x4
.equ REG_TIMER0, 0x100

.global kprobe_measure_init
.global kprobe_measure_main
.global kprobe_exec_init
.global kprobe_exec_main
.global kprobe
.global kprobe_probe

bak_r0: .word 0
bak_r1: .word 0
bak_r2: .word 0
bak_r3: .word 0
bak_r4: .word 0
bak_r5: .word 0
bak_r6: .word 0
bak_r7: .word 0
bak_r8: .word 0
bak_r9: .word 0
bak_r10: .word 0
bak_r11: .word 0
bak_r12: .word 0
bak_r13: .word 0
bak_r14: .word 0

ctx_r0: .word 0
ctx_r1: .word 0
ctx_r2: .word 0
ctx_r3: .word 0
ctx_r4: .word 0
ctx_r5: .word 0
ctx_r6: .word 0
ctx_r7: .word 0
ctx_r8: .word 0
ctx_r9: .word 0
ctx_r10: .word 0
ctx_r11: .word 0
ctx_r12: .word 0
ctx_r13: .word 0
ctx_r14: .word 0
ctx_r15: .word 0 // read only!!

timer0: .word 0

load_dtcm:
	mrc	p15, 0, r1, c9, c1,0	
	bic r1, #0x0FF
	bic r1, #0xF00
	add r1, #0x4000	
	mov pc, lr


.align
old_IE: .word 0x1000beef
old_IRQ: .word 0x2000beef
old_IME: .word 0x4000beef
.pool

// r0 = pre handler 
// r1 = execution handler (measure/exec)

kprobe:
	// backup calling context
	str r0, bak_r0
	adr r0, bak_r0
	stmib r0, {r1-r14}
	
	
	adr r0, ctx_r0               // load context address
	ldr r1, bak_r0               // load pre handler
	blx r1                       // invoke pre handler to load context
	
	mov r4, #0x4000000
	mov r0, #0
	str r0, [r4, #REG_IME]       // disable interrupts
	ldr r1, [r4, #REG_IE]        // load original IE
	str r1, old_IE               // back up IE
	ldr r1, [r4, #REG_TIMER0]    // load timer0
	str r1, timer0               // backup timer0
	str r0, [r4, #REG_TIMER0]    // reset timer0
	bl load_dtcm                 // load dtcm to r1
	ldr r0,[r1, #-4]             // load old IRQ handler
	str r0, old_IRQ              // back up old IRQ handler
	adr r0, kprobe_irq           // load new IRQ handler
	str r0,[r1, #-4]             // write new IRQ handler
	mov r1, #8
	str r1, [r4, #REG_IE]        // set IE to timer0 only
	str r1, [r4, #REG_IF]        // signal timer0 in IF
	mov r1, #1
	str r1, [r4, #REG_IME]       // enable IME
	ldr r1, =0x00C0FF00          // enable timer0 IRQ and start
	str r1, [r4, #REG_TIMER0]    // write enable to timer

	// interrupt could occur any time from here on
	adr r0, ctx_r0               // load ctx to registers
	ldmib r0, {r1-r14}           //
	ldr r0, ctx_r0               //
	ldr pc, bak_r1               // jump to probecode


// entering here after probe has been interrupted
kprobe_irq:
	ldmia sp, {r0-r3}            // restore regs except sp from BIOS handler
	str r0, ctx_r0               // backup context for inspection callback
	adr r0, ctx_r0
	stmib r0, {r1-r14}
	
	// restore original environment
	mov r4, #0x4000000
	mov r0, #0
	str r0, [r4, #REG_IME]       // disable interrupts
	ldr r1, old_IE               // reload old IE
	str r1, [r4, #REG_IE]        // reset old IE
	ldr r1, timer0               // reload timer0
	str r1, [r4, #REG_TIMER0]    // reset timer0
	mov r0, lr
	bl load_dtcm                 // load dtcm to r1
	mov lr, r0
	ldr r0, old_IRQ              // load old IRQ handler
	str r0, [r1, #-4]            // restore old IRQ handler
	ldr r1, old_IE               // load old IE
	str r1, [r4, #REG_IE]        // restore old IE	
	mov r1, #1
	str r1, [r4, #REG_IME]       // enable interrupts
	
	adr r1, kprobe_return + 4    // rebranch interrupt return
	ldr r0, [sp, #5*4]
	str r0, ctx_r15
	str r1, [sp, #5*4]
	bx lr

// entering here after IRQ cleanup
kprobe_return:
	adr r0, bak_r0               // load bak to registers
	ldmib r0, {r1-r14}           //
	adr r0, ctx_r0               //
	bx lr                        // return to callee

kprobe_measure_init:
	mov r1, #0
	str r1, [r0]
	mov pc, lr

kprobe_measure_main:
	adds r0, #1
	bne kprobe_measure_main
1:  b 1b


kprobe_exec_main:
	adr r1, l2
	mov r9, #0
l1:	subs r0, #1
l2:	bne l1
kprobe_probe:
	nop
	// this security catch only triggers for non branching instructions
	mov r0, #-1
l3:  b l3


