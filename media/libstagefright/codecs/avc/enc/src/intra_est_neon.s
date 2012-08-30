@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@   intra_est.cpp for neon optimization of h264 encoder
@   author: zefeng.tong@amlogic.com
@   date:   2011-07-18
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  cost_i16
cost_i16:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
    sub        sp,   sp,  #512                            @allocate int16 res[256] at stack
    
    mov        r4,   sp                                   @r4: pointer to res[0]
    
    mov        r5,   #16                                  @r5: j
1:
    VLD1.8     {d0,  d1},  [r0], r1
    VLD1.8     {d2,  d3},  [r2]!
    
    VSUBL.U8   Q2,   d0,   d2                             @Q2:m3 m2 m1 m0..m3 m2 m1 m0
    VSUBL.U8   Q3,   d1,   d3                             @Q3:m3 m2 m1 m0..m3 m2 m1 m0
    
    VSHR.U64   Q0,   Q2,   #32                            @Q0:x  x  m3 m2...
    VSHR.U64   Q1,   Q3,   #32                            @Q1:x  x  m3 m2...
    VREV32.16  Q0,   Q0                                   @Q0:x  x  m2 m3...
    VREV32.16  Q1,   Q1                                   @Q1:x  x  m2 m3...
    
    VADD.S16   Q4,   Q2,   Q0                             @Q4: xx  xx (m1+m2)(m0+m3) ...
    VADD.S16   Q5,   Q3,   Q1                             @Q5: xx  xx m1 m0
    VSUB.S16   Q6,   Q2,   Q0                             @Q6: xx  xx (m1-m2)(m0-m3) ...
    VSUB.S16   Q7,   Q3,   Q1                             @Q7: xx  xx m2 m3
    
    VTRN.16    Q4,   Q0                                   @Q0: xx  xx xx m1 ...;Q4:xx xx xx m0 ...
    VTRN.16    Q5,   Q1                                   @Q1: xx  xx xx m1 ...;Q5:xx xx xx m0 ...
    VADD.S16   Q2,   Q4,   Q0                             @Q2: xx  xx xx m0+m1 xx xx xx m0+m1
    VSUB.S16   Q0,   Q4,   Q0                             @Q0: xx  xx xx m0-m1 xx xx xx m0-m1
    VADD.S16   Q3,   Q5,   Q1                             @Q3: xx  xx xx m0+m1 xx xx xx m0+m1
    VSUB.S16   Q1,   Q5,   Q1                             @Q1: xx  xx xx m0-m1 xx xx xx m0-m1
    
    VTRN.16    Q6,   Q4                                   @Q4: xx  xx xx m2 ...;Q6:xx xx xx m3 ...
    VTRN.16    Q7,   Q5                                   @Q5: xx  xx xx m2 ...;Q7:xx xx xx m3 ...
    VADD.S16   Q8,   Q6,   Q4                             @Q8: xx  xx xx m3+m2 xx xx xx m3+m2
    VSUB.S16   Q9,   Q6,   Q4                             @Q9: xx  xx xx m3-m2 xx xx xx m3-m2
    VADD.S16   Q4,   Q7,   Q5                             @Q4: xx  xx xx m3+m2 xx xx xx m3+m2
    VSUB.S16   Q5,   Q7,   Q5                             @Q5: xx  xx xx m3-m2 xx xx xx m3-m2
    
    VZIP.16    Q2,   Q8                                   @Q2,Q8: ...m3+m2 m0+m1
    VZIP.16    Q3,   Q4                                   @Q3,Q4: ...m3+m2 m0+m1
    VZIP.16    Q0,   Q9                                   @Q0,Q9: ...m3-m2 m0-m1
    VZIP.16    Q1,   Q5                                   @Q1,Q5: ...m3-m2 m0-m1
    
    VZIP.32    d4,   d0                                   @d4: m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d16,  d18                                  @d16: m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d6,   d2                                   @d6:  m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d8,  d10                                   @d8: m3-m2 m0-m1 m3+m2 m0+m1
    
    VST1.16    {d4}, [r4]!
    VST1.16    {d16}, [r4]!
    VST1.16    {d6}, [r4]!
    VST1.16    {d8}, [r4]!
    
    subs       r5,   r5,  #1
    bgt        1b
    
    sub        r4,   sp,  #128
    VMOV.U32   d31,  #0
    mov        r5,   #4
2:
    add        r4,   r4,  #128
    
    @VLD1.16    {d0,d1,d2,d3},  [r4]                       @Q0,Q1:m0; Q2,Q3:m1; Q4,Q5:m2; Q6,Q7:m3
    @add        r7,   r4,  #32
    @VLD1.16    {d4,d5,d6,d7},  [r7]
    @add        r7,   r7,  #32
    @VLD1.16    {d8,d9,d10,d11},  [r7]
    @add        r7,   r7,  #32
    @VLD1.16    {d12,d13,d14,d15},  [r7]
    VLDMIA      r4,  {d0 - d15}
    
    VADD.S16   Q8,  Q0,  Q6
    VADD.S16   Q9,  Q1,  Q7                               @Q8,Q9: m0 (m0+m3)
    VSUB.S16   Q0,  Q0,  Q6
    VSUB.S16   Q1,  Q1,  Q7                               @Q0,Q1: m3 (m0-m3)
    
    VADD.S16   Q6,  Q2,  Q4
    VADD.S16   Q7,  Q3,  Q5                               @Q6,Q7: m1 (m1+m2)
    VSUB.S16   Q2,  Q2,  Q4
    VSUB.S16   Q3,  Q3,  Q5                               @Q2,Q3: m2 (m1-m2)
    
    VADD.S16   Q4,  Q8,  Q6
    VADD.S16   Q5,  Q9,  Q7                               @Q4,Q5: m0
    VST1.16    {d8, d9, d10, d11}, [r4]
    
    VSHR.U64   Q10, Q4, #16
    VABS.S16   Q10, Q10
    VADDL.U16  Q10, d20,  d21
    VADD.U32   d20, d20,  d21
    VADD.U32   d31, d20,  d31
    
    VSHR.U64   Q10, Q5, #16
    VABS.S16   Q10, Q10
    VADDL.U16  Q10, d20,  d21
    VADD.U32   d20, d20,  d21
    VADD.U32   d31, d20,  d31
    
    VABD.S16   Q4,  Q8,  Q6
    VABD.S16   Q5,  Q9,  Q7                               @Q4,Q5: m1
    
    VADDL.U16  Q4, d8,  d9
    VADDL.U16  Q5, d10, d11
    VADD.U32   Q4, Q4,  Q5
    VADD.U32   d8, d8,  d9
    VADD.U32   d31,d8,  d31
    
    
    VADD.S16   Q4,  Q0,  Q2
    VADD.S16   Q5,  Q1,  Q3                               @Q4,Q5: m3
    
    VABS.S16   Q4, Q4
    VABS.S16   Q5, Q5
    VADDL.U16  Q4, d8,  d9
    VADDL.U16  Q5, d10, d11
    VADD.U32   Q4, Q4,  Q5
    VADD.U32   d8, d8,  d9
    VADD.U32   d31,d8,  d31
    
    VABD.S16   Q4,  Q0,  Q2
    VABD.S16   Q5,  Q1,  Q3                               @Q4,Q5: m2
    
    VADDL.U16  Q4, d8,  d9
    VADDL.U16  Q5, d10, d11
    VADD.U32   Q4, Q4,  Q5
    VADD.U32   d8, d8,  d9
    VADD.U32   d31,d8,  d31
    
    VPADDL.U32 d31, d31
    VMOV.U32   r6,  d31[0]
    lsr        r6,  r6,  #1
    
    cmp        r6,  r3
    ble        3f
    b          7f
3:
    subs       r5,  r5,  #1
    bgt        2b
    
    
    mov        r4,   sp
    mov        r5,   #4
4:
    ldrsh      r6,   [r4]
    ldrsh      r7,   [r4,  #8]                            @r6: m0; r7: m1
    ldrsh      r8,   [r4,  #24]
    ldrsh      r9,   [r4,  #16]                           @r8: m3; r9: m2
    
    asr        r6,   r6,  #2
    add        r6,   r6,  r8,  asr #2                     @r6:  m0
    sub        r8,   r6,  r8,  asr #1                     @r8:  m3
    
    asr        r7,   r7,  #2
    add        r7,   r7,  r9,  asr #2                     @r7:  m1
    sub        r9,   r7,  r9,  asr #1                     @r9:  m2
    
    add        r10,  r6,  r7
    strh       r10,  [r4]
    sub        r10,  r6,  r7
    strh       r10,  [r4, #16]
    add        r10,  r8,  r9
    strh       r10,  [r4, #8]
    sub        r10,  r8,  r9
    strh       r10,  [r4, #24]
    
    add        r4,   r4,  #128
    subs       r5,   r5,  #1
    bgt        4b
    
    mov        r8,   #384
    mov        r9,   #256
    mov        r4,   sp
    mov        r5,   #4
5:
    ldrsh      r6,   [r4]
    ldrsh      r7,   [r4,  #128]
    VMOV       d0,   r6,  r7                              @d0: m1 m0
    ldrsh      r6,   [r4,  r8]
    ldrsh      r7,   [r4,  r9]
    VMOV       d1,   r6,  r7                              @d1: m2 m3
    
    VADD.S32   d2,   d0,  d1                              @d2: m1 m0
    VSUB.S32   d3,   d0,  d1                              @d3: m2 m3
    
    VZIP.32    d2,   d3                                   @d2: m3 m0; d3:m2 m1
    VADD.S32   d0,   d2,  d3                              @d0: m2+m3 m0+m1
    VSUB.S32   d1,   d2,  d3                              @d1: m3-m2 m0-m1
    VABS.S32   Q0,   Q0
    VADD.U32   d0,   d0,  d1
    VADD.U32   d31,  d0,  d31
    VPADDL.U32 d31,  d31
    
    VMOV.U32   r6,   d31[0]
    lsr        r6,   r6,  #1
    cmp        r6,   r3
    ble        6f
    b          7f
6:
    add        r4,   r4,  #8
    subs       r5,   r5,  #1
    bgt        5b
    
7:
    VMOV.U32   r6,   d31[0]
    lsr        r6,   r6,  #1
    mov        r0,   r6
    add        sp,   sp,  #512
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |cost_i16|
    
    
    .section .text
    .global  cost_i4
cost_i4:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
    VLD1.8     {d0},  [r0], r1
    VLD1.8     {d2},  [r0], r1
    VLD1.8     {d1},  [r0], r1
    VLD1.8     {d3},  [r0]
    VZIP.32    d0,   d2                                  @d0: 3 2 1 0 - 3 2 1 0
    VZIP.32    d1,   d3                                  @d1: 3 2 1 0 - 3 2 1 0
    VLD1.8     {d2,  d3},  [r2]
    
    VSUBL.U8   Q2,   d0,   d2                             @Q2:m3 m2 m1 m0..m3 m2 m1 m0
    VSUBL.U8   Q3,   d1,   d3                             @Q3:m3 m2 m1 m0..m3 m2 m1 m0
    
    VSHR.U64   Q0,   Q2,   #32                            @Q0:x  x  m3 m2...
    VSHR.U64   Q1,   Q3,   #32                            @Q1:x  x  m3 m2...
    VREV32.16  Q0,   Q0                                   @Q0:x  x  m2 m3...
    VREV32.16  Q1,   Q1                                   @Q1:x  x  m2 m3...
    
    VADD.S16   Q4,   Q2,   Q0                             @Q4: xx  xx (m1+m2)(m0+m3) ...
    VADD.S16   Q5,   Q3,   Q1                             @Q5: xx  xx m1 m0
    VSUB.S16   Q6,   Q2,   Q0                             @Q6: xx  xx (m1-m2)(m0-m3) ...
    VSUB.S16   Q7,   Q3,   Q1                             @Q7: xx  xx m2 m3
    
    VTRN.16    Q4,   Q0                                   @Q0: xx  xx xx m1 ...;Q4:xx xx xx m0 ...
    VTRN.16    Q5,   Q1                                   @Q1: xx  xx xx m1 ...;Q5:xx xx xx m0 ...
    VADD.S16   Q2,   Q4,   Q0                             @Q2: xx  xx xx m0+m1 xx xx xx m0+m1
    VSUB.S16   Q0,   Q4,   Q0                             @Q0: xx  xx xx m0-m1 xx xx xx m0-m1
    VADD.S16   Q3,   Q5,   Q1                             @Q3: xx  xx xx m0+m1 xx xx xx m0+m1
    VSUB.S16   Q1,   Q5,   Q1                             @Q1: xx  xx xx m0-m1 xx xx xx m0-m1
    
    VTRN.16    Q6,   Q4                                   @Q4: xx  xx xx m2 ...;Q6:xx xx xx m3 ...
    VTRN.16    Q7,   Q5                                   @Q5: xx  xx xx m2 ...;Q7:xx xx xx m3 ...
    VADD.S16   Q8,   Q6,   Q4                             @Q8: xx  xx xx m3+m2 xx xx xx m3+m2
    VSUB.S16   Q9,   Q6,   Q4                             @Q9: xx  xx xx m3-m2 xx xx xx m3-m2
    VADD.S16   Q4,   Q7,   Q5                             @Q4: xx  xx xx m3+m2 xx xx xx m3+m2
    VSUB.S16   Q5,   Q7,   Q5                             @Q5: xx  xx xx m3-m2 xx xx xx m3-m2
    
    VZIP.16    Q2,   Q8                                   @Q2,Q8: ...m3+m2 m0+m1
    VZIP.16    Q3,   Q4                                   @Q3,Q4: ...m3+m2 m0+m1
    VZIP.16    Q0,   Q9                                   @Q0,Q9: ...m3-m2 m0-m1
    VZIP.16    Q1,   Q5                                   @Q1,Q5: ...m3-m2 m0-m1
    
    VZIP.32    d4,   d0                                   @d12: m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d16,  d18                                  @d16: m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d6,   d2                                   @d6:  m3-m2 m0-m1 m3+m2 m0+m1
    VZIP.32    d8,  d10                                   @d8: m3-m2 m0-m1 m3+m2 m0+m1
        
    
    VADD.S16   d0,  d4,   d8                              @d0: m0
    VSUB.S16   d1,  d4,   d8                              @d1: m3
    VADD.S16   d2,  d16,  d6                              @d2: m1
    VSUB.S16   d3,  d16,  d6                              @d3: m2
    
    VADD.S16   Q2,  Q0,  Q1                               @Q2: (m3+m2)(m3+m2)(m3+m2)(m3+m2)(m0+m1)(m0+m1)(m0+m1)(m0+m1)
    VABD.S16   Q0,  Q0,  Q1                               @Q0: (m3-m2)(m3-m2)(m3-m2)(m3-m2)(m0-m1)(m0-m1)(m0-m1)(m0-m1)
    VABS.S16   Q1,  Q2
    
    VADDL.U16  Q0,  d0,  d1
    VADDL.U16  Q1,  d2,  d3
    VADD.U32   Q0,  Q0,  Q1
    VADD.U32   d0,  d0,  d1
    VPADDL.U32 d0,  d0
    
    VMOV.U32   r5,  d0[0]
    
    add        r5,  r5,  #1
    lsr        r5,  r5,  #1
    
    ldrh       r4,  [r3]
    add        r4,  r4,  r5
    strh       r4,  [r3]
    
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |cost_i4|
    
    
    .section .text
    .global  SATDChroma
SATDChroma:
    stmdb      sp!, {r4 - r7, r11, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)min_cost, lr, r11, r7-r4(lowend)@@@@@@@@@@@@@@@@
    mov        fp,   sp
    sub        sp,   fp,  #256                            @allocate int16 res[128]
    
    mov        r4,   sp
    mov        r5,   #8
1:
    VLD1.8     {d0},   [r0],  r2
    VLD1.8     {d1},   [r3]!
    VSUBL.U8   Q0,   d0,   d1                             @Q0: m3 m2 m1 m0 - m3 m2 m1 m0
    VSHR.U64   Q1,   Q0,   #32                            @Q1: xx xx m3 m2 - xx xx m3 m2
    VREV32.16  Q1,   Q1                                   @Q1: xx xx m2 m3 - xx xx m2 m3
    
    VADD.S16   Q2,   Q0,   Q1                             @Q2: xx xx (m1)(m0) - xx xx (m1+m2)(m0+m3)
    VSUB.S16   Q3,   Q0,   Q1                             @Q3: xx xx (m2)(m3) - xx xx (m1-m2)(m0-m3)
    
    VTRN.S16   Q2,   Q3                                   @Q2: xx xx m3 m0;  Q3:xx xx m2 m1
    VADD.S16   Q0,   Q2,   Q3                             @Q0: xx xx pres[1]pres[0]
    VSUB.S16   Q1,   Q2,   Q3                             @Q1: xx xx pres[3]pres[2]
    
    VZIP.32    Q0,   Q1                                   @Q0: pres[3]pres[2]pres[1]pres[0]
    VMOV       d1,   d2
    VST1.16    {d0, d1},   [r4]!
    
    
    VLD1.8     {d0},   [r1],  r2
    VLD1.8     {d1},   [r3]!
    VSUBL.U8   Q0,   d0,   d1                             @Q0: m3 m2 m1 m0 - m3 m2 m1 m0
    VSHR.U64   Q1,   Q0,   #32                            @Q1: xx xx m3 m2 - xx xx m3 m2
    VREV32.16  Q1,   Q1                                   @Q1: xx xx m2 m3 - xx xx m2 m3
    
    VADD.S16   Q2,   Q0,   Q1                             @Q2: xx xx (m1)(m0) - xx xx (m1+m2)(m0+m3)
    VSUB.S16   Q3,   Q0,   Q1                             @Q3: xx xx (m2)(m3) - xx xx (m1-m2)(m0-m3)
    
    VTRN.S16   Q2,   Q3                                   @Q2: xx xx m3 m0;  Q3:xx xx m2 m1
    VADD.S16   Q0,   Q2,   Q3                             @Q0: xx xx pres[1]pres[0]
    VSUB.S16   Q1,   Q2,   Q3                             @Q1: xx xx pres[3]pres[2]
    
    VZIP.32    Q0,   Q1                                   @Q0: pres[3]pres[2]pres[1]pres[0]
    VMOV       d1,   d2
    VST1.16    {d0, d1},   [r4]!
    
    subs       r5,   r5,   #1
    bgt        1b
    
    mov        r4,   sp
    mov        r5,   #2
2:
    VLDMIA     r4,   {d0 - d15}                           @Q0,Q1:m0; Q2,Q3:m1; Q4,Q5:m2; Q6,Q7:m3
    
    VADD.S16   Q8,  Q0,  Q6
    VADD.S16   Q9,  Q1,  Q7                               @Q8,Q9: m0 (m0+m3)
    VSUB.S16   Q0,  Q0,  Q6
    VSUB.S16   Q1,  Q1,  Q7                               @Q0,Q1: m3 (m0-m3)
    
    VADD.S16   Q6,  Q2,  Q4
    VADD.S16   Q7,  Q3,  Q5                               @Q6,Q7: m1 (m1+m2)
    VSUB.S16   Q2,  Q2,  Q4
    VSUB.S16   Q3,  Q3,  Q5                               @Q2,Q3: m2 (m1-m2)
    
    VADD.S16   Q4,  Q8,  Q6
    VADD.S16   Q5,  Q9,  Q7                               @Q4,Q5: m0
    VST1.16    {d8, d9, d10, d11}, [r4]!
    
    VADD.S16   Q4,  Q0,  Q2
    VADD.S16   Q5,  Q1,  Q3                               @Q4,Q5: m3
    VST1.16    {d8, d9, d10, d11}, [r4]!
    
    VSUB.S16   Q4,  Q8,  Q6
    VSUB.S16   Q5,  Q9,  Q7                               @Q4,Q5: m1
    VST1.16    {d8, d9, d10, d11}, [r4]!
    
    VSUB.S16   Q4,  Q0,  Q2
    VSUB.S16   Q5,  Q1,  Q3                               @Q4,Q5: m2
    VST1.16    {d8, d9, d10, d11}, [r4]!
    
    subs       r5,   r5,   #1
    bgt        2b
    
    VMOV.U32   d2,   #0
    ldr        r6,   [fp,  #24]
    mov        r4,   sp
    mov        r5,   #128
3:
    VLD1.16    {d0,  d1},  [r4]!
    
    VABS.S16   Q0,   Q0
    VADDL.U16  Q0,   d0,   d1
    VADD.U32   d0,   d0,   d1
    VADD.U32   d2,   d0,   d2
    VPADDL.U32 d2,   d2
    VMOV.U32   r7,   d2[0]
    
    cmp        r7,   r6
    ble        4f
    b          5f
4:
    subs       r5,   r5,  #8
    bgt        3b
5:
    mov        r0,   r7
    mov        sp,   fp
    ldmia      sp!, {r4 - r7, r11, pc}
    @ENDP  @ |SATDChroma|

    
    .section .text
    @.global  IntraDecisionABE
IntraDecisionABE:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
    ldr        r4,  [r0, #0]                             @AVCCommonObj *video = encvid->common;
    ldr        r5,  [r4, #920]                           @video->mb_x
    ldr        r7,  [r4, #1248]                          @video->PicWidthInMbs
    sub        r7,  r7,  #1
    
    cmp        r5,  r7
    beq        4f
    
    ldr        r6,  [r4, #924]                           @video->mb_y
    ldr        r8,  [r4, #1296]                          @video->PicHeightInMbs
    sub        r8,  r8,  #1
    
    cmp        r6,  r8
    beq        4f
    
    ldr        r7,  [r4, #1220]                          @video->intraAvailA
    cmp        r7,  #0
    beq        4f
    
    ldr        r7,  [r4, #1224]                          @video->intraAvailB
    cmp        r7,  #0
    beq        4f
    
    lsl        r5,  r5,  #4                              @r5: int x_pos = (video->mb_x) << 4;
    lsl        r6,  r6,  #4                              @r6: int y_pos = (video->mb_y) << 4;
    
    ldr        r7,  [r0, #24]                            @r7: AVCFrameIO *currInput = encvid->currInput;
    ldr        r8,  [r7, #16]                            @r8: int orgPitch = currInput->pitch;
    ldr        r9,  [r7, #4]                             @r9: currInput->YCbCr[0] 
    mla        r9,  r6,  r8,  r9
    add        r9,  r9,  r5                              @r9: orgY
    
    sub        r10, r2,  r3                              @r10:topL = curL - picPitch;
    sub        r11, r2,  #1                              @r11:leftL = curL - 1;
    sub        r12, r9,  r8                              @r12:orgY_2 = orgY - orgPitch;
    
    VMOV.I16   Q2,  #0
    
    VLD1.8     {d0, d1}, [r10]
    VLD1.8     {d2, d3}, [r9]
    
    VABAL.U8   Q2,  d0,  d2
    VABAL.U8   Q2,  d1,  d3
    
    VMOV.I32   Q0,  #0
    VMOV.I32   Q1,  #0                                   @set 0
    mov        r7,  #16
1:
    ldrb       r9,  [r11, r3]!
    ldrb       r10, [r12, r8]!
    VMOV.U32   d0[0],  r9
    VMOV.U32   d2[0],  r10
    VABA.U16   Q2,  Q0, Q1
    
    subs       r7,  r7,  #1
    bgt        1b
    
    lsr        r6,  r6,  #2
    lsr        r5,  r5,  #1
    mla        r5,  r6,  r3,  r5                         @r5:offset = (y_pos >> 2) * picPitch + (x_pos >> 1);
    
    ldr        r4,  [r4, #884]                           @r4: video->currPic
    ldr        r12,  [r4, #8]
    add        r12,  r12,  r5                            @topL = video->currPic->Scb + offset;
    
    ldr        r7,  [r0, #24]
    ldr        r9,  [r7, #8]
    add        r9,  r9,  r5
    sub        r10, r8,  r3
    mla        r9,  r6,  r10, r9                         @r9: orgY_2 = currInput->YCbCr[1] + offset + (y_pos >> 2) * (orgPitch - picPitch);
    
    sub        r10, r12,  #1                             @r10:leftL = topL - 1;
    sub        r12, r12,  r3,  asr #1                    @r12:topL -= (picPitch >> 1);
    sub        r11, r9,   r8,  asr #1                    @r11:orgY_3 = orgY_2 - (orgPitch >> 1);
    
    VLD1.8     {d0}, [r12]
    VLD1.8     {d1}, [r9]
    
    VABAL.U8   Q2,  d0,  d1
    
    VMOV.I32   Q0,  #0
    VMOV.I32   Q1,  #0
    mov        r7,  #8
2:
    ldrb       r9,  [r10, r3, asr #1]!
    ldrb       r12, [r11, r8, asr #1]!
    VMOV.U32   d0[0],  r9
    VMOV.U32   d2[0],  r12
    VABA.U16   Q2,  Q0, Q1
    
    subs       r7,  r7,  #1
    blt        2b
    
    
    ldr        r12,  [r4, #12]
    add        r12,  r12,  r5                            @topL = video->currPic->Scb + offset;
    
    ldr        r7,  [r0, #24]
    ldr        r9,  [r7, #12]
    add        r9,  r9,  r5
    sub        r10, r8,  r3
    mla        r9,  r6,  r10, r9                         @r9: orgY_2 = currInput->YCbCr[1] + offset + (y_pos >> 2) * (orgPitch - picPitch);
    
    sub        r10, r12,  #1                             @r10:leftL = topL - 1;
    sub        r12, r12,  r3,  asr #1                    @r12:topL -= (picPitch >> 1);
    sub        r11, r9,   r8,  asr #1                    @r11:orgY_3 = orgY_2 - (orgPitch >> 1);
    
    VLD1.8     {d0}, [r12]
    VLD1.8     {d1}, [r9]
    
    VABAL.U8   Q2,  d0,  d1
    
    VMOV.I32   Q0,  #0
    VMOV.I32   Q1,  #0
    mov        r7,  #8
3:
    ldrb       r9,  [r10, r3, lsr #1]!
    ldrb       r12, [r11, r8, lsr #1]!
    VMOV.U32   d0[0],  r9
    VMOV.U32   d2[0],  r12
    VABA.U16   Q2,  Q0, Q1
    
    subs       r7,  r7,  #1
    blt        3b
    
    
    
    VPADD.U16  d0,  d4, d5
    VPADDL.U32 d0,  d0
    VMOV.U32   r4,  d0[0]
    
    
    mov        r5,  #24
    mul        r6,  r4, r5
    mov        r5,  #5
    mul        r7,  r1, r5
    
    cmp        r6,  r7
    blt        4f
    mov        r0,  #0
    b          5f
4:
    mov        r0,  #1
5:
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |IntraDecisionABE|
    
    
    .section .text
    .global  MBIntraSearch
MBIntraSearch:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@@@@data stack:(highend)lr,r12-r4(lowend)@@@@@@@@@@@@@@@@
    sub        sp,   sp,  #4                            @allocate local variable as min_cost
    ldr        r4,  [r0, #0]                            @r4: video
    ldr        r5,  [r4, #860]                          @r5: video->slice_type
    ldr        r6,  =10716                              @note: AVCMV(*mot16x8)[2]; ...   is one pointer to an array
    ldr        r8,  [r0,  r6]                           @r8: encvid->min_cost
    ldr        r6,  [r8, r1, lsl #2]                    @r6: min_cost = encvid->min_cost[mbnum];
    str        r6,  [sp]
    
    mov        r7,  #1                                  @r7: bool intra = true;
    
    ldr        r9,  [r4,  #912]
    mov        r8,  #0
    str        r8,  [r9,  #184]                         @currMB->CBP = 0;
    
    cmp        r5,  #0
    bne        1f
    stmdb      sp!, {r0 - r3}
    mov        r1,  r6
    bl         IntraDecisionABE
    mov        r7,  r0
    ldmia      sp!, {r0 - r3}
1:
    cmp        r7,  #1
    beq        2f
    cmp        r5,  #2
    bne        5f
2:
    ldr        r6,   [r0,  #24]                        @r6: AVCFrameIO *currInput = encvid->currInput;
    ldr        r8,   [r6,  #16]                        @r8: int orgPitch = currInput->pitch;
    ldr        r9,   [r6,  #4]
    ldr        r10,  [r4,  #920]                       @r10: video->mb_x
    add        r9,   r9,  r10, lsl #4
    ldr        r10,  [r4, #924]                        @r10: video->mb_y
    lsl        r10,  r10,  #4                          @r10: y_pos
    mla        r9,   r10, r8,  r9                      @r9: orgY = currInput->YCbCr[0] + y_pos * orgPitch + x_pos;
    
    stmdb      sp!, {r0 - r3}
    bl         intrapred_luma_16x16
    ldmia      sp!, {r0 - r3}
    
    stmdb      sp!, {r0 - r3}
    mov        r1,  r9
    add        r2,  sp,  #12
    bl         find_cost_16x16
    ldmia      sp!, {r0 - r3}
    
    cmp        r5,   #0
    bne        4f
    ldr        r6,   =5140
    add        r6,   r0,  r6                           @r6: saved_inter = encvid->subpel_pred;
    sub        r9,   r3,  #4
    
    mov        r8,   #16
3:
    VLD1.32    {d0, d1},   [r2]!
    VST1.32    {d0, d1},   [r6]!
    add        r2,  r2,  r9
    subs       r8,  r8,  #1
    bgt        3b
    
4:
    stmdb      sp!, {r0 - r3}
    add        r1,  sp,   #8
    bl         mb_intra4x4_search
    ldmia      sp!, {r0 - r3}
    ldr        r6,  [sp]
    ldr        r8,  =10716
    ldr        r8,  [r0,  r8]
    str        r6,  [r8, r1, lsl #2]
    
    
5:
    ldr        r6,  [r4,  #912]                        @r6:AVCMacroblock *currMB = video->currMB;
    ldr        r8,  [r6,  #156]
    
    cmp        r8,  #0
    beq        7f
    stmdb      sp!, {r0}
    bl         chroma_intra_search
    ldmia      sp!, {r0}
    
    VMOV.I32   Q0,  #0
    add        r9,  r6,  #4                            @r9: currMB->mvL0
    mov        r8,  #4
6:
    VST1.32    {d0, d1},  [r9]!
    subs       r8,  r8,  #1
    bgt        6b
    
    VMOV.I8    d0,  #0xff
    add        r9,  r6,  #132                          @r9: currMB->ref_idx_L0
    VST1.16    d0,  [r9]
    b          9f
    
7:
    cmp        r5,  #0
    bne        9f
    cmp        r7,  #1
    bne        9f
    
    ldr        r5,  =5140
    add        r5,  r0,  r5                            @r5: saved_inter = encvid->subpel_pred; note:encvid->subpel_pred is not a pointer
    add        r6,  r3,  #16
    sub        r2,  r2,  r6,  lsl #4
    
    sub        r7,  r3,  #4
    mov        r6,  #16
8:
    add        r2,  r2,  #4
    VLD1.32    {d0,  d1},  [r5]!
    VST1.32    {d0,  d1},  [r2]!
    add        r2,   r2,  r7
    subs       r6,   r6,  #1
    bgt        8b
    
9:
    add        sp,   sp,  #4
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |MBIntraSearch|

    .section .text
    .global  intrapred_luma_16x16
intrapred_luma_16x16:
    stmdb      sp!, {r4 - r12, lr}
    ldr        r4,  [r0, #0]                            @r4: video
    ldr        r5,  [r4, #884]                          @r5: AVCPictureData *currPic = video->currPic;
    ldr        r6,  [r5, #48]                           @r6: int pitch = currPic->pitch;
    ldr        r7,  [r5, #4]                            @r7: currPic->Sl
    ldr        r8,  [r4, #920]                          @r8: video->mb_x
    ldr        r9,  [r4, #924]                          @r9: video->mb_y
    lsl        r8,  r8,  #4                             @r8: x_pos
    lsl        r9,  r9,  #4                             @r9: y_pos
    mla        r5,  r9,  r6,  r8                        @r5: int offset = y_pos * pitch + x_pos;
    add        r5,  r7,  r5                             @r5: uint8 *curL = currPic->Sl + offset;
    
    ldr        r7,  [r4,  #1220]                        @r7: video->intraAvailA
    ldr        r8,  [r4,  #1224]                        @r8: video->intraAvailB
    
    VMOV.I32   d2,  #0                                  @d2: sum
    
    cmp        r8,  #0
    beq        3f
    
    sub        r9,  r5,  r6                             @r9: top = curL - pitch;
    VLD1.32    {d0,  d1},  [r9]                         @Q0: word4 word3 word2 word1
    
    ldr        r9,   =3380
    add        r9,   r0,   r9                           @r9: pred = encvid->pred_i16[AVC_I16_Vertical]
    mov        r10,  #16
1:
    VST1.32    {d0,  d1},  [r9]!
    subs       r10,  r10,  #1
    bgt        1b
    
    VPADDL.U8  Q0,  Q0
    VPADD.U16  d0,  d0,  d1
    VPADDL.U16 d0,  d0
    VPADDL.U32 d0,  d0
    VADD.U32   d2,  d2,  d0
    
    cmp        r7,  #0
    bne        3f
    VMOV.I32   d0,  #8
    VADD.U32   d2,  d2,  d0
    VSHR.U32   d2,  d2,  #4
    
3:
    cmp        r7,  #0
    beq        6f
    
    sub        r9,  r5,  #1                             @r9: left = curL - 1
    ldr        r10,   =3636
    add        r10, r0,  r10                            @r10: pred = encvid->pred_i16[AVC_I16_Horizontal]
    mov        r11,  #16
4:
    ldrb       r12,  [r9], r6
    VMOV.U32   d0[0],  r12
    VADD.U32   d2,  d2,  d0
    VDUP.I8    Q0,  r12
    VST1.32    {d0,  d1},  [r10]!
    subs       r11,  r11,  #1
    bgt        4b
    
    cmp        r8,  #0
    beq        5f
    VMOV.I32   d0,  #16
    VADD.U32   d2,  d2,  d0
    VSHR.U32   d2,  d2,  #5
    b          6f
5:
    VMOV.I32   d0,  #8
    VADD.U32   d2,  d2,  d0
    VSHR.U32   d2,  d2,  #4
    
6:
    cmp        r7,  #0
    bne        7f
    cmp        r8,  #0
    bne        7f
    VMOV.I8    Q0,  #0x80
    b          8f
7:
    VDUP.I8    Q0,  d2[0]
    
8:
    ldr        r9,   =3892
    add        r9,  r0,  r9                           @pred = encvid->pred_i16[AVC_I16_DC]
    mov        r10,  #16
9:
    VST1.32    {d0,  d1},  [r9]!
    subs       r10,  r10,  #1
    bgt        9b
    
    cmp        r7,   #0
    beq        12f
    cmp        r8,   #0
    beq        12f
    ldr        r7,  [r4,  #1232]                        @r8: video->intraAvailB
    cmp        r7,   #0
    beq        12f
    
    sub        r4,   r5,  r6
    sub        r7,   r4,  #1                            @r7: comp_ref_x1 = curL - pitch + 6;
    add        r4,   r4,  #8                            @r4: comp_ref_x0 = curL - pitch + 8;
    
    sub        r8,   r5,  #1
    add        r9,   r8,  r6,  lsl #3                   @r9: comp_ref_y0 = curL - 1 + (pitch << 3);
    mov        r10,  #6
    mla        r8,   r10, r6,  r8                       @r8: comp_ref_y1 = curL - 1 + 6 * pitch;
    
    VLD1.8     {d0},  [r4]
    VLD1.8     {d1},  [r7]
    VREV64.I8  d1,  d1
    VSUBL.U8   Q0,  d0,  d1
    ldr        r10,  =0x04030201
    ldr        r11,  =0x08070605
    VMOV       d4,  r10,  r11
    VMOVL.U8   Q1,  d4
    VMUL.S16   Q1,  Q0,  Q1
    VADDL.S16  Q0,  d2,  d3
    VADD.S32   d0,  d0,  d1
    VPADDL.S32 d0,  d0
    
    
    mov        r12,  #0
    mov        r10,  #1
10:
    ldrb       r4,   [r9], r6
    ldrb       r7,   [r8]
    sub        r8,   r8,  r6
    sub        r4,   r4,  r7
    mla        r12,  r4,  r10,  r12
    add        r10,  r10,  #1
    cmp        r10,  #8
    ble        10b
    
    sub        r4,   r5,  r6
    add        r4,   r4,  #15
    ldrb       r4,   [r4]
    
    sub        r5,   r5,  #1
    mov        r7,   #15
    mla        r5,   r7,  r6,  r5
    ldrb       r5,   [r5]
    
    add        r4,   r4,  r5
    lsl        r4,   r4,  #4
    add        r4,   r4,  #16
    
    VMOV.S32   d0[1], r12
    VMOV.S32   d1,   #5
    VMUL.S32   d2,   d0,  d1
    VMOV.S32   d0,   #32
    VADD.S32   d0,   d0,  d2
    VSHR.S32   d0,   d0,  #6                            @d0: c b
    
    VDUP.16    Q1,   r4                                 @Q1: a_16 a_16 a_16 a_16 a_16 a_16 a_16 a_16
    
    VMOV.S8    d1,   #1
    VSUB.S8    d4,   d4,  d1                            @d4: 7 6 5 4 - 3 2 1 0
    VMOVL.U8   Q2,   d4                                 @Q2: 7 6 5 4 - 3 2 1 0
    
    VMOV.S16   Q3,   #7                                 @Q3: 7 7 7 7 - 7 7 7 7
    VDUP.S16   Q4,   d0[1]                              @Q4: c c c c - c c c c
    VDUP.S16   Q5,   d0[0]                              @Q5: b b b b - b b b b
    VSHL.S16   Q6,   Q5,  #3                            @Q6: 8b 8b 8b 8b 8b 8b 8b 8b
    VMUL.S16   Q7,   Q5,  Q2                            @Q7: 7b 6b 5b 4b 3b 2b b  0
    VMOV.S16   Q10,  #0xff
    VMOV.S8    Q11,  #0xff
    VMOV.S16   Q14,  #1
    VMOV.S16   Q0,   #0
    
    ldr        r5,   =4148
    add        r5,   r0,  r5                            @r5: pred = encvid->pred_i16[AVC_I16_Plane]
    mov        r4,   #16
11:
    VSUB.S16   Q8,   Q0,  Q3
    VMUL.S16   Q8,   Q8,  Q4
    VADD.S16   Q8,   Q8,  Q1
    VMLS.S16   Q8,   Q3,  Q5
    
    VADD.S16   Q8,   Q8,  Q7
    VSHR.S16   Q9,   Q8,  #5
    
    VCGT.U16   Q12,  Q9, Q10
    VSHR.S16   Q13,  Q9, #15
    VEOR       Q13,  Q13,Q11
    VBIT.16    Q9,   Q13,Q12                            @Q9: x7 x6 x5 x4 x3 x2 x1 x0
    
    @VZIP.I8    d18,  d19
    VUZP.I8     d18,  d19
    VST1.32    {d18},   [r5]!
    
    
    VADD.S32   Q8,   Q8,  Q6
    VSHR.S32   Q9,   Q8,  #5
    
    VCGT.U16   Q12,  Q9, Q10
    VSHR.S16   Q13,  Q9, #15
    VEOR       Q13,  Q13,Q11
    VBIT.16    Q9,   Q13,Q12                            @Q9: x7 x6 x5 x4 x3 x2 x1 x0
    
    @VZIP.I8    d18,  d19
    VUZP.I8     d18,  d19
    VST1.32    {d18},   [r5]!
    
    VADD.S32   Q0,   Q0,  Q14
    subs       r4,   r4,  #1
    bgt        11b
    
12:
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |intrapred_luma_16x16|
    
    
    
    
    
    
    
    .section .text
    .global  chroma_intra_search
chroma_intra_search:
    stmdb      sp!, {r4 - r12, lr}
    ldr        r4,  [r0, #0]
    ldr        r5,  [r4, #884]
    ldr        r6,  [r5, #48]                           @r6: currPic->pitch
    asr        r6,  r6,  #1                             @r6: int pitch = currPic->pitch >> 1;
    
    ldr        r7,  [r5, #8]                            @r7: currPic->Scb
    ldr        r8,  [r5, #12]                           @r8: currPic->Scr
    ldr        r9,  [r4, #920]                          @r9: video->mb_x
    ldr        r10, [r4, #924]                          @r10: video->mb_y
    lsl        r9,  r9,  #3                             @r9: int x_pos = video->mb_x << 3;
    lsl        r10, r10, #3                             @r10: int y_pos = video->mb_y << 3;
    
    mla        r5,  r10,  r6,  r9                       @r5: int offset = y_pos * pitch + x_pos;
    add        r7,  r7,   r5                            @r7: uint8 *curCb = currPic->Scb + offset;
    add        r8,  r8,   r5                            @r8: uint8 *curCr = currPic->Scr + offset;
    
    ldr        r11, [r4,  #1220]                        @r11: video->intraAvailA
    ldr        r12, [r4,  #1224]                        @r12: video->intraAvailB
    
    and        r5,  r11,  r12
    cmp        r5,  #0
    beq        1f
    
    sub        r5,   r7,  r6
    VLD1.32    {d0},   [r5]
    
    VPADDL.U8  d0,   d0
    VPADDL.U16 d0,   d0                                 @d0: sum_x1 sum_x0
    
    sub        r5,    r7,  #1
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d1[0], r11
    
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d1[1], r11                               @d1: sum_y1 sum_y0
    
    
    VMOV.U32   Q2,    #2
    VADD.U32   Q0,    Q0,   Q2
    VADD.U32   d2,    d0,   d1
    VTRN.32    d0,    d1                                @d1: (sum_y1+2)(sum_x1+2)
    VSHR.U32   d0,    d1,   #2                          @d0: pred_2[0]pred_1[0]
    VSHR.U32   d1,    d2,   #3                          @d1: pred_3[0]pred_0[0]
    
    
    sub        r5,    r8,  r6
    VLD1.32    {d2},   [r5]
    
    VPADDL.U8  d2,   d2
    VPADDL.U16 d2,   d2                                 @d2: sum_x1 sum_x0
    
    sub        r5,    r8,  #1
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d3[0], r11
    
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d3[1], r11                               @d3: sum_y1 sum_y0
    
    
    VADD.U32   Q1,    Q1,   Q2
    VADD.U32   d4,    d2,   d3
    VTRN.32    d2,    d3                                @d3: (sum_y1+2)(sum_x1+2)
    VSHR.U32   d2,    d3,   #2                          @d2: pred_2[1]pred_1[1]
    VSHR.U32   d3,    d4,   #3                          @d3: pred_3[1]pred_0[1]
    
    b          4f
    
1:
    cmp        r11,  #0
    beq        2f
    
    sub        r5,    r7,  #1
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d0[0], r11
    
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d0[1], r11
    VMOV       d1,    d0                                @d0, d1: sum_x1 sum_x0
    
    
    sub        r5,    r8,  #1
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d2[0], r11
    
    ldrb       r11,   [r5], r6
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    ldrb       r12,   [r5], r6
    add        r11,   r11,  r12
    VMOV.U32   d2[1], r11
    VMOV       d3,    d2                                @d2, d3:sum_x1 sum_x0
    
    VMOV.U32   Q2,    #2
    VADD.U32   Q0,    Q0,   Q2
    VSHR.U32   Q0,    Q0,   #2                          @d0: pred_2[0]pred_1[0]; d1:pred_3[0]pred_0[0]
    VADD.U32   Q1,    Q1,   Q2
    VSHR.U32   Q1,    Q1,   #2                          @d2: pred_2[1]pred_1[1]; d3:pred_3[1]pred_0[1]
    
    b          4f
    
2:
    cmp        r12,  #0
    beq        3f
    
    sub        r5,   r7,  r6
    VLD1.32    {d0},   [r5]
    
    VPADDL.U8  d0,   d0
    VPADDL.U16 d0,   d0
    
    VMOV.U32   d3,   #2
    VADD.U32   d0,   d0,   d3
    VSHR.U32   d0,   d0,   #2
    VMOV       d1,   d0                                @d0: pred_1[0]pred_2[0]; d1:pred_3[0]pred_0[0]
    VREV64.32  d0,   d0                                @d0: pred_2[0]pred_1[0]; d1:pred_3[0]pred_0[0]
    
    sub        r5,   r8,  r6
    VLD1.32    {d2},   [r5]
    
    VPADDL.U8  d2,   d2
    VPADDL.U16 d2,   d2
    
    VADD.U32   d2,   d2,   d3
    VSHR.U32   d2,   d2,   #2
    VMOV       d3,   d2
    VREV64.32  d2,   d2
    
    b          4f
    
3:
    VMOV.U32   Q0,   #128
    VMOV.U32   Q1,   Q0
    
4:
    ldr        r5,  =4548
    add        r5,  r0,  r5                           @r5: pred = encvid->pred_ic[AVC_IC_DC];
    VDUP.U8    d4,  d1[0]
    VDUP.U8    d5,  d0[0]
    VZIP.32    d4,  d5                                   @d4: pred_b pred_a
    
    VDUP.U8    d5,  d3[0]
    VDUP.U8    d6,  d2[0]
    VZIP.32    d5,  d6                                   @d5: pred_d pred_c
    
    mov        r11,  #4
5:
    VST1.32    {d4,  d5},  [r5]!
    subs       r11,  r11,  #1
    bgt        5b
    
    
    VDUP.U8    d4,  d0[4]
    VDUP.U8    d5,  d1[4]
    VZIP.32    d4,  d5                                   @pred_b pred_a
    
    VDUP.U8    d5,  d2[4]
    VDUP.U8    d6,  d3[4]
    VZIP.32    d5,  d6                                   @pred_d pred_c
    
    mov        r11,  #4
6:
    VST1.32    {d4,  d5},  [r5]!
    subs       r11,  r11,  #1
    bgt        6b
    
    ldr        r11, [r4,  #1220]                        @r11: video->intraAvailA
    cmp        r11,  #0
    beq        8f
    
    sub        r5,   r7,  #1
    sub        r11,  r8,  #1
    ldr        r12,  =4676
    add        r12,  r0,  r12                           @r12: pred = encvid->pred_ic[AVC_IC_Horizontal];
    
    mov        r1,   #8
7:
    ldrb       r2,   [r5], r6
    VDUP.U8    d0,   r2
    ldrb       r2,   [r11],r6
    VDUP.U8    d1,   r2
    VST1.32    {d0,  d1},  [r12]!
    subs       r1,   r1,  #1
    bgt        7b
    
8:
    ldr        r12, [r4,  #1224]                        @r12: video->intraAvailB
    cmp        r12,  #0
    beq        10f
    
    sub        r5,   r7,  r6
    sub        r11,  r8,  r6
    ldr        r12,  =4804
    add        r12,  r0,  r12                           @r12: pred = encvid->pred_ic[AVC_IC_Horizontal];
    
    VLD1.8     {d0},  [r5]
    VLD1.8     {d1},  [r11]
    mov        r1,   #8
9:
    VST1.32    {d0,  d1},  [r12]!
    subs       r1,   r1,  #1
    bgt        9b
    
10:
    ldr        r11, [r4,  #1220]                        @r11: video->intraAvailA
    cmp        r11, #0
    beq        14f
    ldr        r11, [r4,  #1224]                        @r11: video->intraAvailB
    cmp        r11, #0
    beq        14f
    ldr        r11, [r4,  #1232]                        @r11: video->intraAvailD
    cmp        r11, #0
    beq        14f
    
    ldr        r5,   =0x04030201
    VMOV.U32   d2[0],   r5
    VMOVL.U8   Q1,   d2                                  @d2: 0x0004000300020001
    sub        r5,   r7,  r6                             @r5: comp_ref_x = curCb - pitch;
    sub        r11,  r7,  #1
    
    VMOV.U8    d7,   #0xff
    VMOV.U16   d8,   #0xff
    ldr        r12,  =4932
    add        r12,  r0,   r12                           @pred = encvid->pred_ic[AVC_IC_Plane];
    
    mov        r7,   #2
11:
    add        r1,   r5,   #4                            @r1: comp_ref_x0 = comp_ref_x + 4;
    VLD1.8     {d0},  [r1]
    sub        r1,   r5,   #1
    VLD1.8     {d1},  [r1]
    VREV32.8   d1,  d1
    
    VSUBL.U8   Q0,  d0,   d1
    VMUL.S16   d3,  d0,   d2
    VPADDL.S16 d0,  d3
    VPADDL.S32 d0,  d0                                   @d0: xxxx H
    
    
    ldrb       r2,   [r5,  #7]
    mov        r5,   #7
    mla        r1,   r5,   r6, r11
    ldrb       r1,   [r1]
    add        r2,   r2,   r1
    lsl        r2,   r2,   #4
    add        r3,   r2,   #16                           @r3:a_16
    
    add        r5,   r11,  r6,  lsl #2
    add        r11,  r11,  r6,  lsl #1
    mov        r1,   #0
    mov        r2,   #1
12:
    ldrb       r9,   [r5], r6
    ldrb       r10,  [r11]
    sub        r11,  r11,  r6
    sub        r9,   r9,   r10
    mla        r1,   r9,   r2,  r1
    add        r2,   r2,   #1
    cmp        r2,   #4
    ble        12b
    
    VMOV.S32   d0[1],r1                                    @d0: V H
    VMOV.U32   d1,   #16
    VMOV.U32   d3,   #17
    VMLA.S32   d1,   d0,  d3
    VSHR.S32   d0,   d1,  #5                               @d0: c b
    
    
    VMOV       r5,   r10,  d0                              @r5: b; r10: c
    
    VDUP.S16   d0,   d0[0]                                 @d0: b b b b
    VMOV.U16   d1,   #1
    VSUB.S16   d1,   d2,   d1                              @d1: 3 2 1 0
    VMUL.S16   d1,   d1,   d0                              @d1: 3b 2b 1b 0
    VSHL.S16   d0,   d0,   #2                              @d0: 4b 4b 4b 4b
    
    
    mov        r9,   #0
13:
    sub        r11,  r9,   #3
    mov        r1,   r3                                    @r1: a_16
    mla        r1,   r11,  r10,  r1
    sub        r1,   r1,   r5
    sub        r1,   r1,   r5,  lsl #1
    
    VDUP.S16   d3,   r1                                    @d3:factor_c factor_c factor_c factor_c
   
    VADD.S16   d3,   d3,   d1
    VSHR.S16   d10,  d3,   #5
    
    VCGT.U16   d5,   d10,   d8
    VSHR.S16   d6,   d10,   #15
    VEOR       d6,   d6,    d7
    VBIT.16    d10,  d6,    d5                             @d10: x3 x2 x1 x0
    
    
    VADD.S16   d3,   d3,   d0
    VSHR.S16   d9,   d3,   #5
    
    VCGT.U16   d5,   d9,   d8
    VSHR.S16   d6,   d9,   #15
    VEOR       d6,   d6,   d7
    VBIT.16    d9,   d6,   d5                              @d9: x7 x6 x5 x4
    
    VUZP.8     d10,   d9
    VST1.32    {d10},   [r12]
    
    add        r12,  r12,  #16
    add        r9,   r9,   #1
    cmp        r9,   #8
    blt        13b
    
    sub        r12,  r12,  #120
    
    sub        r5,   r8,   r6
    sub        r11,  r8,   #1
    subs       r7,   r7,   #1
    bgt        11b
    
14:
    ldr        r9,  [r4, #920]                          @r9: video->mb_x
    ldr        r10, [r4, #924]                          @r10: video->mb_y
    lsl        r9,  r9,  #3                             @r9: int x_pos = video->mb_x << 3;
    lsl        r10, r10, #3                             @r10: int y_pos = video->mb_y << 3;
    
    ldr        r5,  [r0,  #24]
    ldr        r6,  [r5,  #16]
    asr        r6,  r6,   #1                            @r6: org_pitch = (currInput->pitch) >> 1;
    
    ldr        r7,  [r5,  #8]
    ldr        r8,  [r5,  #12]
    
    mla        r9,  r10,  r6, r9                        @r9: int offset = y_pos * pitch + x_pos;
    add        r7,  r7,   r9
    add        r8,  r8,   r9
    
    ldr        r11, [r4,   #912]                        @r11:AVCMacroblock *currMB = video->currMB;
    
    ldr        r9,  =0x7fffffff
    stmdb      sp!, {r0 - r3}
    add        r3,  r0,  #4544
    mov        r0,  r7
    mov        r1,  r8
    mov        r2,  r6
    stmdb      sp!, {r9}
    bl         SATDChroma
    ldmia      sp!, {r10}
    mov        r10,  r0
    ldmia      sp!, {r0 - r3}
    
    cmp        r10,  r9
    bge        15f
    mov        r9,   r10
    mov        r10,  #0
    str        r10,  [r11]
    
15:
    ldr        r10,  [r4,  #1220]                        @r10: video->intraAvailA
    cmp        r10,  #0
    beq        16f
    
    stmdb      sp!, {r0 - r3}
    add        r3,  r0,  #4672
    mov        r0,  r7
    mov        r1,  r8
    mov        r2,  r6
    stmdb      sp!, {r9}
    bl         SATDChroma
    ldmia      sp!, {r10}
    mov        r10,  r0
    ldmia      sp!, {r0 - r3}
    
    cmp        r10,  r9
    bge        16f
    mov        r9,   r10
    mov        r10,  #1
    str        r10,  [r11]
    
16:
    ldr        r10,  [r4,  #1224]                        @r10: video->intraAvailB
    cmp        r10,  #0
    beq        17f
    
    stmdb      sp!, {r0 - r3}
    add        r3,  r0,  #4800
    mov        r0,  r7
    mov        r1,  r8
    mov        r2,  r6
    stmdb      sp!, {r9}
    bl         SATDChroma
    ldmia      sp!, {r10}
    mov        r10,  r0
    ldmia      sp!, {r0 - r3}
    
    cmp        r10,  r9
    bge        17f
    mov        r9,   r10
    mov        r10,  #2
    str        r10,  [r11]
    
17:
    ldr        r10,  [r4,  #1220]                        @r10: video->intraAvailA
    cmp        r10,  #0
    beq        18f
    
    ldr        r10,  [r4,  #1224]                        @r10: video->intraAvailB
    cmp        r10,  #0
    beq        18f
    
    ldr        r10,  [r4,  #1232]                        @r10: video->intraAvailD
    cmp        r10,  #0
    beq        18f
    
    stmdb      sp!, {r0 - r3}
    add        r3,  r0,  #4928
    mov        r0,  r7
    mov        r1,  r8
    mov        r2,  r6
    stmdb      sp!, {r9}
    bl         SATDChroma
    ldmia      sp!, {r10}
    mov        r10,  r0
    ldmia      sp!, {r0 - r3}
    
    cmp        r10,  r9
    bge        18f
    mov        r10,  #3
    str        r10,  [r11]
    
18:
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |chroma_intra_search|
    
    .end
    
