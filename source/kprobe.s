.text
.align

.equ REG_IME, 0x208
.equ REG_IE, 0x210
.equ REG_IF, 0x214
.equ REG_DISPSTAT, 0x4

.global kprobe_entry

load_dtcm:
	mrc	p15, 0, r1, c9, c1,0	
	bic r1, #0x0FF
	bic r1, #0xF00
	add r1, #0x4000	
	mov pc, lr

kprobe_return:
	mov r0, r9
	ldmfd sp!, {r1,r4,r9,lr}
	bx lr

kprobe_hblank:
	stmfd sp!, {r0,r1,r4,lr}
	mov r4, #0x4000000
	mov r0, #0
	
	// disable interrupts
	str r0, [r4, #REG_IME]
	
	// reload old DISPSTAT
	ldr r1, old_DISPSTAT
	strh r1, [r4, #REG_DISPSTAT]
	
	// reload old IE
	ldr r1, old_IE
	str r1, [r4, #REG_IE]
	
	// reset the trapped PC
	//adr r1, kprobe_return_addr
	//ldrt pc, [r1]
	
	// restore original IRQ handler
	ldr r0, old_IRQ
	bl load_dtcm
	str r0, [r1, #-4]
	
	// restore original IE
	ldr r1, old_IE
	str r1, [r4, #REG_IE]
	
	// enable interrupts
	mov r1, #1
	str r1, [r4, #REG_IME]
	
	adr r1, kprobe_return + 4
	str r1, [sp, #9*4]
	
	ldmfd sp!, {r0,r1,r4,lr}	
	bx lr
	
	
.align
old_IE: .word 0x1000beef
old_IRQ: .word 0x2000beef
old_DISPSTAT: .word 0x3000beef
.pool

kprobe_entry:
	stmfd sp!, {r1,r4,r9,lr}
	mov r4, #0x4000000
	mov r0, #0
	
	// disable interrupts
	str r0, [r4, #REG_IME]
	
	// backup original DISPSTAT
	ldrh r1, [r4, #REG_DISPSTAT]
	
	str r1, old_DISPSTAT
	orr r1, #0x10
	strh r1, [r4, #REG_DISPSTAT]
	
	// backup original IE
	ldr r1, [r4, #REG_IE]
	str r1, old_IE
	
	// mask IE
	str r0, [r4, #REG_IE]
	
	// backup old and load new IRQ handler
	bl load_dtcm
	ldr r0,[r1, #-4]
	str r0, old_IRQ
	adr r0, kprobe_hblank
	str r0,[r1, #-4]

	// hblank spinlocks
hspin0: // spin while hblank is 1
	ldr  r1, [r4, #0x4]
	ands r1, r1, #2
	bne hspin0
hspin1: // spin while hblank is 0
	ldr  r1, [r4, #0x4]
	ands r1, r1, #2
	beq hspin1
	
	// reset counter and enable hblank interrupt
	mov r9, #0
	mov r1, #2
	str r1, [r4, #REG_IE]
	str r1, [r4, #REG_IF]
	mov r1, #1
	str r1, [r4, #REG_IME]
	

// right here hblank has been toggled to 1 and we might have consumed some cycles
// thus time till next blank is at most 272 cycles (hblank time)
.rept 4096
	add r9, #1
.endr
cycling:
	add r9, #1
	b cycling // shouldnt reach this if so increase unrolling above




