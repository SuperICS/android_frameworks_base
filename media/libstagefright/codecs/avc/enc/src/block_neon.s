@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@   block.cpp for neon optimization of h264 encoder
@   author: zefeng.tong@amlogic.com
@   date:   2011-07-28
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    
    
@    .section .text
@    .global  trans
@trans:
@    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
@    lsr        r4,   r1,  #16                        @r4:int curpitch = (uint)pitch >> 16;
@    lsl        r5,   r1,  #16
@    lsr        r5,   r5,  #16                        @r5:int predpitch = (pitch & 0xFFFF);
@    mov        r6,   r3                              @r6:int16 *ptr = dataBlock;
@    mov        r8,   #32
    
@    mov        r7,   #4
@1:
@    VLD1.8     {d0}, [r0], r4
@    VLD1.8     {d1}, [r2], r5
    
@    VSUBL.U8   Q0,   d0,   d1                        @d0: r3 r2 r1 r0
@    VREV64.16  d1,   d0                              @d1: r0 r1 r2 r3
    
@    VADD.S16   d2,   d0,   d1                        @d2: r0 r1 r1 r0
@    VSUB.S16   d3,   d0,   d1                        @d3: xx xx r2 r3
    
@    VSHL.S16   d0,   d3,   #1                        @d0: xxxx(r2<<1)(r3<<1)
@    VREV32.16  d0,   d0                              @d0: xxxx(r3<<1)(r2<<1)
@    VSUB.S16   d1,   d3,   d0                        @d1: xxxxxxxx(r3-(r2<<1))
@    VADD.S16   d0,   d3,   d0                        @d0: xxxx(r2+(r3<<1))xx
@    VSHR.U64   d0,   d0,   #16
    
@    VTRN.16    d2,   d3                              @d2: xx xx xx r0;d3:xx xx xx r1
@    VADD.S16   d4,   d2,   d3                        @d4: xx xx xx r0+r1
@    VSUB.S16   d2,   d2,   d3                        @d2: xx xx xx r0-r1
    
@    VZIP.16    d4,   d0
@    VZIP.16    d2,   d1
@    VZIP.32    d4,   d2
@    VST1.16    {d4},  [r6], r8
    
@    subs       r7,   r7,  #1
@    bgt        1b
    
@    mov        r4,   r3
@    add        r5,   r3,  #32
@    add        r6,   r3,  #64
@    add        r7,   r3,  #96
@    VLD1.16    {d0},  [r4]                           @d0: prt[0]prt[0]prt[0]prt[0]
@    VLD1.16    {d1},  [r5]                           @d1: prt[16]prt[16]prt[16]prt[16]
@    VLD1.16    {d2},  [r6]                           @d2: prt[32]prt[32]prt[32]prt[32]
@    VLD1.16    {d3},  [r7]                           @d3: prt[48]prt[16]prt[48]prt[48]
    
@    VADD.S16   d4,   d0,  d3                         @d4: r0 r0 r0 r0
@    VSUB.S16   d0,   d0,  d3                         @d0: r3 r3 r3 r3
@    VADD.S16   d3,   d1,  d2                         @d3: r1 r1 r1 r1
@    VSUB.S16   d1,   d1,  d2                         @d1: r2 r2 r2 r2
    
@    VADD.S16   d2,   d4,  d3
@    VST1.16    {d2},  [r4]
@    VSUB.S16   d2,   d4,  d3
@    VST1.16    {d2},  [r6]
    
@    VSHL.S16   Q1,   Q0,  #1                         @d2: r3 << 1 ; d3: r2 << 1
@    VADD.S16   d2,   d2,  d1
@    VST1.16    {d2},  [r5]
@    VSUB.S16   d2,   d0,  d3
@    VST1.16    {d2},  [r7]
    
@    ldmia      sp!, {r4 - r12, pc}
@    @ENDP  @ |trans|
    
    
    .section .text
    .global  MBInterIdct
MBInterIdct:
    stmdb      sp!,  {r4 - r12, lr}
    ldr        r4,   [r2,  #184]                             @r4: currMB->CBP
    add        r5,   r2,   #380                              @r5: currMB->nz_coeff
    mov        r6,   #1
    
    VMOV.U8    Q5,   #0xff
    VMOV.U32   Q6,   #0xff
    
    mov        r7,   #0                                      @r7: b8
1:
    mov        r8,   r1                                      @r8: cur = curL;
    mov        r9,   r0                                      @r9: coef = coef8;
    
    and        r10,  r4,  r6,  lsl r7
    cmp        r10,  #0
    beq        7f
    
    mov        r10,  #0                                      @r10: b4
2:
    
    mov        r11,  #16
    mul        r12,  r11, r7
    mov        r11,  #4
    mla        r12,  r11,  r10, r12
    
    ldr        r11,  =blkIdx2blkXY
    ldr        r11,  [r11,  r12]                             @r11: blkidx = blkIdx2blkXY[b8][b4];
    
    ldrb       r11,  [r5,   r11]
    cmp        r11,  #0
    beq        4f
    
    mov        r11,  #4
3:
    VLD1.16    d0,   [r9]                                    @d0: coef[3]coef[2]coef[1]coef[0]
    VMOVL.S16  Q0,   d0                                      @Q0: coef[3]coef[2]coef[1]coef[0]
    VDUP.S32   d3,   d1[1]                                   @d3: coef[3]coef[3]
    VDUP.S32   d2,   d0[1]                                   @d2: coef[1]coef[1]
    
    VSHR.S32   Q1,   Q1,  #1                                 @d2: (coef[1]>>1); d3:(coef[3]>>1)
    VMOV.S32   r12,  d0[0]
    VMOV.S32   d2[0], r12                                    @d2: (coef[1]>>1) coef[0]
    VSUB.S32   d4,   d2,  d1                                 @d4: r2 r1
    
    VMOV.S32   r12,  d1[0]
    VMOV.S32   d3[0], r12                                    @d3: (coef[3]>>1) coef[2]
    VADD.S32   d5,   d3,  d0                                 @d5: r3 r0
    
    VZIP.S32   d5,   d4                                      @d4: r2 r3; d5:r1 r0
    
    VADD.S32   d0,   d4,  d5                                 @d0: (r1+r2)(r0+r3)
    VSUB.S32   d1,   d5,  d4                                 @d1: (r1-r2)(r0-r3)
    
    VREV64.32  d1,   d1                                      @d1: (r0-r3)(r1-r2)
    VUZP.16    d0,   d1
    
    VST1.16    {d0}, [r9]
    add        r9,   r9,  #32
    
    subs       r11,  r11, #1
    bgt        3b
    
    sub        r9,   r9,  #128
    VLD1.16    {d0},   [r9]                               @d0: coef[0]
    add        r11,  r9,  #32
    VLD1.16    {d2},   [r11]                               @d2: coef[16]
    add        r11,  r11,  #32
    VLD1.16    {d1},   [r11]                               @d1: coef[32]
    add        r11,  r11,  #32
    VLD1.16    {d3},   [r11]                               @d3: coef[48]
    
    VADDL.S16  Q2,   d0,  d1                              @Q2: r0 r0 r0 r0
    VSUBL.S16  Q3,   d0,  d1                              @Q3: r1 r1 r1 r1
    
    VSHR.S16   Q4,   Q1,  #1                              @d9: (coef[48]>>1)  d8: (coef[16]>>1)
    
    VSUBL.S16  Q7,   d8,  d3                              @Q7: r2 r2 r2 r2
    VADDL.S16  Q8,   d9,  d2                              @Q8: r3 r3 r3 r3
    
    VADD.S32   Q0,   Q2,  Q8                              @Q0: r0 r0 r0 r0
    VSUB.S32   Q1,   Q2,  Q8                              @Q1: r3 r3 r3 r3
    VADD.S32   Q2,   Q3,  Q7                              @Q2: r1 r1 r1 r1
    VSUB.S32   Q3,   Q3,  Q7                              @Q3: r2 r2 r2 r2
    
    VMOV.S32   Q4,   #32
    VADD.S32   Q0,   Q0,  Q4
    VADD.S32   Q1,   Q1,  Q4
    VADD.S32   Q2,   Q2,  Q4
    VADD.S32   Q3,   Q3,  Q4
    
    VSHR.S32   Q0,   Q0,  #6
    VSHR.S32   Q1,   Q1,  #6
    VSHR.S32   Q2,   Q2,  #6
    VSHR.S32   Q3,   Q3,  #6
    
    VLD1.8     {d8},  [r8]
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q0,   Q0,  d8
    VCGT.U32   Q7,   Q0,  Q6
    VSHR.S32   Q8,   Q0,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q0,   Q8,  Q7
    
    VMOV       r11,  r12, d0
    strb       r11,  [r8]
    strb       r12,  [r8, #1]
    VMOV       r11,  r12, d1
    strb       r11,  [r8, #2]
    strb       r12,  [r8, #3]
    
    add        r2,   r8,   r3
    VLD1.8     {d8},  [r2]
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q2,   Q2,  d8
    VCGT.U32   Q7,   Q2,  Q6
    VSHR.S32   Q8,   Q2,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q2,   Q8,  Q7
    
    VMOV       r11,  r12, d4
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d5
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    
    add        r2,   r2,   r3
    VLD1.8     {d8},  [r2]
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q3,   Q3,  d8
    VCGT.U32   Q7,   Q3,  Q6
    VSHR.S32   Q8,   Q3,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q3,   Q8,  Q7
    
    VMOV       r11,  r12, d6
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d7
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    
    add        r2,   r2,   r3
    VLD1.8     {d8},  [r2]
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q1,   Q1,  d8
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    
4:
    and        r11,  r10,  #1
    cmp        r11,  #0
    beq        5f
    
    add        r8,   r8,  r3,  lsl #2
    sub        r8,   r8,  #4                                 @r8: cur += ((picPitch << 2) - 4);
    add        r9,   r9,  #120                               @r9: coef += 60;
    b          6f
5:
    add        r8,   r8,  #4
    add        r9,   r9,  #8
    
6:
    add        r10,  r10, #1
    cmp        r10,  #4
    blt        2b
    
7:
    and        r11,  r7,  #1
    cmp        r11,  #0
    beq        8f
    
    add        r1,   r1,  r3,  lsl  #3
    sub        r1,   r1,  #8
    
    add        r0,   r0,  #240
    b          9f
8:
    add        r1,   r1,  #8
    add        r0,   r0,  #16
    
9:
    add        r7,   r7,  #1
    cmp        r7,   #4
    blt        1b
    
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |MBInterIdct|
    .section .rodata
blkIdx2blkXY:    .word    0, 1, 4, 5,   2, 3, 6, 7,   8, 9, 12, 13,    10, 11, 14, 15





    
    .section .text
    .global  dct_luma
dct_luma:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)coef_cost, lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
    sub        sp,  sp,  #24
    
    ldr        r4,  [r0, #0]                             @r4: AVCCommonObj *video = encvid->common;
    ldr        r5,  [r0, #24]                            @r5: encvid->currInput;
    ldr        r5,  [r5, #16]                            @r5: int org_pitch = encvid->currInput->pitch;
    ldr        r6,  [r4, #772]                           @r6: int pred_pitch = video->pred_pitch;
    
    ldr        r7,  =0xffff0001
    VMOV.S32   d10[0], r7                                @d10: -1  -  1
    
    and        r7,  r1,  #3
    lsl        r7,  r7,  #2
    asr        r8,  r1,  #2
    add        r7,  r7,  r8,  lsl #6
    add        r7,  r4,  r7,  lsl #1                     @r7: coef += ((blkidx & 0x3) << 2) + ((blkidx >> 2) << 6);
    
    ldr        r8,  [r4,  #768]                          @r8: uint8 *pred = video->pred_block;
    
    mov        r10, #32
    mov        r9,  #4
1:
    VLD1.8     {d0},  [r3], r5
    VLD1.8     {d1},  [r8], r6
    
    VSUBL.U8   Q0,    d0,   d1                           @d0: r3 r2 r1 r0
    VSHR.U64   d1,    d0,   #32                          @d1: x  x  r3 r2
    VREV32.16  d1,    d1                                 @d1: x  x  r2 r3
    
    VADD.S16   d2,    d0,   d1                           @d2: x  x  r1 r0
    VSUB.S16   d0,    d0,   d1                           @d0: x  x  r2 r3
    
    VMUL.S16   d1,    d0,   d10                          @d1: x x -r2 r3
    
    VTRN.16    d2,    d0                                 @d0: x x r2 r1; d2: x x r3 r0
    VADD.S16   d3,    d0,   d2                           @d3: x x (r2+r3)(r0+r1)
    VSUB.S16   d0,    d2,   d0                           @d0: x x (r3-r2)(r0-r1)
    VTRN.16    d3,    d0                                 @d0: x x (r3-r2)(r3+r2); d3:x x (r0-r1)(r0+r1)
    
    VADD.S16   d0,    d0,   d1                           @d0: x x (r3-2*r2)(2*r3+r2)
    
    VZIP.S16   d3,    d0                                 @d3: (r3-2*r2)(r0-r1)(2*r3+r2)(r0+r1)
    VST1.16    {d3},  [r7], r10
    
    subs       r9,    r9,   #1
    bgt        1b
    
    sub        r7,    r7,   #128                         @r7: coef -= 64;
    sub        r8,    r8,   r6,  lsl #2                  @r8: pred -= (pred_pitch << 2);
    
    @@@@@@@@@@@@vertical@@@@@@@@@@@@@@@@@
    VLD1.16    {d0},   [r7]                              @d0:coef[0]coef[0]coef[0]coef[0]
    add        r9,     r7,   #32
    VLD1.16    {d1},   [r9]                              @d1:coef[16]coef[16]coef[16]coef[16]
    add        r10,    r9,   #32
    VLD1.16    {d3},   [r10]                             @d3:coef[32]coef[32]coef[32]coef[32]
    add        r12,    r10,  #32
    VLD1.16    {d2},   [r12]                             @d2:coef[48]coef[48]coef[48]coef[48]
    
    VADD.S16   Q2,    Q0,   Q1                           @Q2:r1 r1 r1 r1 - r0 r0 r0 r0;  assume it can not overflow
    VSUB.S16   Q0,    Q0,   Q1                           @Q0:r2 r2 r2 r2 - r3 r3 r3 r3
    
    VADD.S16   d2,    d4,   d5                           @d2:(r0+r1)....
    VSUB.S16   d3,    d4,   d5                           @d3:(r0-r1)....
    
    VSHL.S16   Q2,    Q0,   #1
    VADD.S16   d4,    d4,   d1                           @d4:((r3<<1)+r2)....
    VSUB.S16   d5,    d0,   d5                           @d5:(r3 - (r2<<1))
    
    VST1.16    {d2},   [r7]
    VST1.16    {d3},   [r10]
    VST1.16    {d4},   [r9]
    VST1.16    {d5},   [r12]
    
    @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@quant@@@@@@@@@r3 r5 is available@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    ldr        r3,     =ras2dec
    ldrb       r3,     [r3,  r1]                         @r3: ras2dec[blkidx]
    
    add        r5,     r0,   #32
    add        r5,     r5,   r3,  lsl #6                 @r5: level = encvid->level[ras2dec[blkidx]];
    add        r3,     r5,   #1536                       @r3: run = encvid->run[ras2dec[blkidx]];
    
    ldr        r9,     [r4,  #820]
    str        r9,     [sp]                              @sp[0]: Qq = video->QPy_div_6;
    add        r9,     r9,   #15
    str        r9,     [sp,  #4]                         @sp[1]: q_bits = 15 + Qq;
    ldr        r9,     [r4,  #824]
    str        r9,     [sp,  #8]                         @sp[2]: Rq = video->QPy_mod_6;
    ldr        r9,     [r0,  #3372]
    str        r9,     [sp,  #12]                        @sp[3]: qp_const = encvid->qp_const;
    
    str        r3,     [sp,  #16]                        @sp[4]: run
    str        r5,     [sp,  #20]                        @sp[5]: level
    
    
    mov        r3,     #0                                @r3: zero_run = 0;
    mov        r5,     #0                                @r5: numcoeff = 0;
    mov        r0,     #0                                @r0: k
2:
    ldr        r9,     =ZZ_SCAN_BLOCK
    ldrb       r9,     [r9,  r0]                         @r9: idx
    
    ldr        r1,     =quant_coef
    ldr        r10,    [sp,  #8]                         @r10: Rq
    add        r12,    r0,   r10,  lsl #4
    ldr        r1,     [r1,  r12,  lsl #2]               @r1: quant = quant_coef[Rq][k];
    
    lsl        r9,     r9,   #1
    ldrsh      r11,    [r7,  r9]                         @r11: data
    cmp        r11,    #0
    rsblt      r11,    r11,  #0
3:
    
    ldr        r12,    [sp,  #12]
    mla        r12,    r11,   r1,  r12                   @r12: lev = data * quant + qp_const;
    ldr        r11,    [sp,  #4]
    asr        r12,    r12,   r11                        @r12: lev >>= q_bits;
    
    cmp        r12,    #0
    beq        6f
    
    cmp        r12,    #1
    bgt        4f
    ldr        r11,    =COEFF_COST
    ldrb       r11,    [r11,  r3]
    b          5f
4:
    ldr        r11,    =999999
    
5:
    ldr        r1,     [sp,  #64]                        @r1: int *coef_cost
    ldr        lr,     [r1]
    add        r11,     lr,   r11
    str        r11,    [r1]
    
    add        r1,     r0,   r10,  lsl #4
    ldr        r11,    =dequant_coefres
    ldr        r1,     [r11, r1, lsl #2]                 @r1: quant = dequant_coefres[Rq][k];
    
    ldrsh      r11,    [r7,  r9]                         @r11: data
    cmp        r11,    #0
    rsblt      r12,    r12,  #0                          @r12: -lev
    
    
    ldr        r11,     [sp,  #20]
    str        r12,     [r11, r5, lsl #2]                @level[numcoeff] = lev;
    
    mul        r11,    r12,   r1
    ldr        r1,     [sp]
    lsl        r11,    r11,   r1
    strh       r11,    [r7,  r9]
    
    
    ldr        r11,    [sp,  #16]
    str        r3,     [r11, r5, lsl #2]
    add        r5,     r5,   #1
    mov        r3,     #0
    b          7f
    
6:
    add        r3,     r3,    #1
    strh       r12,    [r7,  r9]
7:
    add        r0,     r0,    #1
    cmp        r0,     #16
    blt        2b
    
    
    
    VMOV.U8    Q5,     #0xff
    VMOV.U32   Q6,     #0xff
    
    ldr        r0,  [r4,  #912]                         @r0:video->currMB
    ldr        r0,  [r0,  #156]                         @r0:video->currMB->mb_intra
    ldr        r1,  [r4,  #884]
    ldr        r1,  [r1,  #48]                          @r1:int pitch = video->currPic->pitch;
    
    cmp        r0,     #0
    beq        10f
    
    cmp        r5,     #0
    beq        9f
    
    mov        r4,   #32
    mov        r11,  #4
8:
    VLD1.16    d0,   [r7]                                    @d0: coef[3]coef[2]coef[1]coef[0]
    VMOVL.S16  Q0,   d0                                      @Q0: coef[3]coef[2]coef[1]coef[0]
    VTRN.32    Q0,   Q1                                      @Q0: x coef[2] x coef[0]; Q1: x coef[3] x coef[1]
    VSHR.S32   Q2,   Q1,  #1                                 @d4: x (coef[1]>>1); d5: x (coef[3]>>1)
    
    
    VZIP.S32   Q0,   Q2                                      @d0: (coef[1]>>1) coef[0]; d4:(coef[3]>>1)coef[2]
    VMOV       d1,   d4                                      @d1: (coef[3]>>1)coef[2]
    VTRN.32    d4,   d3                                      @d4: coef[3] coef[2];      d3: x (coef[3]>>1)
    VSUB.S32   d4,   d0,  d4                                 @d4: r2 r1
    
    VTRN.32    d0,   d2                                      @d0: coef[1] coef[0]
    VADD.S32   d5,   d1,  d0                                 @d5: r3 r0
    
    VZIP.S32   d5,   d4                                      @d4: r2 r3; d5:r1 r0
    
    VADD.S32   d0,   d4,  d5                                 @d0: (r1+r2)(r0+r3)
    VSUB.S32   d1,   d5,  d4                                 @d1: (r1-r2)(r0-r3)
    
    VREV64.32  d1,   d1                                      @d1: (r0-r3)(r1-r2)
    VUZP.16    d0,   d1
    
    VST1.16    {d0}, [r7], r4
    
    subs       r11,  r11, #1
    bgt        8b
    
    
    sub        r7,   r7,  #128
    VLD1.16    {d0},   [r7]                                @d0: coef[0]
    add        r11,  r7,  #32
    VLD1.16    {d2},   [r11]                               @d2: coef[16]
    add        r11,  r11,  #32
    VLD1.16    {d1},   [r11]                               @d1: coef[32]
    add        r11,  r11,  #32
    VLD1.16    {d3},   [r11]                               @d3: coef[48]
    
    VADDL.S16  Q2,   d0,  d1                              @Q2: r0 r0 r0 r0
    VSUBL.S16  Q3,   d0,  d1                              @Q3: r1 r1 r1 r1
    
    VSHR.S16   Q4,   Q1,  #1                              @d9: (coef[48]>>1)  d8: (coef[16]>>1)
    
    VSUBL.S16  Q7,   d8,  d3                              @Q7: r2 r2 r2 r2
    VADDL.S16  Q8,   d9,  d2                              @Q8: r3 r3 r3 r3
    
    VADD.S32   Q0,   Q2,  Q8                              @Q0: r0 r0 r0 r0
    VSUB.S32   Q1,   Q2,  Q8                              @Q1: r3 r3 r3 r3
    VADD.S32   Q2,   Q3,  Q7                              @Q2: r1 r1 r1 r1
    VSUB.S32   Q3,   Q3,  Q7                              @Q3: r2 r2 r2 r2
    
    VMOV.S32   Q4,   #32
    VADD.S32   Q0,   Q0,  Q4
    VADD.S32   Q1,   Q1,  Q4
    VADD.S32   Q2,   Q2,  Q4
    VADD.S32   Q3,   Q3,  Q4
    
    VSHR.S32   Q0,   Q0,  #6
    VSHR.S32   Q1,   Q1,  #6
    VSHR.S32   Q2,   Q2,  #6
    VSHR.S32   Q3,   Q3,  #6
    
    VLD1.8     {d8},  [r8], r6
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q0,   Q0,  d8
    VCGT.U32   Q7,   Q0,  Q6
    VSHR.S32   Q8,   Q0,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q0,   Q8,  Q7
    
    VMOV       r11,  r12, d0
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d1
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    add        r2,   r2,   r1
    VLD1.8     {d8},  [r8], r6
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q2,   Q2,  d8
    VCGT.U32   Q7,   Q2,  Q6
    VSHR.S32   Q8,   Q2,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q2,   Q8,  Q7
    
    VMOV       r11,  r12, d4
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d5
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    
    add        r2,   r2,   r1
    VLD1.8     {d8},  [r8], r6
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q3,   Q3,  d8
    VCGT.U32   Q7,   Q3,  Q6
    VSHR.S32   Q8,   Q3,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q3,   Q8,  Q7
    
    VMOV       r11,  r12, d6
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d7
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    
    add        r2,   r2,   r1
    VLD1.8     {d8},  [r8]
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q1,   Q1,  d8
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r2]
    strb       r12,  [r2, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r2, #2]
    strb       r12,  [r2, #3]
    
    b          10f
9:
    ldr        r0,     [r8], r6
    str        r0,     [r2], r1
    ldr        r0,     [r8], r6
    str        r0,     [r2], r1
    ldr        r0,     [r8], r6
    str        r0,     [r2], r1
    ldr        r0,     [r8]
    str        r0,     [r2]
10:
    mov        r0,     r5
    add        sp,  sp,  #24
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |dct_luma|
    
    .ltorg
    .section .rodata
ras2dec:           .byte    0, 1, 4, 5, 2, 3, 6, 7, 8, 9, 12, 13, 10, 11, 14, 15
ZZ_SCAN_BLOCK:     .byte    0, 1, 16, 32, 17, 2, 3, 18, 33, 48, 49, 34, 19, 35, 50, 51
quant_coef:        .word    13107, 8066,   8066,   13107,  5243,   13107,  8066,   8066,   8066,   8066,   5243,   13107,  5243,   8066,   8066,   5243
                   .word    11916, 7490,   7490,   11916,  4660,   11916,  7490,   7490,   7490,   7490,   4660,   11916,  4660,   7490,   7490,   4660
                   .word    10082, 6554,   6554,   10082,  4194,   10082,  6554,   6554,   6554,   6554,   4194,   10082,  4194,   6554,   6554,   4194
                   .word    9362,  5825,   5825,   9362,   3647,   9362,   5825,   5825,   5825,   5825,   3647,   9362,   3647,   5825,   5825,   3647
                   .word    8192,  5243,   5243,   8192,   3355,   8192,   5243,   5243,   5243,   5243,   3355,   8192,   3355,   5243,   5243,   3355
                   .word    7282,  4559,   4559,   7282,   2893,   7282,   4559,   4559,   4559,   4559,   2893,   7282,   2893,   4559,   4559,   2893
COEFF_COST:        .byte    3, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                   .byte    9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9
dequant_coefres:   .word    10, 13, 13, 10, 16, 10, 13, 13, 13, 13, 16, 10, 16, 13, 13, 16
                   .word    11, 14, 14, 11, 18, 11, 14, 14, 14, 14, 18, 11, 18, 14, 14, 18
                   .word    13, 16, 16, 13, 20, 13, 16, 16, 16, 16, 20, 13, 20, 16, 16, 20
                   .word    14, 18, 18, 14, 23, 14, 18, 18, 18, 18, 23, 14, 23, 18, 18, 23
                   .word    16, 20, 20, 16, 25, 16, 20, 20, 20, 20, 25, 16, 25, 20, 20, 25
                   .word    18, 23, 23, 18, 29, 18, 23, 23, 23, 23, 29, 18, 29, 23, 23, 29
ZIGZAG2RASTERDC:   .byte    0, 4, 64, 128, 68, 8, 12, 72, 132, 192, 196, 136, 76, 140, 200, 204
    
    
    .section .text
    .global  dct_luma_16x16
dct_luma_16x16:
    stmdb      sp!, {r4 - r12, lr}
    
    sub        sp,  sp,  #24
    
    ldr        r4,  [r0, #0]                             @r4:AVCCommonObj *video = encvid->common;
    ldr        r5,  [r4,  #912]                          @r5:AVCMacroblock *currMB = video->currMB;
    ldr        r6,  [r5,  #188]                          @r6: currMB->i16Mode
    ldr        r7,   =3380
    add        r7,  r7,   r6,  lsl #8
    add        r6,  r0,   r7                             @r6: uint8 *pred = encvid->pred_i16[currMB->i16Mode];
    
    ldr        r7,  [r0, #24]                            @r7: encvid->currInput;
    ldr        r7,  [r7, #16]                            @r7: int org_pitch = encvid->currInput->pitch;
    
    mov        r8,  r4                                   @r8: int16 *coef = video->block;
    
    VMOV.I8    Q10,   #0xff
    VSHL.U32   Q10,   Q10,   #16
    mov        r3,   #16
1:
    VLD1.8     {d0, d1},  [r2], r7
    VLD1.8     {d2, d3},  [r6]!
    
    VSUBL.U8   Q2,   d0,   d2                            @Q2: r3 r2 r1 r0 - r3 r2 r1 r0
    VSUBL.U8   Q3,   d1,   d3                            @Q3: r3 r2 r1 r0 - r3 r2 r1 r0
    
    VSHR.U64   Q0,   Q2,   #32                           @Q0: xx xx r3 r2 - xx xx r3 r2
    VREV32.16  Q0,   Q0                                  @Q0: xx xx r2 r3 - xx xx r2 r3
    VSHR.U64   Q1,   Q3,   #32                           @Q1: xx xx r3 r2 - xx xx r3 r2
    VREV32.16  Q1,   Q1                                  @Q1: xx xx r2 r3 - xx xx r2 r3
    
    VADD.S16   Q4,   Q2,   Q0
    VADD.S16   Q5,   Q3,   Q1                            @Q4,Q5: xxxx(r1)(r0)
    VSUB.S16   Q0,   Q2,   Q0
    VSUB.S16   Q1,   Q3,   Q1                            @Q0,Q1: xxxx(r2)(r3)
    
    VTRN.16    Q4,   Q0                                  @Q0: xxxx(r2)(r1); Q4:xxxx(r3)(r0)
    VTRN.16    Q5,   Q1                                  @Q1: xxxx(r2)(r1); Q5:xxxx(r3)(r0)
    
    VADD.S16   Q2,   Q4,   Q0                            @Q2: xxxx(r2+r3)(r0+r1)
    VADD.S16   Q3,   Q5,   Q1                            @Q3: xxxx(r2+r3)(r0+r1)
    VAND       Q6,   Q4,   Q10                           @Q6: xxxx(r3)xx
    VAND       Q7,   Q5,   Q10                           @Q7: xxxx(r3)xx
    VADD.S16   Q2,   Q2,   Q6                            @Q2: xxxx(r2+2*r3)(r0+r1)
    VADD.S16   Q3,   Q3,   Q7                            @Q3: xxxx(r2+2*r3)(r0+r1)
    
    VSUB.S16   Q4,   Q4,   Q0                            @Q4: xxxx(r3-r2)(r0-r1)
    VSUB.S16   Q5,   Q5,   Q1                            @Q5: xxxx(r3-r2)(r0-r1)
    VAND       Q0,   Q0,   Q10                           @Q0: xxxx(r2)xx
    VAND       Q1,   Q1,   Q10                           @Q1: xxxx(r2)xx
    VSUB.S16   Q4,   Q4,   Q0                            @Q4: xxxx(r3-2*r2)(r0-r1)
    VSUB.S16   Q5,   Q5,   Q1                            @Q5: xxxx(r3-2*r2)(r0-r1)
    
    VZIP.32    Q2,   Q4                                  @Q2,Q4: xxxx(r3-2*r2)(r0-r1)(r2+2*r3)(r0+r1)
    VZIP.32    Q3,   Q5                                  @Q3,Q5: xxxx(r3-2*r2)(r0-r1)(r2+2*r3)(r0+r1)
    
    VST1.16    {d4},  [r8]!
    VST1.16    {d8},  [r8]!
    VST1.16    {d6},  [r8]!
    VST1.16    {d10}, [r8]!
    
    subs       r3,   r3,  #1
    bgt        1b
    
    sub        r6,   r6,  #256
    sub        r8,   r8,  #512
    
    mov        r3,   #4
2:
    VLD1.16    {d0, d1, d2, d3},  [r8]                   @d0-d3: coef[0]
    add        r9,   r8,  #32
    VLD1.16    {d4, d5, d6, d7},  [r9]                   @d4-d7: coef[16]
    add        r10,   r9,  #32
    VLD1.16    {d8, d9, d10, d11},  [r10]                @d8-d11: coef[32]
    add        r11,   r10,  #32
    VLD1.16    {d12, d13, d14, d15},  [r11]              @d12-d15: coef[48]
    
    VADD.S16   Q8,   Q0,   Q6
    VADD.S16   Q9,   Q1,   Q7                            @Q8,Q9: r0
    VADD.S16   Q11,  Q2,   Q4
    VADD.S16   Q12,  Q3,   Q5                            @Q11,Q12: r1
    
    VADD.S16   Q13,  Q8,   Q11                           @Q13: (r0+r1)
    VADD.S16   Q14,  Q9,   Q12                           @Q14: (r0+r1)
    VST1.16    {d26,d27,d28,d29},  [r8]
    
    VSUB.S16   Q13,  Q8,   Q11                           @Q13: (r0-r1)
    VSUB.S16   Q14,  Q9,   Q12                           @Q14: (r0-r1)
    VST1.16    {d26,d27,d28,d29},  [r10]
    
    
    VSUB.S16   Q8,   Q0,   Q6
    VSUB.S16   Q9,   Q1,   Q7                            @Q8,Q9: r3
    VSUB.S16   Q11,  Q2,   Q4
    VSUB.S16   Q12,  Q3,   Q5                            @Q11,Q12: r2
    
    VSHL.S16   Q13,  Q8,   #1
    VSHL.S16   Q14,  Q9,   #1                            @Q13,Q14:(r3 << 1)
    VADD.S16   Q13,  Q13,  Q11                           @Q13: (r3 << 1) + r2
    VADD.S16   Q14,  Q14,  Q12                           @Q14: (r3 << 1) + r2
    VST1.16    {d26,d27,d28,d29},  [r9]
    
    VSHL.S16   Q13,  Q11,   #1
    VSHL.S16   Q14,  Q12,   #1                           @Q13,Q14:(r2 << 1)
    VSUB.S16   Q13,  Q8,   Q13                           @Q13: r3 - (r2 << 1)
    VSUB.S16   Q14,  Q9,   Q14                           @Q14: r3 - (r2 << 1)
    VST1.16    {d26,d27,d28,d29},  [r11]
    
    add        r8,   r8,   #128
    subs       r3,   r3,   #1
    bgt        2b
    
    
    sub        r8,   r8,  #512
    mov        r3,   #4
3:
    ldrsh      r9,   [r8]
    ldrsh      r10,  [r8,  #8]
    VMOV       d0,   r9,  r10                            @d0: coef[4]coef[0]
    ldrsh      r9,   [r8,  #24]
    ldrsh      r10,  [r8,  #16]
    VMOV       d1,   r9,  r10                            @d1: coef[8]coef[12]
    
    VADD.S32   d2,   d0,  d1                             @d2: r1 r0
    VSUB.S32   d3,   d0,  d1                             @d3: r2 r3
    
    VTRN.32    d2,   d3                                  @d2: r3 r0; d3: r2 r1
    VADD.S32   d0,   d2,  d3                             @d0: (r3+r2)(r0+r1)
    VSUB.S32   d1,   d2,  d3                             @d1: (r3-r2)(r0-r1)
    
    VMOV       r9,   r10, d0
    strh       r9,   [r8]
    strh       r10,  [r8,  #8]
    VMOV       r9,   r10, d1
    strh       r9,   [r8,  #16]
    strh       r10,  [r8,  #24]
    
    add        r8,   r8,   #128
    subs       r3,   r3,   #1
    bgt        3b
    
    
    sub        r8,   r8,  #512
    
    mov        r11,  #256
    mov        r12,  #384
    mov        r3,   #4
4:
    ldrsh      r9,   [r8]
    ldrsh      r10,  [r8,  #128]
    VMOV       d0,   r9,  r10                            @d0: coef[64]coef[0]
    ldrsh      r9,   [r8,  r12]
    ldrsh      r10,  [r8,  r11]
    VMOV       d1,   r9,  r10                            @d1: coef[128]coef[192]
    
    VADD.S32   d2,   d0,  d1                             @d2: r1 r0
    VSUB.S32   d3,   d0,  d1                             @d3: r2 r3
    
    VTRN.32    d2,   d3                                  @d2: r3 r0; d3: r2 r1
    VADD.S32   d0,   d2,  d3                             @d0: (r3+r2)(r0+r1)
    VSUB.S32   d1,   d2,  d3                             @d1: (r3-r2)(r0-r1)
    VSHR.S32   Q0,   Q0,  #1
    
    VMOV       r9,   r10, d0
    strh       r9,   [r8]
    strh       r10,  [r8,  #128]
    VMOV       r9,   r10, d1
    strh       r9,   [r8,  r11]
    strh       r10,  [r8,  r12]
    
    add        r8,   r8,   #8
    subs       r3,   r3,   #1
    bgt        4b
    
    
    sub        r8,   r8,  #32
    
    
    ldr        r3,   =quant_coef
    ldr        r7,   [r4, #824]                          @Rq = video->QPy_mod_6;
    str        r7,   [sp]                                @sp[0]: Rq
    ldr        r3,   [r3, r7, lsl #6]                    @r3: quant = quant_coef[Rq][0];
    ldr        r7,   [r4, #820]                          @r7: Qq = video->QPy_div_6;
    add        r7,   r7,  #16
    
    mov        r9,   #0                                  @r9: zero_run = 0;
    mov        r10,  #0                                  @r10:ncoeff = 0;
    mov        r11,  #0                                  @r11:k
5:
    ldr        r12,  =ZIGZAG2RASTERDC
    ldrb       r12,  [r12, r11]                          @r12:idx = ZIGZAG2RASTERDC[k];
    lsl        r12,  r12,  #1
    ldrsh      lr,   [r8,  r12]
    
    cmp        lr,   #0
    rsblt      lr,   lr,   #0
6:
    ldr        r2,   [r0, #3372]                          @qp_const = encvid->qp_const;
    lsl        r2,   r2,   #1
    mla        r2,   lr,   r3,  r2                        @r2:lev
    
    asr        r2,   r2,  r7
    
    cmp        r2,   #0
    beq        8f
    
    ldrsh      lr,   [r8,  r12]
    cmp        lr,   #0
    rsblt      r2,   r2,    #0
7:
    add        lr,   r0,    #3104
    str        r2,   [lr,   r10, lsl #2]
    strh       r2,   [r8,   r12]
    
    add        lr,   r0,    #3168
    str        r9,   [lr,   r10, lsl #2]
    add        r10,  r10,   #1
    mov        r9,   #0
    b          9f
    
8:
    add        r9,   r9,    #1
    strh       r2,   [r8,  r12]
9:
    add        r11,  r11,   #1
    cmp        r11,  #16
    blt        5b
    
    str        r10,  [r0,   #3368]                       @r10:encvid->numcoefdc = ncoeff;
    
    cmp        r10,  #0
    beq        15f
    
    mov        r11,   #4
10:
    ldrsh      r9,   [r8]
    ldrsh      r10,  [r8,  #16]
    VMOV       d0,   r9,  r10                            @d0: coef[8]coef[0]
    ldrsh      r9,   [r8,  #8]
    ldrsh      r10,  [r8,  #24]
    VMOV       d1,   r9,  r10                            @d1: coef[12]coef[4]
    
    VADD.S32   d2,   d0,  d1                             @d2: m2 m0
    VSUB.S32   d3,   d0,  d1                             @d3: m3 m1
    
    VTRN.32    d2,   d3                                  @d2: m1 m0; d3: m3 m2
    VADD.S32   d0,   d2,  d3                             @d0: (m1+m3)(m0+m2)
    VSUB.S32   d1,   d2,  d3                             @d1: (m1-m3)(m0-m2)
    
    VMOV       r9,   r10, d0
    strh       r9,   [r8]
    strh       r10,  [r8,  #24]
    VMOV       r9,   r10, d1
    strh       r9,   [r8,  #8]
    strh       r10,  [r8,  #16]
    
    add        r8,   r8,   #128
    subs       r11,   r11,   #1
    bgt        10b
    
    sub        r8,   r8,   #512
    sub        r7,   r7,   #16                          @r7: Qq
    
    ldr        r2,   =dequant_coefres
    ldr        r3,   [sp]
    ldr        r2,   [r2,  r3, lsl #6]                   @quant = dequant_coefres[Rq][0];
    VDUP.32    Q2,   r2
    
    cmp        r7,   #2
    bge        12f
    
    rsb        r3,   r7,   #2
    sub        r11,  r3,   #1
    mov        r12,  #1
    lsl        r12,  r12,  r11
    VDUP.S32   Q3,   r3                                  @Q3:Qq
    VNEG.S32   Q3,   Q3                                  @Q3:-Qq
    VDUP.S32   Q4,   r12                                 @Q4:offset
    
    mov        r11,  #256
    mov        r12,  #384
    mov        r3,   #4
11:
    ldrsh      r9,   [r8]
    ldrsh      r10,  [r8,  r11]
    VMOV       d0,   r9,  r10                            @d0: coef[128]coef[0]
    ldrsh      r9,   [r8,  #128]
    ldrsh      r10,  [r8,  r12]
    VMOV       d1,   r9,  r10                            @d1: coef[192]coef[64]
    
    VADD.S32   d2,   d0,  d1                             @d2: m2 m0
    VSUB.S32   d3,   d0,  d1                             @d3: m3 m1
    
    VTRN.32    d2,   d3                                  @d2: m1 m0; d3: m3 m2
    VADD.S32   d0,   d2,  d3                             @d0: (m1+m3)(m0+m2)
    VSUB.S32   d1,   d2,  d3                             @d1: (m1-m3)(m0-m2)
    
    VMUL.S32   Q1,   Q0,  Q2
    VADD.S32   Q1,   Q1,  Q4
    VSHL.S32   Q0,   Q1,  Q3
    
    VMOV       r9,   r10, d0
    strh       r9,   [r8]
    strh       r10,  [r8,  r12]
    VMOV       r9,   r10, d1
    strh       r9,   [r8,  #128]
    strh       r10,  [r8,  r11]
    
    add        r8,   r8,   #8
    subs       r3,   r3,   #1
    bgt        11b
    
    b          14f
    
12:
    sub        r3,   r7,   #2
    VDUP.S32   Q3,   r3                                  @Q3:Qq
    
    mov        r11,  #256
    mov        r12,  #384
    mov        r3,   #4
13:
    ldrsh      r9,   [r8]
    ldrsh      r10,  [r8,  r11]
    VMOV       d0,   r9,  r10                            @d0: coef[128]coef[0]
    ldrsh      r9,   [r8,  #128]
    ldrsh      r10,  [r8,  r12]
    VMOV       d1,   r9,  r10                            @d1: coef[192]coef[64]
    
    VADD.S32   d2,   d0,  d1                             @d2: m2 m0
    VSUB.S32   d3,   d0,  d1                             @d3: m3 m1
    
    VTRN.32    d2,   d3                                  @d2: m1 m0; d3: m3 m2
    VADD.S32   d0,   d2,  d3                             @d0: (m1+m3)(m0+m2)
    VSUB.S32   d1,   d2,  d3                             @d1: (m1-m3)(m0-m2)
    
    VMUL.S32   Q1,   Q0,  Q2
    VSHL.S32   Q0,   Q1,  Q3
    
    VMOV       r9,   r10, d0
    strh       r9,   [r8]
    strh       r10,  [r8,  r12]
    VMOV       r9,   r10, d1
    strh       r9,   [r8,  #128]
    strh       r10,  [r8,  r11]
    
    add        r8,   r8,   #8
    subs       r3,   r3,   #1
    bgt        13b
    
    
14:
    sub        r8,   r8,   #32
    add        lr,   r7,   #15                           @r7: q_bits = 15 + Qq;
    
15:
    @@@@@@@@@@@@@@@@@@@/* now zigzag scan ac coefs, quant, iquant and itrans */@@@@@@
    mov        r2,   #0
    str        r2,   [r5, #184]                          @currMB->CBP = 0;
    
    ldr        r4,   [r4, #884]
    ldr        r4,   [r4, #48]                           @r4: int pitch = video->currPic->pitch;
    
    @@@@@@@@@@@@@@@@@@@@@@save r4 r5 r6@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    str        r4,   [sp, #4]
    str        r5,   [sp, #8]
    str        r6,   [sp, #12]
    
    add        r10,  r0,  #32
    str        r10,  [sp, #16]                           @sp[4]: level
    add        r10,  r0,  #1568
    str        r10,  [sp, #20]                           @sp[5]: run
    
16:
    mov        r3,   #0                                  @r2: b8; r3:b4
17:
    mov        r6,   #0                                  @r6: zero_run = 0;
    mov        r9,   #0                                  @r9: ncoeff = 0;
    
    mov        r10,  #1                                  @r10: k
18:
    ldr        r12,  [sp]
    add        r12,  r10,   r12,  lsl #4
    ldr        r11,  =quant_coef
    ldr        r12,  [r11,  r12, lsl #2]
    
    
    ldr        r11,  =ZZ_SCAN_BLOCK
    ldrb       r11,  [r11, r10]
    lsl        r11,  r11,  #1
    
    ldrsh      r4,   [r8, r11]                           @r4: data
    cmp        r4,   #0
    rsblt      r4,   r4,   #0
19:
    ldr        r5,   [r0,  #3372]
    mla        r5,   r4,  r12,  r5
    
    asr        r5,   r5,  lr
    
    cmp        r5,   #0
    beq        21f
    
    ldrsh      r4,   [r8,  r11]                          @r4: data
    cmp        r4,   #0
    rsblt      r5,   r5,  #0
20:
    ldr        r4,   [sp, #16]
    str        r5,   [r4, r9, lsl #2]                    @level[ncoeff] = lev;
    
    ldr        r12,  [sp]
    add        r12,  r10,   r12,  lsl #4
    ldr        r4,   =dequant_coefres
    ldr        r12,  [r4,  r12, lsl #2]                  @quant = dequant_coefres[Rq][k];
    
    mul        r4,   r12,  r5
    lsl        r4,   r4,   r7
    strh       r4,   [r8,  r11]
    
    ldr        r4,   [sp, #20]
    str        r6,   [r4,  r9, lsl #2]
    add        r9,   r9,   #1
    mov        r6,   #0
    b          22f
    
21:
    add        r6,   r6,   #1
    strh       r5,   [r8, r11]
    
22:
    add        r10,   r10,  #1
    cmp        r10,   #16
    blt        18b
    
    
    
    ldr        r4,   [sp, #4]
    ldr        r5,   [sp, #8]
    ldr        r6,   [sp, #12]
    
    add        r11,   r3,   r2, lsl #2
    ldr        r10,   =blkIdx2blkXY
    ldr        r11,   [r10,  r11, lsl #2]
    
    add        r10,   r5,   #380
    strb       r9,    [r10, r11]                         @currMB->nz_coeff[blkIdx2blkXY[b8][b4]] = ncoeff;
    
    cmp        r9,    #0
    beq        24f
    
    mov        r9,   #1
    ldr        r10,  [r5, #184]
    orr        r10,  r10,  r9, lsl r2
    str        r10,  [r5, #184]                          @currMB->CBP |= (1 << b8);
    
    mov        r9,   #32
    mov        r10,  #4
23:
    VLD1.16    {d0},  [r8]                               @d0: coef[3]coef[2]coef[1]coef[0]
    VMOVL.S16  Q1,   d0                                  @d2: coef[1]coef[0]; d3:coef[3]coef[2]
    
    VTRN.16    d0,   d1                                  @d0: xx coef[2] xx coef[0]; d1: xx coef[3] xx coef[1]
    VSHR.S16   d1,   d1,    #1
    VTRN.16    d0,   d1                                  @d0: (coef[3]>>1)coef[2](coef[1]>>1)coef[0]
    VMOVL.S16  Q0,   d0                                  @d0: (coef[1]>>1)coef[0]; d1: (coef[3]>>1)coef[2]
    
    VADD.S32   d2,   d2,    d1                           @d2: r3 r0 ((coef[3]>>1)+coef[1])(coef[2]+coef[0])
    VSUB.S32   d3,   d0,    d3                           @d3: r2 r1 ((coef[1]>>1)-coef[3])(coef[0]-coef[2])
    
    VTRN.32    d2,   d3                                  @d2: r1 r0; d3:r2 r3
    VADD.S32   d0,   d2,    d3                           @d0: (r1+r2)(r0+r3)
    VSUB.S32   d1,   d2,    d3                           @d1: (r1-r2)(r0-r3)
    
    VREV64.32  d1,   d1
    VUZP.16    d0,   d1
    
    VST1.16    {d0}, [r8], r9
    
    subs       r10,   r10,   #1
    bgt        23b
    
    VMOV.U8    Q5,   #0xff
    VMOV.U32   Q6,   #0xff
    
    sub        r8,   r8,   #128
    VLD1.16    {d0},   [r8]                                @d0: coef[0]
    add        r11,  r8,  #32
    VLD1.16    {d2},   [r11]                               @d2: coef[16]
    add        r11,  r11,  #32
    VLD1.16    {d1},   [r11]                               @d1: coef[32]
    add        r11,  r11,  #32
    VLD1.16    {d3},   [r11]                               @d3: coef[48]
    
    VADDL.S16  Q2,   d0,  d1                              @Q2: r0 r0 r0 r0
    VSUBL.S16  Q3,   d0,  d1                              @Q3: r1 r1 r1 r1
    
    VSHR.S16   Q4,   Q1,  #1                              @d9: (coef[48]>>1)  d8: (coef[16]>>1)
    
    VSUBL.S16  Q7,   d8,  d3                              @Q7: r2 r2 r2 r2
    VADDL.S16  Q8,   d9,  d2                              @Q8: r3 r3 r3 r3
    
    VADD.S32   Q0,   Q2,  Q8                              @Q0: r0 r0 r0 r0
    VSUB.S32   Q1,   Q2,  Q8                              @Q1: r3 r3 r3 r3
    VADD.S32   Q2,   Q3,  Q7                              @Q2: r1 r1 r1 r1
    VSUB.S32   Q3,   Q3,  Q7                              @Q3: r2 r2 r2 r2
    
    VMOV.S32   Q4,   #32
    VADD.S32   Q0,   Q0,  Q4
    VADD.S32   Q1,   Q1,  Q4
    VADD.S32   Q2,   Q2,  Q4
    VADD.S32   Q3,   Q3,  Q4
    
    VSHR.S32   Q0,   Q0,  #6
    VSHR.S32   Q1,   Q1,  #6
    VSHR.S32   Q2,   Q2,  #6
    VSHR.S32   Q3,   Q3,  #6
    
    mov        r10,  #16
    VLD1.8     {d8},  [r6], r10
    VMOVL.U8   Q4,   d8                                   @d8:pred[0]pred[0]pred[0]pred[0]
    
    VADDW.U16  Q0,   Q0,  d8
    VCGT.U32   Q7,   Q0,  Q6
    VSHR.S32   Q8,   Q0,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q0,   Q8,  Q7
    
    VMOV       r11,  r12, d0
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d1
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,   r4
    VLD1.8     {d8},  [r6], r10
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q2,   Q2,  d8
    VCGT.U32   Q7,   Q2,  Q6
    VSHR.S32   Q8,   Q2,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q2,   Q8,  Q7
    
    VMOV       r11,  r12, d4
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d5
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    
    add        r1,   r1,   r4
    VLD1.8     {d8},  [r6], r10
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q3,   Q3,  d8
    VCGT.U32   Q7,   Q3,  Q6
    VSHR.S32   Q8,   Q3,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q3,   Q8,  Q7
    
    VMOV       r11,  r12, d6
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d7
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    
    add        r1,   r1,   r4
    VLD1.8     {d8},  [r6], r10
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q1,   Q1,  d8
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,  r4
    b          26f
    
24:
    ldrsh      r9,   [r8]
    add        r9,   r9,   #32
    asr        r9,   r9,   #6
    VDUP.S16   d0,   r9                                   @d0: m0 m0 m0 m0
    
    VMOV.U8    Q5,   #0xff
    VMOV.U32   Q6,   #0xff
    
    mov        r9,   #16
    mov        r10,  #4
25:
    VLD1.8     {d1},  [r6], r9
    VMOVL.U8   Q1,   d1                                   @d2: pred[0]pred[0]pred[0]pred[0]
    
    VADDL.S16  Q1,   d0,   d2
    
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,   r4
    subs       r10,  r10,  #1
    blt        25b
    
26:
    add        r8,   r8,   #8
    
    ldr        r11,  [sp, #16]
    add        r11,  r11,  #64
    str        r11,  [sp, #16]
    
    ldr        r11,  [sp, #20]
    add        r11,  r11,  #64
    str        r11,  [sp, #20]
    
    sub        r1,   r1,   r4, lsl #2
    sub        r6,   r6,   #64
    
    and        r11,  r3,   #1
    cmp        r11,  #0
    moveq      r11,  #0
    moveq      r12,  #0
    lslne      r11,  r4,   #2
    subne      r11,  r11,  #4
    movne      r12,  #56
    
    add        r1,   r1,   r11
    add        r6,   r6,   r12
    add        r8,   r8,   r12, lsl #1
    
    add        r3,   r3,   #1
    cmp        r3,   #4
    blt        17b
    
    
    and        r11,  r2,   #1
    cmp        r11,  #0
    lsleq      r11,  r4,   #3
    rsbeq      r11,  r11,  #8
    moveq      r12,  #-120
    movne      r11,  #-8
    movne      r12,  #-8
    
    add        r1,   r1,   r11
    add        r6,   r6,   r12
    add        r8,   r8,   r12, lsl #1
    
    add        r2,   r2,   #1
    cmp        r2,   #4
    blt        16b
    
    
    add        sp,  sp,  #24
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |dct_luma_16x16|
    
    
    .section .text
    .global  dct_chroma
dct_chroma:
    stmdb      sp!, {r4 - r12, lr}
    sub        sp,  sp,  #60
    
    ldr        r4,   [r0, #0]                             @r4:AVCCommonObj *video = encvid->common;
    ldr        r5,   [r4,  #912]                          @r5:AVCMacroblock *currMB = video->currMB;
    ldr        r6,   [r0,  #24]
    ldr        r6,   [r6,  #16]
    asr        r6,   r6,   #1                             @r6: org_pitch = (currInput->pitch) >> 1;
    
    ldr        r7,   [r4, #884]                           @AVCPictureData *currPic = video->currPic;
    ldr        r7,   [r7, #48]                            @r7: int pitch = currPic->pitch;
    asr        r7,   r7,   #1
    
    mov        r8,   #16                                  @r8: int pred_pitch = 16;
    add        r9,   r4,   #512                           @r9: int16 *coef = video->block + 256;
    ldr        r10,  [r4,  #768]                          @r10: uint8 *pred = video->pred_block;
    
    cmp        r3,   #0
    addne      r9,   r9,   #16
    addne      r10,  r10,  #8
    
    ldr        r11,  [r5,  #156]                          @currMB->mb_intra
    cmp        r11,  #0
    moveq      r10,  r1
    moveq      r8,   r7
    
    VMOV.I8    Q4,   #0xff
    VSHL.U32   Q4,   Q4,   #16
    mov        r11,  #8
1:
    VLD1.8     {d0},  [r2],  r6
    VLD1.8     {d1},  [r10], r8
    
    VSUBL.U8   Q0,    d0,    d1                           @Q0:r3 r2 r1 r0 - r3 r2 r1 r0
    VSHR.U64   Q1,    Q0,    #32                          @Q1:xx xx r3 r2 - xx xx r3 r2
    VREV32.16  Q1,    Q1                                  @Q1:xx xx r2 r3 - xx xx r2 r3
    
    VADD.S16   Q2,    Q0,    Q1                           @Q2:xx xx r1 r0 - xx xx r1 r0
    VSUB.S16   Q0,    Q0,    Q1                           @Q0:xx xx r2 r3 - xx xx r2 r3
    VTRN.16    Q2,    Q0                                  @Q0:xx xx r2 r1 - xx xx r2 r1; Q2:xx xx r3 r0 - xx xx r3 r0
    
    VADD.S16   Q1,    Q2,    Q0                           @Q1:xx xx (r2+r3)(r0+r1) - xx xx (r2+r3)(r0+r1)
    VAND       Q3,    Q2,    Q4                           @Q3:xx xx r3 0 - xx xx r3 0
    VADD.S16   Q1,    Q1,    Q3                           @Q1:xx xx (r2+(r3<<1))(r0+r1) - xx xx (r2+(r3<<1))(r0+r1)
    
    VSUB.S16   Q2,    Q2,    Q0                           @Q2:xx xx (r3-r2)(r0-r1) - xx xx (r3-r2)(r0-r1)
    VAND       Q0,    Q0,    Q4                           @Q0:xx xx  r2     0      - xx xx  r2    0
    VSUB.S16   Q2,    Q2,    Q0                           @Q2:xx xx (r3-(r2<<1))(r0-r1) - xx xx (r3-(r2<<1))(r0-r1)
    
    VZIP.32    Q1,    Q2
    
    VST1.16    {d2},  [r9]!
    VST1.16    {d4},  [r9]!
    
    add        r9,    r9,    #16
    subs       r11,   r11,   #1
    bgt        1b
    
    
    sub        r10,   r10,   r8,  lsl #3
    sub        r9,    r9,    #256
    
    @@@@@@@@@@@@@@@@@@r2 is available@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    mov        r2,   #2
2:
    VLD1.16    {d0, d1},  [r9]                           @d0-d1: coef[0]
    add        r11,   r9,  #32
    VLD1.16    {d2, d3},  [r11]                          @d2-d3: coef[16]
    add        r12,   r11,  #32
    VLD1.16    {d4, d5},  [r12]                          @d4-d5: coef[32]
    add        lr,   r12,  #32
    VLD1.16    {d6, d7},  [lr]                           @d6-d7: coef[48]
    
    VADD.S16   Q4,   Q0,   Q3                            @Q4: r0
    VADD.S16   Q5,   Q1,   Q2                            @Q5: r1
    
    VADD.S16   Q6,   Q4,   Q5                            @Q6: (r0+r1)
    VST1.16    {d12, d13},  [r9]
    
    VSUB.S16   Q6,   Q4,   Q5                            @Q6: (r0-r1)
    VST1.16    {d12, d13},  [r12]
    
    
    VSUB.S16   Q4,   Q0,   Q3                            @Q4: r3
    VSUB.S16   Q5,   Q1,   Q2                            @Q5: r2
    
    VSHL.S16   Q6,   Q4,   #1                            @Q6:(r3 << 1)
    VADD.S16   Q6,   Q6,   Q5                            @Q6: (r3 << 1) + r2
    VST1.16    {d12, d13},  [r11]
    
    VSHL.S16   Q6,   Q5,   #1                            @Q6:(r2 << 1)
    VSUB.S16   Q6,   Q4,   Q6                            @Q6: r3 - (r2 << 1)
    VST1.16    {d12, d13},  [lr]
    
    add        r9,   r9,   #128
    subs       r2,   r2,   #1
    bgt        2b
    
    sub        r9,    r9,    #256
    ldrsh      r11,   [r9]
    ldrsh      r12,   [r9,  #128]
    VMOV       d0,    r11,   r12                         @d0: r2 r0
    ldrsh      r11,   [r9,  #8]
    ldrsh      r12,   [r9,  #136]
    VMOV       d1,    r11,   r12                         @d0: r3 r1
    
    VADD.S32   d2,    d0,   d1                           @d2: (r2+r3)(r0+r1)
    VSUB.S32   d0,    d0,   d1                           @d0: (r2-r3)(r0-r1)
    VTRN.32    d2,    d0                                 @d0: (r2-r3)(r2+r3); d2:(r0-r1)(r0+r1)
    
    VADD.S32   d1,    d0,   d2                           @d1: (r0-r1 + r2-r3) (r0+r1 + r2+r3)
    VSUB.S32   d0,    d2,   d0                           @d0: (r0-r1 - r2+r3) (r0+r1 - r2-r3)
    
    VMOV       r11,   r12,  d1
    strh       r11,   [r9]
    strh       r12,   [r9,  #8]
    VMOV       r11,   r12,  d0
    strh       r11,   [r9,  #128]
    strh       r12,   [r9,  #136]
    
    
    str        r5,    [sp]
    str        r6,    [sp,  #4]
    str        r7,    [sp,  #8]
    str        r8,    [sp,  #12]
    str        r10,   [sp,  #16]
    str        r1,    [sp,  #20]
    str        r3,    [sp,  #24]
    str        r0,    [sp,  #28]
    str        r4,    [sp,  #32]
    
    ldr        r2,    [r4,  #832]                       @r2: Rq    = video->QPc_mod_6;
    ldr        r5,    =quant_coef
    ldr        r2,    [r5,   r2,  lsl #6]               @r2: quant = quant_coef[Rq][0];
    ldr        r5,    [r4,  #828]                       @Qq
    str        r5,    [sp,  #36]                        @sp[9]:Qq
    add        r5,    r5,   #16                         @r5: q_bits+1;    q_bits= 15 + Qq;
    
    mov        r6,    #0                                @r6: zero_run = 0;
    mov        r7,    #0                                @r7: ncoeff = 0;
    add        r8,    r0,   #3232
    add        r8,    r8,   r3,  lsl #4                 @r8: level = encvid->levelcdc + (cr << 2);
    add        r10,   r8,   #64                         @r10: run = encvid->runcdc + (cr << 2);
    
    ldr        r1,    [r0,  #3376]                      @r1:qp_const = encvid->qp_const_c;
    
    mov        r11,   #0
3:
    asr        r12,   r11,  #1
    lsl        r12,   r12,  #6
    and        lr,    r11,  #1
    add        r12,   r12,  lr, lsl #2
    lsl        r12,   r12,  #1
    
    ldrsh      lr,    [r9,  r12]
    cmp        lr,    #0
    rsblt      lr,    lr,   #0
    
    mul        r3,    lr,   r2
    add        r3,    r3,   r1, lsl #1
    asr        r3,    r3,   r5
    
    cmp        r3,    #0
    beq        4f
    
    ldrsh      lr,    [r9,  r12]
    cmp        lr,    #0
    rsblt      r3,    r3,   #0
    
    str        r3,    [r8,  r7, lsl #2]
    strh       r3,    [r9,  r12]
    
    str        r6,    [r10, r7, lsl #2]
    add        r7,    r7,   #1
    mov        r6,    #0
    b          5f
    
4:
    add        r6,    r6,   #1
    strh       r3,    [r9,  r12]
    
5:
    add        r11,   r11,  #1
    cmp        r11,   #4
    blt        3b
    
    
    ldr        r3,    [sp,  #24]
    add        r11,   r0,   #3360
    str        r7,    [r11, r3, lsl #2]
    
    cmp        r7,    #0
    beq        6f
    
    ldr        r2,    [sp]
    ldr        r11,   [r2, #184]
    orr        r11,   r11,   #16
    str        r11,   [r2, #184]
    
    ldr        r2,    [r4,  #832]                       @r2: Rq    = video->QPc_mod_6;
    ldr        r11,   =dequant_coefres
    ldr        r2,    [r11,   r2,  lsl #6]
    VDUP.32    Q0,    r2                                @Q0: quant quant quant quant
    
    ldrsh      r11,   [r9]
    ldrsh      r12,   [r9,  #128]
    VMOV       d2,    r11,   r12                        @d2:coef[64] coef[0]
    ldrsh      r11,   [r9,  #8]
    ldrsh      r12,   [r9,  #136]
    VMOV       d3,    r11,   r12                        @d3:coef[68] coef[4]
    
    VADD.S32   d4,    d2,    d3                         @d4: r2 r0
    VSUB.S32   d3,    d2,    d3                         @d3: r3 r1
    VTRN.32    d4,    d3                                @d3: r3 r2; d4:r1 r0
    
    VADD.S32   d2,    d4,    d3                         @d2: r1 r0
    VSUB.S32   d3,    d4,    d3                         @d3: r3 r2
    
    ldr        r2,    [r4,  #828]                       @Qq
    cmp        r2,    #1
    subge      r2,    r2,    #1
    movlt      r2,    #-1
    
    VDUP.32    Q2,    r2                                @Q2: Qq Qq Qq Qq
    
    VMUL.S32   Q0,    Q0,    Q1
    VSHL.S32   Q0,    Q0,    Q2
    
    VMOV       r11,   r12,   d0
    strh       r11,   [r9]
    strh       r12,   [r9,  #8]
    VMOV       r11,   r12,   d1
    strh       r11,   [r9,  #128]
    strh       r12,   [r9,  #136]
    
6:
    cmp        r3,    #0
    addeq      r8,    r0,   #1056                       @r8: level = encvid->level[16];
    addeq      r10,   r0,   #2592                       @r10: run = encvid->run[16];
    addne      r8,    r0,   #1312                       @r8: level = encvid->level[20];
    addne      r10,   r0,   #2848                       @r10: run = encvid->run[20];
    
    @@@@@@@@@@r1:qp_const = encvid->qp_const_c; r2, r3, r6, r7, r11,r12,lr free@@@@@@@@@@@@
    sub        r5,    r5,   #1                          @r5: q_bits;
    ldr        r0,    [r4,  #832]                       @r0: Rq
    
    mov        r2,    #0                                @r2: coeff_cost = 0;
    str        r2,    [sp,  #40]                        @sp[10]: b4
7:
    mov        r6,    #0                                @r6: zero_run = 0;
    mov        r7,    #0                                @r7: ncoeff = 0;
    
    mov        r4,    #1                                @r4: k
8:
    ldr        r11,   =ZZ_SCAN_BLOCK
    ldrb       r11,   [r11,  r4]
    lsl        r11,   r11,   #1                         @idx
    
    ldr        r12,   =quant_coef
    add        lr,    r4,    r0,  lsl #4
    ldr        r12,   [r12,  lr, lsl #2]
    
    ldrsh      lr,    [r9,   r11]
    cmp        lr,    #0
    rsblt      lr,    lr,    #0
    
    mul        r3,    lr,    r12
    add        r3,    r3,    r1
    asr        r3,    r3,    r5
    
    cmp        r3,    #0
    beq        9f
    
    cmp        r3,    #1
    ldr        lr,    =COEFF_COST
    ldrb       lr,    [lr,   r6]
    ldrgt      lr,    =999999
    add        r2,    r2,    lr
    
    ldr        r12,   =dequant_coefres
    add        lr,    r4,    r0,  lsl #4
    ldr        r12,   [r12,  lr, lsl #2]
    
    ldrsh      lr,    [r9,   r11]
    cmp        lr,    #0
    rsblt      r3,    r3,    #0
    
    str        r3,    [r8,   r7, lsl #2]
    mul        lr,    r3,    r12
    ldr        r3,    [sp,   #36]
    lsl        lr,    lr,    r3
    strh       lr,    [r9,   r11]
    
    str        r6,    [r10,  r7, lsl #2]
    add        r7,    r7,    #1
    mov        r6,    #0
    b          10f
    
9:
    add        r6,    r6,    #1
    strh       r3,    [r9,   r11]
    
10:
    add        r4,    r4,    #1
    cmp        r4,    #16
    blt        8b
    
    ldr        r4,    [sp,   #40]                         @load b4
    ands       r11,   r4,    #1
    addne      r9,    r9,    #112
    
    add        r9,    r9,    #8
    add        r8,    r8,    #64
    add        r10,   r10,   #64
    
    add        r11,   r4,    #11
    str        r7,    [sp,   r11, lsl #2]                 @nz_temp[b4] = ncoeff;
    
    add        r4,    r4,    #1
    str        r4,    [sp,   #40]
    cmp        r4,    #4
    blt        7b
    
    
    sub        r9,    r9,    #256
    
    
    ldr        r3,    [sp,  #24]                          @r3: cr
    ldr        r5,    [sp]                                @r5: currMB
    ldr        r7,    [sp,  #8]                           @r7: pitch
    ldr        r8,    [sp,  #12]                          @r8: pred_pitch
    ldr        r1,    [sp,  #20]                          @r1: curC
    ldr        r10,   [sp,  #16]                          @r10:pred
    
    VMOV.U8    Q5,   #0xff
    VMOV.U32   Q6,   #0xff
    
    @@@@@@@@@@@@@@@@@@@@@@r0, r2 r4, r6, r11, r12, lr are available@@@@@@@@@@@@@@@@@@@@@
    cmp        r2,    #4
    bge        13f
    
    mov        r0,    #0
    add        r5,    r5,   #380                          @r5: currMB->nz_coeff
    lsl        r3,    r3,   #1
    add        r2,    r3,   #16
    strb       r0,    [r5,  r2]
    add        r2,    r3,   #17
    strb       r0,    [r5,  r2]
    add        r2,    r3,   #20
    strb       r0,    [r5,  r2]
    add        r2,    r3,   #21
    strb       r0,    [r5,  r2]
    
    @@@@@@@@@@@@@@take r0 as b4,  do not set it again @@@@@@@@@@@@@@@@@@
11:
    ldrsh      r2,    [r9]
    add        r2,    r2,   #32
    asr        r2,    r2,   #6
    VDUP.32    Q0,    r2                                  @Q0: m0>>6
    
    mov        r4,    r1
    mov        r6,    r10
    mov        r2,    #4
12:
    VLD1.8     {d2},  [r6], r8
    VMOVL.U8   Q1,    d2                                  @d2:pred[0] pred[0] pred[0] pred[0]
    
    VADDW.U16  Q1,   Q0,  d2
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r4]
    strb       r12,  [r4, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r4, #2]
    strb       r12,  [r4, #3]
    
    add        r4,   r4,   r7
    subs       r2,   r2,   #1
    bgt        12b
    
    add        r1,   r1,   #4
    add        r10,  r10,  #4
    add        r9,   r9,   #8
    
    tst        r0,   #1
    addne      r9,   r9,   #112
    addne      r1,   r1,   r7,  lsl #2
    subne      r1,   r1,   #8
    addne      r10,  r10,  r8,  lsl #2
    subne      r10,  r10,  #8
    
    add        r0,   r0,   #1
    cmp        r0,   #4
    blt        11b
    
    b          19f
    
13:
    add        r0,   sp,   #44
    mov        r2,   #0
14:
    ldr        r4,   [r0,  r2, lsl #2]
    
    and        r6,   r2,   #1
    add        r6,   r6,   #16
    add        r6,   r6,   r3,  lsl #1
    asr        r11,  r2,   #1
    add        r6,   r6,   r11, lsl #2
    
    add        r11,   r5,   #380
    strb       r4,   [r11, r6]
    
    cmp        r4,   #0
    beq        16f
    
    ldr        r4,   [r5, #184]
    orr        r4,   r4,  #32
    str        r4,   [r5, #184]                          @currMB->CBP |= (2 << 4);
    
    mov        r12,   #32
    mov        r11,   #4
15:
    VLD1.16    {d0},  [r9]                               @d0: coef[3]coef[2]coef[1]coef[0]
    VMOVL.S16  Q1,   d0                                  @d2: coef[1]coef[0]; d3:coef[3]coef[2]
    
    VTRN.16    d0,   d1                                  @d0: xx coef[2] xx coef[0]; d1: xx coef[3] xx coef[1]
    VSHR.S16   d1,   d1,    #1
    VTRN.16    d0,   d1                                  @d0: (coef[3]>>1)coef[2](coef[1]>>1)coef[0]
    VMOVL.S16  Q0,   d0                                  @d0: (coef[1]>>1)coef[0]; d1: (coef[3]>>1)coef[2]
    
    VADD.S32   d2,   d2,    d1                           @d2: r3 r0 ((coef[3]>>1)+coef[1])(coef[2]+coef[0])
    VSUB.S32   d3,   d0,    d3                           @d3: r2 r1 ((coef[1]>>1)-coef[3])(coef[0]-coef[2])
    
    VTRN.32    d2,   d3                                  @d2: r1 r0; d3:r2 r3
    VADD.S32   d0,   d2,    d3                           @d0: (r1+r2)(r0+r3)
    VSUB.S32   d1,   d2,    d3                           @d1: (r1-r2)(r0-r3)
    
    VREV64.32  d1,   d1
    VUZP.16    d0,   d1
    
    VST1.16    {d0}, [r9], r12
    
    subs       r11,   r11,   #1
    bgt        15b
    
    
    sub        r9,   r9,   #128
    VLD1.16    {d0},   [r9]                                @d0: coef[0]
    add        r11,  r9,  #32
    VLD1.16    {d2},   [r11]                               @d2: coef[16]
    add        r11,  r11,  #32
    VLD1.16    {d1},   [r11]                               @d1: coef[32]
    add        r11,  r11,  #32
    VLD1.16    {d3},   [r11]                               @d3: coef[48]
    
    VADDL.S16  Q2,   d0,  d1                              @Q2: r0 r0 r0 r0
    VSUBL.S16  Q3,   d0,  d1                              @Q3: r1 r1 r1 r1
    
    VSHR.S16   Q4,   Q1,  #1                              @d9: (coef[48]>>1)  d8: (coef[16]>>1)
    
    VSUBL.S16  Q7,   d8,  d3                              @Q7: r2 r2 r2 r2
    VADDL.S16  Q8,   d9,  d2                              @Q8: r3 r3 r3 r3
    
    VADD.S32   Q0,   Q2,  Q8                              @Q0: r0 r0 r0 r0
    VSUB.S32   Q1,   Q2,  Q8                              @Q1: r3 r3 r3 r3
    VADD.S32   Q2,   Q3,  Q7                              @Q2: r1 r1 r1 r1
    VSUB.S32   Q3,   Q3,  Q7                              @Q3: r2 r2 r2 r2
    
    VMOV.S32   Q4,   #32
    VADD.S32   Q0,   Q0,  Q4
    VADD.S32   Q1,   Q1,  Q4
    VADD.S32   Q2,   Q2,  Q4
    VADD.S32   Q3,   Q3,  Q4
    
    VSHR.S32   Q0,   Q0,  #6
    VSHR.S32   Q1,   Q1,  #6
    VSHR.S32   Q2,   Q2,  #6
    VSHR.S32   Q3,   Q3,  #6
    
    
    VLD1.8     {d8},  [r10], r8
    VMOVL.U8   Q4,   d8                                   @d8:pred[0]pred[0]pred[0]pred[0]
    
    VADDW.U16  Q0,   Q0,  d8
    VCGT.U32   Q7,   Q0,  Q6
    VSHR.S32   Q8,   Q0,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q0,   Q8,  Q7
    
    VMOV       r11,  r12, d0
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d1
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,   r7
    VLD1.8     {d8},  [r10], r8
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q2,   Q2,  d8
    VCGT.U32   Q7,   Q2,  Q6
    VSHR.S32   Q8,   Q2,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q2,   Q8,  Q7
    
    VMOV       r11,  r12, d4
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d5
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    
    add        r1,   r1,   r7
    VLD1.8     {d8},  [r10], r8
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q3,   Q3,  d8
    VCGT.U32   Q7,   Q3,  Q6
    VSHR.S32   Q8,   Q3,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q3,   Q8,  Q7
    
    VMOV       r11,  r12, d6
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d7
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    
    add        r1,   r1,   r7
    VLD1.8     {d8},  [r10], r8
    VMOVL.U8   Q4,   d8                                   @d8:cur[0]cur[0]cur[0]cur[0]
    
    VADDW.U16  Q1,   Q1,  d8
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,   r7
    b          18f
    
16:
    ldrsh      r11,   [r9]
    add        r11,   r11,   #32
    asr        r11,   r11,   #6
    VDUP.32    Q0,    r11                                 @Q0: m0>>6
    
    mov        r4,   #4
17:
    VLD1.8     {d2},  [r10], r8
    VMOVL.U8   Q1,    d2                                  @d2:pred[0] pred[0] pred[0] pred[0]
    
    VADDW.U16  Q1,   Q0,  d2
    VCGT.U32   Q7,   Q1,  Q6
    VSHR.S32   Q8,   Q1,  #31
    VEOR       Q8,   Q8,  Q5
    VBIT.32    Q1,   Q8,  Q7
    
    VMOV       r11,  r12, d2
    strb       r11,  [r1]
    strb       r12,  [r1, #1]
    VMOV       r11,  r12, d3
    strb       r11,  [r1, #2]
    strb       r12,  [r1, #3]
    
    add        r1,   r1,   r7
    subs       r4,   r4,   #1
    bgt        17b
    
18:
    add        r9,   r9,   #8
    
    tst        r2,   #1
    addne      r9,   r9,   #112
    subeq      r1,   r1,   r7,  lsl #2
    addeq      r1,   r1,   #4
    subne      r1,   r1,   #4
    subeq      r10,  r10,  r8,  lsl #2
    addeq      r10,  r10,  #4
    subne      r10,  r10,  #4
    
    add        r2,   r2,   #1
    cmp        r2,   #4
    blt        14b
    
19:
    add        sp,  sp,  #60
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |dct_chroma|
    .end
