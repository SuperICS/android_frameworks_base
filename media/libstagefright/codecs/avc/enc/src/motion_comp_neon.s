@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@   motion_comp functions for neon optimization of h264 encoder
@   author: zefeng.tong@amlogic.com
@   date:   2011-06-30
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  eCreateAlign
    
eCreateAlign:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    
    mla        r0,  r1,  r2, r0
    mov        r6,  #24
    sub        r6,  r6,  r5                         @out_offset = 24 - blkwidth;
    sub        r8,  r1,  r5                         @offset =  picpitch - blkwidth;
    
    and        r7,  r0,  #3
    cmp        r7,  #0
    beq        4f
    
    mov        r7,  #4
    mov        r9,  #0
1:
    cmp        r9,  r4
    bge        4f
    
    mov        r10, #0
2:
    cmp        r10, r5
    bge        3f
    
    VLD1.8     {d0}, [r0], r7
    VMOV.I32   r12,  d0[0]
    str        r12,  [r3], #4
    add        r10,  r10, #4
    b          2b
    
3:
    add        r0,   r0,  r8
    add        r3,   r3,  r6
    add        r9,   r9,  #1
    b          1b
    
4:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eCreateAlign|
    
    .section .text
    .global  eHorzInterp1MC
eHorzInterp1MC:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)dx blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    ldr        r6,  [fp, #48]                       @r6: dx
    
    sub        r1,  r1,  r5                         @r1: ref_offset = inpitch - blkwidth;
    sub        r7,  r3,  r5                         @r7: curr_offset = (outpitch - blkwidth) //>> 2;  using bytes
    
    VMOV.U16   d6,  #16                             @d6: 16  16  16  16
    VMOV.U16   d7,  #20                             @d7: 20  20  20  20
    VMOV.U16   d8,  #5                              @d8: 5   5   5   5
    VMOV.U16   d9,  #1                              @d9: 1   1   1   1
    
    VMOV.U8    Q5, #0xff
    VMOV.U32   Q6, #0xff
    
    sub        r0,  r0,  #2                         @r0: p_ref -= 2;
    
    tst        r6,  #1
    beq        3f
    
    asrs       r6,  r6,  #1
    @moveq      r6,  #-4
    @movne      r6,  #-3                             @r6: dx = ((dx >> 1) ? -3 : -4); 
    @add        r6,  r6,  #6                         @r6: dx+2+4
    moveq      r6,  #2
    movne      r6,  #3 
    
1:                                                  @assume blkheight > 0
    mov        r9,  r5                              @r9: tmp = (uint32)(p_ref + blkwidth);
    
2:
    add        r8,  r0,  r6
    add        r10, r0,  #1                         @r10: p_ref[1]
    
    VLD1.8     {d0}, [r0]                           @d0: h g f e -- d c b a
    VLD1.8     {d1}, [r10]                          @d1: i h g f -- e d c b
    VADDL.U8   Q1,  d0,  d1                         @Q1: xx(xx g+h)(f+g)(e+f)--(d+e)(c+d)xx(xx a+b)
    VREV64.32  d1,  d1                              @d1: e d c b -- i h g f
    VADDL.U8   Q2,  d0,  d1                         @Q2: (e+h)(d+g)(c+f)(b+e)--(d+i)(c+h)(b+g)(a+f)
    
    VSHR.U64   d2,  d2,  #32                        @d2: xx xx (d+e)(c+d)
    VZIP.32    d2,  d3                              @d2: (f+g)(e+f)(d+e)(c+d)
    
    VMULL.U16  Q0,  d2,  d7                         @Q0: 20*(f+g) 20*(e+f) 20*(d+e) 20*(c+d)
    VADDW.U16  Q0,  Q0,  d4                         @Q0: 20*(f+g)+(d+i); 20*(e+f)+(c+h); 20*(d+e)+(b+g); 20*(c+d)+(a+f)
    VADDW.U16  Q0,  Q0,  d6                         @Q0: +16
    
    VMLSL.U16  Q0,  d5,  d8                         @Q1: 5*(e+h) 5*(d+g) 5*(c+f) 5*(b+e)
    VSHR.S32   Q0,  Q0,  #5                         @Q0: >>5
    
    @@@@@@@@@@@@@@CLIP_RESULT first@@@@@@@@
    VCGT.U32   Q1,   Q0,   Q6
    VSHR.S32   Q2,   Q0,   #31
    VEOR       Q2,   Q2,   Q5
    VBIT.32    Q0,   Q2,   Q1
    VAND       Q0,   Q0,   Q6
    
    VLD1.8     {d2},  [r8]
    VMOVL.U8   Q1,  d2                              @d2:  p_ref[dx+5] p_ref[dx+4] p_ref[dx+3] p_ref[dx+2]
    VADDW.U16  Q0,  Q0,  d2
    VADDW.U16  Q0,  Q0,  d9
    VSHR.S32   Q0,  Q0,  #1
    
    
    VUZP.8     d0,   d1
    VUZP.8     d0,   d1
    VMOV.32    r8,   d0[0]
    str        r8,   [r2],  #4
    
    add        r0,   r0,  #4
    subs       r9,   r9,  #4
    bgt        2b
    
    add        r2,   r2,  r7                        @p_cur += curr_offset;
    add        r0,   r0,  r1                        @p_ref += ref_offset; 
    
    subs       r4,   r4,  #1
    bgt        1b
    
    b          5f                                  @quit
    
3:                                                  @assume blkheight > 0
    mov        r9,  r5                              @r9: tmp = (uint32)(p_ref + blkwidth);
    
4:
    add        r10, r0,  #1                         @r10: p_ref[1]
    
    VLD1.8     {d0}, [r0]                           @d0: h g f e -- d c b a
    VLD1.8     {d1}, [r10]                          @d1: i h g f -- e d c b
    VADDL.U8   Q1,  d0,  d1                         @Q1: xx(xx g+h)(f+g)(e+f)--(d+e)(c+d)xx(xx a+b)
    VREV64.32  d1,  d1                              @d1: e d c b -- i h g f
    VADDL.U8   Q2,  d0,  d1                         @Q2: (e+h)(d+g)(c+f)(b+e)--(d+i)(c+h)(b+g)(a+f)
    
    VSHR.U64   d2,  d2,  #32                        @d2: xx xx (d+e)(c+d)
    VZIP.32    d2,  d3                              @d2: (f+g)(e+f)(d+e)(c+d)
    
    VMULL.U16  Q0,  d2,  d7                         @Q0: 20*(f+g) 20*(e+f) 20*(d+e) 20*(c+d)
    VADDW.U16  Q0,  Q0,  d4                         @Q0: 20*(f+g)+(d+i); 20*(e+f)+(c+h); 20*(d+e)+(b+g); 20*(c+d)+(a+f)
    VADDW.U16  Q0,  Q0,  d6                         @Q0: +16
    
    VMLSL.U16  Q0,  d5,  d8                         @Q1: 5*(e+h) 5*(d+g) 5*(c+f) 5*(b+e)
    VSHR.S32   Q0,  Q0,  #5                         @Q0: >>5
    
    VCGT.U32   Q1,   Q0,   Q6
    VSHR.S32   Q2,   Q0,   #31
    VEOR       Q2,   Q2,   Q5
    VBIT.32    Q0,   Q2,   Q1
    @VAND       Q0,   Q0,   Q6                       @Q0: x  x  x  x, we will unzip all the low bytes
    
    
    VUZP.8     d0,   d1
    VUZP.8     d0,   d1
    VMOV.32    r8,   d0[0]
    str        r8,   [r2],  #4
    
    add        r0,   r0,  #4
    subs       r9,   r9,  #4
    bgt        4b
    
    add        r2,   r2,  r7                        @p_cur += curr_offset;
    add        r0,   r0,  r1                        @p_ref += ref_offset; 
    
    subs       r4,   r4,  #1
    bgt        3b
    
5:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eHorzInterp1MC|
    
    
    
    
    
    .section .text
    .global  eHorzInterp2MC
eHorzInterp2MC:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)dx blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    ldr        r6,  [fp, #48]                       @r6: dx
    
    sub        r1,  r1,  r5                         @r1: ref_offset = inpitch - blkwidth;
    sub        r7,  r3,  r5                         @r7: curr_offset = (outpitch - blkwidth) //>> 2;  using bytes
    
    
    VMOV.U32   Q6,  #5                              @Q6: 5   5   5   5
    VMOV.U32   Q7,  #20                             @Q7: 20 20  20  20
    VMOV.U32   Q8,  #512                            @Q8:512 512 512 512
    VMOV.U32   Q9,  #16
    VMOV.U32   Q10, #1
    
    VMOV.U8    Q11,#0xff
    VMOV.U32   Q12,#0xff
    
    tst        r6,  #1
    beq        3f
    
    asrs       r6,  r6,  #1
    moveq      r6,  #-4
    movne      r6,  #-3                             @r6: dx = ((dx >> 1) ? -3 : -4); 
    
    
1:                                                  @assume blkheight > 0
    mov        r9,  r5                              @r9: tmp = (uint32)(p_ref + blkwidth);
    
2:
    sub        r8,  r0,  #8                         @r8: p_ref[-2];
    add        r10, r8,  #4                         @r10:p_ref[-1]
    
    add        r0,  r0,  #16
    add        r12, r0,  r6, lsl #2
    
    VLD1.32    {d0,d1,d2,d3}, [r8]                  @d0: r1 r0; d1:r3 r2; d2:r5 r4; d3: r7 r6
    VLD1.32    {d4,d5,d6,d7}, [r10]                 @d4: r2 r1; d5:r4 r3; d6:r6 r5; d7: r8 r7
    
    VADD.S32   Q4,   Q0,  Q3                        @Q4: (r3+r8)(r2+r7)(r1+r6)(r0+r5)
    VADD.S32   Q5,   Q1,  Q2                        @Q5: (r4+r7)(r3+r6)(r2+r5)(r1+r4)
    VADD.S32   d0,   d1,  d5                        @d0: (r3+r4)(r2+r3)
    VADD.S32   d1,   d2,  d6                        @Q0: (r5+r6)(r4+r5)(r3+r4)(r2+r3)
    
    VMLS.S32   Q4,   Q5,  Q6
    VMLA.S32   Q4,   Q0,  Q7
    VADD.S32   Q4,   Q4,  Q8
    VSHR.S32   Q4,   Q4,  #10
    
    @@@@@@@@@@@CLIP_RESULT@@@@@@@@@
    VCGT.U32   Q0,   Q4,   Q12
    VSHR.S32   Q1,   Q4,   #31
    VEOR       Q1,   Q1,   Q11
    VBIT.32    Q4,   Q1,   Q0
    VAND       Q4,   Q4,   Q12
    
    VLD1.32    {d6, d7},  [r12]
    VADD.S32   Q3,   Q3,   Q9
    VSHR.S32   Q3,   Q3,   #5
    
    @@@@@@@@@@@CLIP_RESULT@@@@@@@@@
    VCGT.U32   Q0,   Q3,   Q12
    VSHR.S32   Q1,   Q3,   #31
    VEOR       Q1,   Q1,   Q11
    VBIT.32    Q3,   Q1,   Q0
    VAND       Q3,   Q3,   Q12
    
    VADD.U32   Q3,   Q3,   Q4
    VADD.U32   Q3,   Q3,   Q10
    VSHR.U32   Q3,   Q3,   #1
    
    VUZP.8     d6,   d7
    VUZP.8     d6,   d7
    VMOV.32    r8,   d6[0]
    str        r8,   [r2], #4
    
    subs       r9,   r9,   #4
    bgt        2b
    
    add        r2,   r2,  r7                        @p_cur += curr_offset;
    add        r0,   r0,  r1, lsl #2                @p_ref += ref_offset; 
    
    subs       r4,   r4,  #1
    bgt        1b
    
    b          5f                                  @quit
    
    
3:                                                  @assume blkheight > 0
    mov        r9,  r5                              @r9: tmp = (uint32)(p_ref + blkwidth);
    
4:
    sub        r8,  r0,  #8                         @r8: p_ref[-2];
    add        r10, r8,  #4                         @r10:p_ref[-1]
    
    VLD1.32    {d0,d1,d2,d3}, [r8]                  @d0: r1 r0; d1:r3 r2; d2:r5 r4; d3: r7 r6
    VLD1.32    {d4,d5,d6,d7}, [r10]                 @d4: r2 r1; d5:r4 r3; d6:r6 r5; d7: r8 r7
    
    VADD.S32   Q4,   Q0,  Q3                        @Q4: (r3+r8)(r2+r7)(r1+r6)(r0+r5)
    VADD.S32   Q5,   Q1,  Q2                        @Q5: (r4+r7)(r3+r6)(r2+r5)(r1+r4)
    VADD.S32   d0,   d1,  d5                        @d0: (r3+r4)(r2+r3)
    VADD.S32   d1,   d2,  d6                        @Q0: (r5+r6)(r4+r5)(r3+r4)(r2+r3)
    
    VMLS.S32   Q4,   Q5,  Q6
    VMLA.S32   Q4,   Q0,  Q7
    VADD.S32   Q4,   Q4,  Q8
    VSHR.S32   Q4,   Q4,  #10
    
    @@@@@@@@@@@CLIP_RESULT@@@@@@@@@
    VCGT.U32   Q0,   Q4,   Q12
    VSHR.S32   Q1,   Q4,   #31
    VEOR       Q1,   Q1,   Q11
    VBIT.32    Q4,   Q1,   Q0
    VAND       Q3,   Q4,   Q12
    
    
    VUZP.8     d6,   d7
    VUZP.8     d6,   d7
    VMOV.32    r8,   d6[0]
    str        r8,   [r2], #4
    
    add        r0,   r0,  #16
    subs       r9,   r9,  #4
    bgt        4b
    
    add        r2,   r2,  r7                        @p_cur += curr_offset;
    add        r0,   r0,  r1, lsl #2                @p_ref += ref_offset; 
    
    subs       r4,   r4,  #1
    bgt        3b
    
5:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eHorzInterp2MC|
    
    
    
    
    
    
    .section .text
    .global  eHorzInterp3MC
eHorzInterp3MC:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend) blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    
    sub        r1,  r1,  r5                         @r1: ref_offset = inpitch - blkwidth;
    sub        r7,  r3,  r5                         @r7: curr_offset = (outpitch - blkwidth);
    
    
    VMOV.U32   Q4,  #5                              @Q6: 5   5   5   5
    VMOV.U32   Q5,  #20                             @Q5: 20 20  20  20
    
    
1:                                                  @assume blkheight > 0
    add        r9,  r0,  r5                         @r9: tmp = (uint32)(p_ref + blkwidth);
    
2:
    sub        r8, r0,  #2                          @r8: p_ref[-2];
    add        r6, r8,  #1                          @r6: p_ref[-1]
    
    VLD1.8     {d0},   [r8]                         @d0: r7 r6 r5 r4 r3 r2 r1 r0
    VLD1.8     {d1},   [r6]                         @d1: r8 r7 r6 r5 r4 r3 r2 r1
    VMOVL.U8   Q1,   d1                             @Q1: r8 r7 r6 r5--r4 r3 r2 r1
    VMOVL.U8   Q0,   d0                             @Q0: r7 r6 r5 r4--r3 r2 r1 r0
    
    VADDL.U16  Q2,   d0,  d3                        @Q2: (r3+r8)(r2+r7)(r1+r6)(r0+r5)
    VADDL.U16  Q3,   d1,  d2                        @Q3: (r4+r7)(r3+r6)(r2+r5)(r1+r4)
    VADD.U16   Q0,   Q0,  Q1                        @Q0: xxxx(r5+r6)(r4+r5)(r3+r4)(r2+r3) xxxx   
    
    VSHR.U64   d0,   d0,  #32                       @d0: xxxx(r3+r4)(r2+r3)
    VZIP.32    d0,   d1                             @d0: (r5+r6)(r4+r5)(r3+r4)(r2+r3)
    VMOVL.U16  Q0,   d0
    
    VMLS.U32   Q2,   Q3,  Q4
    VMLA.S32   Q2,   Q0,  Q5
    
    VST1.32    {d4, d5},  [r2]!
    
    add        r0,   r0,  #4
    cmp        r0,   r9
    blt        2b
    
    add        r2,   r2,  r7, lsl #2                @p_cur += curr_offset;
    add        r0,   r0,  r1                        @p_ref += ref_offset; 
    
    subs       r4,   r4,  #1
    bgt        1b
    
    
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eHorzInterp3MC|
    
    @@@@@@@@@@@@@@@@@@note: this is for blkwidth multiple of 8, actually it is in our encoder@@@@@@@@@@@@@@@
    .section .text
    .global  eVertInterp2MC
eVertInterp2MC:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend) blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    
    mul        r10, r1,  r4                         @r10: ref_offset = blkheight * inpitch;
    mul        r12, r3,  r4                         @r12: outpitch * blkheight;
    rsb        r4,  r12, #8                         @r4: curr_offset = 1 - outpitch * (blkheight - 1); note: we moved 8 bytes one time
    lsl        r6,  r3,  #2
    
    VMOV.U16   Q4,  #5                              @Q6: 5   5   5   5
    VMOV.U16   Q5,  #20                             @Q5: 20 20  20  20
    
    
1:
    mov        r8,  r0
    add        r0,  r0,  #8
    mov        r9,  r10                             @r9: ref_offset
    
2:
    sub        r8,  r8,  r1,  lsl #1                @r8: (p_ref - (inpitch << 1))
    
    VLD1.8     {d0},   [r8],  r1                    @d0: r0 r0 r0 r0 r0 r0 r0 r0
    VLD1.8     {d1},   [r8],  r1                    @d1: r1 r1 r1 r1 r1 r1 r1 r1
    VLD1.8     {d2},   [r8],  r1                    @d2: r2 r2 r2 r2 r2 r2 r2 r2
    VLD1.8     {d3},   [r8],  r1                    @d3: r3 r3 r3 r3 r3 r3 r3 r3
    VLD1.8     {d4},   [r8],  r1                    @d4: r4 r4 r4 r4 r4 r4 r4 r4
    VLD1.8     {d5},   [r8],  r1                    @d5: r5 r5 r5 r5 r5 r5 r5 r5
    VLD1.8     {d6},   [r8],  r1                    @d6: r6 r6 r6 r6 r6 r6 r6 r6
    VLD1.8     {d7},   [r8],  r1                    @d7: r7 r7 r7 r7 r7 r7 r7 r7
    VLD1.8     {d12},  [r8]                         @d12:r8 r8 r8 r8 r8 r8 r8 r8
    
    VADDL.U8   Q7,   d0,  d5                        @Q7: (r0+r5)(r0+r5)(r0+r5)(r0+r5)(r0+r5)(r0+r5)(r0+r5)(r0+r5)
    VADDL.U8   Q8,   d1,  d4                        @Q8: (r1+r4)(r1+r4)(r1+r4)(r1+r4)(r1+r4)(r1+r4)(r1+r4)(r1+r4)
    VADDL.U8   Q9,   d2,  d3                        @Q9: (r2+r3)(r2+r3)(r2+r3)(r2+r3)(r2+r3)(r2+r3)(r2+r3)(r2+r3)
    VMLS.U16   Q7,   Q8,  Q4
    VMLA.S16   Q7,   Q9,  Q5
    VMOVL.S16  Q8,   d14
    VMOVL.S16  Q9,   d15
    VST1.32    {d16, d17, d18, d19},  [r2],  r6
    
    
    VADDL.U8   Q7,   d1,  d6                        @Q7: (r1+r6)(r1+r6)(r1+r6)(r1+r6)(r1+r6)(r1+r6)(r1+r6)(r1+r6)
    VADDL.U8   Q8,   d2,  d5                        @Q8: (r2+r5)(r2+r5)(r2+r5)(r2+r5)(r2+r5)(r2+r5)(r2+r5)(r2+r5)
    VADDL.U8   Q9,   d3,  d4                        @Q9: (r3+r4)(r3+r4)(r3+r4)(r3+r4)(r3+r4)(r3+r4)(r3+r4)(r3+r4)
    VMLS.U16   Q7,   Q8,  Q4
    VMLA.S16   Q7,   Q9,  Q5
    VMOVL.S16  Q8,   d14
    VMOVL.S16  Q9,   d15
    VST1.32    {d16, d17, d18, d19},  [r2],  r6
    
    
    VADDL.U8   Q7,   d2,  d7                        @Q7: (r2+r7)(r2+r7)(r2+r7)(r2+r7)(r2+r7)(r2+r7)(r2+r7)(r2+r7)
    VADDL.U8   Q8,   d3,  d6                        @Q8: (r3+r6)(r3+r6)(r3+r6)(r3+r6)(r3+r6)(r3+r6)(r3+r6)(r3+r6)
    VADDL.U8   Q9,   d4,  d5                        @Q9: (r4+r5)(r4+r5)(r4+r5)(r4+r5)(r4+r5)(r4+r5)(r4+r5)(r4+r5)
    VMLS.U16   Q7,   Q8,  Q4
    VMLA.S16   Q7,   Q9,  Q5
    VMOVL.S16  Q8,   d14
    VMOVL.S16  Q9,   d15
    VST1.32    {d16, d17, d18, d19},  [r2],  r6
    
    
    VADDL.U8   Q7,   d3,  d12                       @Q7: (r3+r8)(r3+r8)(r3+r8)(r3+r8)(r3+r8)(r3+r8)(r3+r8)(r3+r8)
    VADDL.U8   Q8,   d4,  d7                        @Q8: (r4+r7)(r4+r7)(r4+r7)(r4+r7)(r4+r7)(r4+r7)(r4+r7)(r4+r7)
    VADDL.U8   Q9,   d5,  d6                        @Q9: (r5+r6)(r5+r6)(r5+r6)(r5+r6)(r5+r6)(r5+r6)(r5+r6)(r5+r6)
    VMLS.U16   Q7,   Q8,  Q4
    VMLA.S16   Q7,   Q9,  Q5
    VMOVL.S16  Q8,   d14
    VMOVL.S16  Q9,   d15
    VST1.32    {d16, d17, d18, d19},  [r2],  r6
    
    sub        r8,   r8,  r1,  lsl #1
    subs       r9,   r9,  r1,  lsl #2               @ -inpitch*4
    bgt        2b
    
    add        r2,   r2,  r4,  lsl #2               @p_cur += curr_offset;  8 times *4bytes 
    subs       r5,   r5,  #8
    bgt        1b
    
    
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eVertInterp2MC|
    
    .section .text
    .global  eFullPelMC
    
eFullPelMC:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #44]                       @r4: blkheight
    ldr        r5,  [fp, #40]                       @r5: blkwidth
    
    sub        r8,  r1, r5                          @r8: int offset_in = srcPitch - blkwidth;
    sub        r6,  r3, r5                          @r6: int offset_out = predPitch - blkwidth;
    mov        r7,  #8
    
    and        r9,  r0, #3
    cmp        r9,  #0
    beq        6f
1:
    cmp        r4,  #0
    ble        11f
2:
    and        r10, r5, #7                          @r10: blkwidth remainder of 8
    lsr        r9,  r5, #3
3:
    cmp        r9,  #0
    ble        4f
    VLD1.8     {d0}, [r0], r7
    VST1.32    {d0}, [r2], r7
    sub        r9,   r9, #1
    b          3b
4:
    cmp        r10, #0
    ble        5f
    VLD1.8     {d0}, [r0]
    VMOV.32    r9,  d0[0]
    str        r9,  [r2], #4
    sub        r10, r10,  #4
    add        r0,  r0,   #4
    b          4b
5:
    add        r2,  r2, r6
    add        r0,  r0, r8
    sub        r4,  r4, #1
    b          1b
    
6:
    cmp        r4,  #0
    ble        11f
7:
    and        r10, r5, #7                          @blkwidth remainder of 8
    lsr        r9,  r5, #3
8:
    cmp        r9,  #0
    ble        9f
    VLD1.32    {d0}, [r0], r7
    VST1.32    {d0}, [r2], r7
    sub        r9,   r9, #1
    b          8b
9:
    cmp        r10, #0
    ble        10f
    ldr        r9,  [r0], #4
    str        r9,  [r2], #4
    sub        r10, r10,  #4
    b          9b
10:
    add        r2,  r2, r6
    add        r0,  r0, r8
    sub        r4,  r4, #1
    b          6b
    
11:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eFullPelMC|




@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@note: dy is assumed as a little number, less than 8. 
@      see the caller eChromaMotionComp
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  eChromaDiagonalMC_SIMD
    
eChromaDiagonalMC_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    sub        sp, fp, #288                         @allocate temp[288]; in stack
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    
    VDUP.8     d0,  r2                              @d0: dx
    VMOV.S8    d1,  #8
    VSUB.S8    d1,  d1, d0                          @d1: int dx_8 = 8 - dx;
    
    mov        r6,   sp
    mov        r10,  #0
1:
    mov        r7,   r0
    
    mov        r12,  #0
2:
    cmp        r12,  r5
    bge        3f
    
    VLD1.8     {d2}, [r7]                           @d2: ref[7]ref[6]ref[5]ref[4]ref[3]ref[2]ref[1]ref[0]
    VSHR.U64   d3,   d2, #8                         @d3: xxxxxxref[7]ref[6]ref[5]ref[4]ref[3]ref[2]ref[1]
    
    VMULL.U8   Q2,   d2, d1
    VMULL.U8   Q3,   d3, d0
    VADD.U16   Q2,   Q2, Q3
    
    VST1.32    {d4},  [r6]!
    
    add        r7,   r7, #4
    add        r12,  r12, #4
    b          2b
    
3:
    add        r0,   r0, r1
    add        r10,  r10, #1
    add        r6,   sp, r10, lsl #5                @sp + 32 + 32 ...
    cmp        r10,  r4
    ble        1b
    
    
    VDUP.16   Q0,  r3                               @Q0: dy
    VMOV.S16  Q1,  #8
    VSUB.S16  Q1,  Q1, Q0                           @Q1: int dy_8 = 8 - dy;
    
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    mov        r8,  sp
    mov        r10, #0
4:
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    cmp        r10, r5
    bge        7f
    
    mov        r9,  r7
    mov        r12, #0
5:
    ldr        r4,  [fp, #52]                       @r4: blkheight
    cmp        r12, r4, lsr #1
    bge        6f
    
    VMOV.S16   Q2,  #0x20
    VLD1.32    {d6}, [r8]
    add        r8,  r8,  #32
    VLD1.32    {d7}, [r8]
    VMOV       d8,  d7
    add        r8,  r8,  #32
    VLD1.32    {d9}, [r8]
    
    VMLA.S16   Q2,  Q3,  Q1
    VMLA.S16   Q2,  Q4,  Q0
    VSHR.S16   Q2,  Q2,  #6
    
    VUZP.I8    d4,  d5
    VMOV       r4,  r5, d4
    str        r4,  [r9], r6
    str        r5,  [r9], r6
    
    add        r12, r12,  #1
    b          5b
6:
    add        r7,  r7,  #4
    add        r8,  sp,  #8                         @ since it can only iterate twice max, note: I saved tmp one by one, so add 8
    add        r10, r10, #4
    b          4b
    
7:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaDiagonalMC_SIMD|
    
    
    
    .section .text
    .global  eChromaHorizontalMC_SIMD
eChromaHorizontalMC_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    VMOV.U8    d1,  #8
    VDUP.8     d0,  r2                              @d0: dx dx dx dx - dx dx dx dx
    VSUB.U8    d1,  d1, d0                          @d1: int dx_8 = 8 - dx;
    
    mov        r8,  #0
1:
    ldr        r4,  [fp, #52]                       @r4: blkheight
    cmp        r8,  r4
    bge        4f
    
    mov        r9,  r0
    mov        r10, r7
    
    mov        r12, #0
2:
    cmp        r12, r5
    bge        3f
    
    VLD1.8     {d2}, [r9]                           @d2: ref[7]ref[6]ref[5]ref[4]ref[3]ref[2]ref[1]ref[0]
    VSHR.U64   d3,   d2, #8                         @d3: xxxxxxref[7]ref[6]ref[5]ref[4]ref[3]ref[2]ref[1]
    
    VMOV.U16   Q2,  #4
    VMLAL.U8   Q2,  d2,  d1
    
    VMLAL.U8   Q2,  d3,  d0
    VSHR.U16   Q2,  Q2,  #3
    
    VUZP.I8    d4,  d5
    VMOV.S32   r4,  d4[0]
    str        r4,  [r10], #4                            @r10=r10+4
    add        r9,  r9,  #4
    add        r12, r12, #4
    b          2b
    
3:
    add        r0,  r0,  r1
    add        r7,  r7,  r6
    add        r8,  r8,  #1
    b          1b
    
4:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaHorizontalMC_SIMD|
    
@eChromaHorizontalMC_SIMD:
@    stmdb      sp!, {r4 - r12, lr}
@    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
@    mov        fp, sp                               @set frame pointer reg
    
@    ldr        r6,  [fp, #44]                       @r6: predPitch
@    ldr        r7,  [fp, #40]                       @r7: pOut
    
@    VMOV.S32   Q1,  #8
@    VDUP.32    Q0,  r2                              @Q0: dx
@    VSUB.S16   Q1,  Q1, Q0                          @Q1: int dx_8 = 8 - dx;
    
@    mov        r8,  #0
@1:
@    ldr        r4,  [fp, #52]                       @r4: blkheight
@    cmp        r8,  r4
@    bge        4f
    
@    mov        r9,  r0
@    mov        r10, r7
    
@    ldrb       r4, [r9]
    
@    mov        r12, #0
@2:
@    ldr        r5,  [fp, #48]                       @r5: blkwidth
@    cmp        r12, r5
@    bge        3f
    
@    ldrb       r5, [r9, #2]
@    VMOV       d4,  r4,  r5
    
@    ldrb       r4, [r9, #4]
@    VMOV       d7,  r5,  r4
    
@    ldrb       r4, [r9, #1]
@    ldrb       r5, [r9, #3]
@    VMOV       d5,  r4,  r5
    
@    VMOV       d6, d5
@    ldrb       r4, [r9, #4]!                         @for next round
    
@    VMOV.S32   Q4,  #4
@    VMLA.S32   Q4,  Q2,  Q1
    
@    VMLA.S32   Q4,  Q3,  Q0
@    VSHR.S32   Q4,  Q4,  #3
    
@    VZIP.I8    d8,  d9
@    VZIP.I16   d8,  d9
@    VMOV.S32   r5,  d8[0]
@    str        r5,  [r10], #4                            @r10=r10+4
@    add        r12, r12, #4
@    b          2b
    
@3:
@    add        r0,  r0,  r1
@    add        r7,  r7,  r6
@    add        r8,  r8,  #1
@    b          1b
    
@4:
@    mov        sp, fp
@    ldmia      sp!, {r4 - r12, pc}
@    @ENDP  @ |eChromaHorizontalMC_SIMD|


@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@note: neon load more data for speed up, data in overflow address is ignored
@if some error happened, please use marked code and report to the author. Thanks.
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  eChromaVerticalMC_SIMD
    
eChromaVerticalMC_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    VMOV.U8    d1,  #8
    VDUP.8     d0,  r3                              @d0: dy dy dy dy - dy dy dy dy
    VSUB.U8    d1,  d1, d0                          @d1: dy_8 ...
    
    mov        r8,  #0
1:
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    cmp        r8,  r5
    bge        4f
    
    mov        r9,  r0
    mov        r10, r7
    
    mov        r12, #0
2:
    cmp        r12, r4
    bge        3f
    
    VLD1.8     {d2}, [r9], r1                       @load more 4 bytes
    
    VMOV.U16   Q2,  #4
    VMLAL.U8   Q2,  d2,  d1
    
    VLD1.8     {d2}, [r9]                           @load more 4 bytes
    
    VMLAL.U8   Q2,  d2,  d0
    VSHR.U16   Q2,  Q2,  #3
    
    VUZP.I8    d4,  d5
    VMOV.U32   r5,  d4[0]
    str        r5,  [r10], r6
    add        r12, r12, #1
    b          2b
    
3:
    add        r0,  r0,  #4
    add        r7,  r7,  #4
    add        r8,  r8,  #4
    b          1b
    
4:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaVerticalMC_SIMD|
    
@eChromaVerticalMC_SIMD:
@    stmdb      sp!, {r4 - r12, lr}
@    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
@    mov        fp, sp                               @set frame pointer reg
    
@    ldr        r6,  [fp, #44]                       @r6: predPitch
@    ldr        r7,  [fp, #40]                       @r7: pOut
    
@    VMOV.S32   Q1,  #8
@    VDUP.32    Q0,  r3                              @Q0: dy
@    VSUB.S16   Q1,  Q1, Q0                          @Q1: int dy_8 = 8 - dy;
    
@    mov        r8,  #0
@1:
@    ldr        r5,  [fp, #48]                       @r5: blkwidth
@    cmp        r8,  r5
@    bge        4f
    
@    mov        r9,  r0
    
@    ldrb       r10, [r9]
@    ldrb       r12, [r9, #2]
@    VMOV       d4,  r10,  r12
@    ldrb       r10, [r9, #1]
@    ldrb       r12, [r9, #3]
@    VMOV       d5,  r10,  r12
@    add        r9,  r9,  r1
    
@    mov        r10, r7
    
@    mov        r12, #0
@2:
@    ldr        r4,  [fp, #52]                       @r4: blkheight
@    cmp        r12, r4
@    bge        3f
    
@    VMOV.S32   Q3,  #4
@    VMLA.S32   Q3,  Q2,  Q1
    
@    ldrb       r4, [r9]
@    ldrb       r5, [r9, #2]
@    VMOV       d4,  r4,  r5
@    ldrb       r4, [r9, #1]
@    ldrb       r5, [r9, #3]
@    VMOV       d5,  r4,  r5
    
@    VMLA.S32   Q3,  Q2,  Q0
@    VSHR.S32   Q3,  Q3,  #3
    
@    VZIP.I8    d6,  d7
@    VZIP.I16   d6,  d7
@    VMOV.S32   r4,  d6[0]
@    str        r4,  [r10]
@    add        r10, r10, r6
@    add        r9,  r9,  r1
@    add        r12, r12, #1
@    b          2b
    
@3:
@    add        r0,  r0,  #4
@    add        r7,  r7,  #4
@    add        r8,  r8,  #4
@    b          1b
    
@4:
@    mov        sp, fp
@    ldmia      sp!, {r4 - r12, pc}
@    @ENDP  @ |eChromaVerticalMC_SIMD|
    

    .section .text
    .global  eChromaDiagonalMC2_SIMD
    
eChromaDiagonalMC2_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    sub        sp, fp, #72                          @allocate int64 temp[9]; in stack
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    VDUP.32    d0,  r2                              @d0: dx
    
    mov        r10,  #8
    mov        r12,  #0
1:
    ldrb       r8,   [r0]
    ldrb       r9,   [r0, #1]
    VMOV       d1,   r8, r9                         @d1: pRef[1] pRef[0]
    ldrb       r8,  [r0, #2]
    VMOV       d2,   r9, r8                        @d2: pRef[2] pRef[1]
    
    VSUB.S32   d2,   d2, d1
    VSHL.S32   d1,   d1, #3
    VMLA.S32   d1,   d2, d0
    
    VST1.32    d1,   [sp], r10
    add        r0,   r0,  r1
    add        r12,  r12, #1
    
    cmp        r12,  r4
    ble        1b
    
    mul        r12,  r1, r12
    sub        r0,   r0, r12
    sub        sp,   fp, #72
    
    
    VMOV.S32   d1,  #8
    VDUP.32    d0,  r3                              @d0: dy
    VSUB.S32   d1,  d1, d0                          @d1: int dy_8 = 8 - dy;
    
    VLD1.32    d3,  [sp], r10
    mov        r12,  #0
2:
    cmp        r12,  r4
    bge        3f
    VMOV.S32   d2,   #0x20
    VMLA.S32   d2,   d3,  d1
    
    VLD1.32    d3,  [sp], r10
    
    VMLA.S32   d2,   d3,  d0
    VSHR.S32   d2,   d2,  #6
    
    VMOV       r8,   r9,  d2
    orr        r8,   r8,  r9, lsl #8
    strh       r8,   [r7], r6
    add        r12,  r12, #1
    b          2b
3:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaDiagonalMC2_SIMD|
    
    

    .section .text
    .global  eChromaHorizontalMC2_SIMD
    
eChromaHorizontalMC2_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    VDUP.32    d0,  r2                              @d0: dx
    VMOV.S32   d3,   #4
    
    mov        r12,  #0
1:
    cmp        r12,  r4
    bge        2f
    
    ldrb       r8,   [r0]
    ldrb       r9,   [r0, #1]
    ldrb       r10,  [r0, #2]
    
    VMOV       d1,   r8, r9                         @d1: pRef[1] pRef[0]
    VMOV       d2,   r9, r10                        @d2: pRef[2] pRef[1]
    
    VSUB.S32   d2,   d2, d1
    VSHL.S32   d1,   d1, #3
    VADD.S32   d1,   d1, d3
    VMLA.S32   d1,   d2, d0
    VSHR.S32   d1,   d1, #3
    
    VMOV       r8,   r9,  d1
    orr        r8,   r8,  r9, lsl #8
    strh       r8,   [r7], r6
    add        r0,   r0,  r1
    add        r12,  r12, #1
    b          1b
2:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaHorizontalMC2_SIMD|



    .section .text
    .global  eChromaVerticalMC2_SIMD
    
eChromaVerticalMC2_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    VMOV.S32   d1,  #8
    VDUP.32    d0,  r3                              @d0: dy
    VSUB.S32   d1,  d1, d0                          @d1: int dy_8 = 8 - dy;
    
    ldrb       r8,  [r0]
    ldrb       r9,  [r0, #1]
    VMOV       d3,  r8, r9
    add        r0,  r0, r1
    
    mov        r10,  #0
1:
    cmp        r10,  r4
    bge        2f
    VMOV.S32   d2,   #4
    VMLA.S32   d2,   d3,  d1
    
    ldrb       r8,  [r0]
    ldrb       r9,  [r0, #1]
    VMOV       d3,  r8, r9
    
    VMLA.S32   d2,   d3,  d0
    VSHR.S32   d2,   d2,  #3
    
    VMOV       r8,   r9,  d2
    orr        r8,   r8,  r9, lsl #8
    strh       r8,   [r7], r6
    add        r0,   r0,  r1
    add        r10,  r10, #1
    b          1b
2:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaVerticalMC2_SIMD|



    .section .text
    .global  eChromaFullMC_SIMD
    
eChromaFullMC_SIMD:
    stmdb      sp!, {r4 - r12, lr}
    @@@data stack:(highend)blkheight,blkwidth,predPitch, pOut, lr,r12-r4(lowend)@@@
    mov        fp, sp                               @set frame pointer reg
    
    ldr        r4,  [fp, #52]                       @r4: blkheight
    ldr        r5,  [fp, #48]                       @r5: blkwidth
    ldr        r6,  [fp, #44]                       @r6: predPitch
    ldr        r7,  [fp, #40]                       @r7: pOut
    
    sub        r8,  r1, r5                          @r8: int offset_in = srcPitch - blkwidth;
    sub        r6,  r6, r5                          @r6: int offset_out = predPitch - blkwidth;
    
    
    and        r9,  r0, #1
    cmp        r9,  #1
    bne        6f
1:
    cmp        r4,  #0
    ble        11f
2:
    and        r10, r5, #7                          @r10: blkwidth remainder of 8
    lsr        r9,  r5, #3
3:
    cmp        r9,  #0
    ble        4f
    VLD1.8     {d0}, [r0]
    VST1.16    {d0}, [r7]
    add        r0,   r0, #8
    add        r7,   r7, #8
    sub        r9,   r9, #1
    b          3b
4:
    cmp        r10, #0
    ble        5f
    ldrb       r9,  [r0], #1
    ldrb       r12, [r0], #1
    orr        r9,  r9,  r12, lsl #8
    strh       r9,  [r7], #2
    sub        r10, #2
    b          4b
5:
    add        r7,  r7, r6
    add        r0,  r0, r8
    sub        r4,  r4, #1
    b          1b
    
6:
    cmp        r4,  #0
    ble        11f
7:
    and        r10, r5, #7                          @blkwidth remainder of 8
    lsr        r9,  r5, #3
8:
    cmp        r9,  #0
    ble        9f
    VLD1.16    {d0}, [r0]
    VST1.16    {d0}, [r7]
    add        r0,   r0, #8
    add        r7,   r7, #8
    sub        r9,   r9, #1
    b          8b
9:
    cmp        r10, #0
    ble        10f
    ldrh       r9,  [r0], #2
    strh       r9,  [r7], #2
    sub        r10, r10,  #2
    b          9b
10:
    add        r7,  r7, r6
    add        r0,  r0, r8
    sub        r4,  r4, #1
    b          6b
    
11:
    mov        sp, fp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |eChromaFullMC_SIMD|
    
    .end
    