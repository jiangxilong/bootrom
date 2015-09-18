/**
 * Copyright (c) 2015 Google Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

.syntax		unified
.file		"standby.S"

#include "chipdef.h"

#define EBUSY       16

.text
.thumb
.thumb_func
.align	2

#define TSB_SCM_CLOCKENABLE1            0x40000304
#define    CE_UNIPRO_SYSCLK               (1 << 2)

/**
 * each CPU cycle is about 10ns and a loop needs at least two cycles
 */
#define DELAY_NS_LOOP_COUNT(n) (n / 20)
.macro delay_ns ns
    ldr r3, =DELAY_NS_LOOP_COUNT(\ns)
1:
    subs r3, r3, #1
    bne 1b
.endm

.globl	chip_enter_standby
.type	chip_enter_standby, %function
chip_enter_standby:
    ldr r1, =TSB_SCM_CLOCKENABLE1
    ldr r0, [r1]
    ldr r1, =CE_UNIPRO_SYSCLK
    tst r0, r1
    beq ok_to_standby
    /* Unipro clock is still on so return EBUSY */
    ldr r0, =-EBUSY
    bx lr

ok_to_standby:
    ldr r2, =RETSRAMCENCONT
    ldr r1, =1
    str r1, [r2]

    /* delay 5 CPU cycles or more */
    nop
    nop
    nop
    nop
    nop

    ldr r0, =0
    ldr r2, =RETSRAMCLKCONT
    str r0, [r2]

    /* delay 5 CPU cycles or more */
    nop
    nop
    nop
    nop
    nop

    ldr r2, =RETSRAMRET
    str r1, [r2]

    ldr r2, =HB8CLK_EN
    str r0, [r2]

    /* delay 1.5us or more */
    delay_ns 1500

    ldr r2, =RETFFSAVE
    str r1, [r2]

    /* delay 0.1us or more */
    delay_ns 100

    str r0, [r2]

    ldr r2, =ISO_FOR_IO_EN
    str r1, [r2]
    ldr r2, =ISO_EN
    str r1, [r2]

    /* loop until the power is off */
    b .

.globl	resume_from_standby
resume_from_standby:
    /*
     * "Resume" path
     * TA-06 Write/Read registers to resume standby
     */
    ldr r2, =RETSRAMRET
    ldr r0, =0
    str r0, [r2]

    /* delay 0.1us or more */
    delay_ns 100

    ldr r2, =RETSRAMCLKCONT
    ldr r1, =1
    str r1, [r2]

    /* delay 5 CPU cycles or more */
    nop
    nop
    nop
    nop
    nop

    ldr r2, =RETSRAMCENCONT
    str r0, [r2]

    ldr r2, =SOFTRESETRELEASE1
    ldr r4, =SRSTRELEASE_UNIPRO_SYSRESET_N
    str r4, [r2]

    /* delay 0.1us or more */
    delay_ns 100

    ldr r2, =RETFFSTR
    str r1, [r2]

    /* delay 5us or more */
    delay_ns 5000

    ldr r2, =RETFFSTR
    str r0, [r2]

    /* delay 5us or more */
    delay_ns 5000

    ldr r2, =HB8CLK_EN
    str r1, [r2]

    /* delay 1.5us or more */
    delay_ns 1500

    ldr r2, =ISO_FOR_IO_EN
    str r0, [r2]

    ldr r2, =BOOTRET_O
    str r0, [r2]

    /*
     * Check for the resume address and its complement before jumping to it
     */
    ldr r2, =_resume_data
    ldm r2, {r0, r1, r4}
    mvn r4, r4
    cmp r1, r4   /* check the complement of the resume address */
    bne cold_boot

    /*
     * Before resuming the higher-level code, ensure that IMS and CMS
     * and JTAG are disabled.
     */
    ldr r5, = DISABLE_JTAG_IMS_CMS_ACCESS
    ldr r3, =_DISABLE_IMS_ACCESS
    str r5, [r3]
    ldr r3, = _DISABLE_CMS_ACCESS
    str r5, [r3]
    ldr r3, = _JTAG_DISABLE
    tst r0, #1
    beq leave_jtag_untouched
    str r5, [r3]

leave_jtag_untouched:
    ldr r3, =0
    str r3, [r2], #4 /* clear the resume address */
    str r3, [r2]
    orr r1, #1   /* make sure thumb bit is set */
    bx r1   /* jump to resume address */
