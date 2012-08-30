

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@        Function:   SAD_Macroblock
@        Date:       09/07/2000
@        Purpose:    Compute SAD 16x16 between blk and ref.
@        To do:      Uniform subsampling will be inserted later!
@                    Hypothesis Testing Fast Matching to be used later!
@        Changes:
@    11/7/00:     implemented MMX
@    1/24/01:     implemented SSE
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    .section .text
@    .global	SAD_Macroblock_C
@    .extern simd_sad_mb [CODE]
@SAD_Macroblock_C:
@    stmdb      sp!, {lr}
    
@    @@@@@@@@@@@@@@@@@@@@prepare parameters input@@@@@@@@@@@@@@@
@    mvn        r3,  #0
@    lsr        r3,  #16
@    and        r3,  r3, r2                           @Int lx = dmin_lx & 0xFFFF;
@    lsr        r2,  r2, #16                          @Int dmin = (ULong)dmin_lx >> 16;
    
@    bl         simd_sad_mb
    
@    ldmia      sp!, {pc}
@    @ENDP  @ |SAD_Macroblock_C|
    
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@        Function:   AVCAVCSAD_MB_HTFM_Collect and AVCSAD_MB_HTFM
@        Date:       3/2/1
@        Purpose:    Compute the SAD on a 16x16 block using
@                    uniform subsampling and hypothesis testing fast matching
@                    for early dropout. SAD_MB_HP_HTFM_Collect is to collect
@                    the statistics to compute the thresholds to be used in
@                    SAD_MB_HP_HTFM.
@        Input/Output:
@        Changes:
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global	AVCAVCSAD_MB_HTFM_Collect
AVCAVCSAD_MB_HTFM_Collect:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@@@@@@@@@@@@allocate local variable here@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    sub        fp, sp, #64                           @fp: r11, move to low end
    sub        sp, sp, #64                           @int saddata[16]
    
    @@@@@@@@input parameters: r0: ref; r1:blk; r2:dmin_lx; r3:extra_info@@@@@@@
    mvn        r4,  #0
    lsl        r4,  r4, #16
    lsr        r4,  r4, #14                          @generate mask: 0x3fffc
    and        r4,  r4, r2, lsl #2                   @r4: lx4
    
    @@@@@@@@@@@@@r3: int *abs_dif_mad_avg = &(htfm_stat->abs_dif_mad_avg);@@@@@
    add        r6,  r3, #4                           @r6: UInt *countbreak = &(htfm_stat->countbreak);
    add        r5,  r3, #72                          @r5: Int *offsetRef = htfm_stat->offsetRef;
    
    mov        r7,  #0                               @r7: i
    VMOV.I64   d6,  #0                               @d6: sad
1:
    lsl        r9,  r7, #2
    ldr        r8,  [r5, r9]                         @r8: offsetRef[i]
    add        r9,  r0, r8                           @r9: p1 = ref + offsetRef[i];
    
    VLD1.8     d0,  [r1]                             @d0: cur_word
    VLD4.8     {d1, d2, d3, d4}, [r9]                @d1: xxxxp1[12]p1[8]p1[4]p1[0]
    add        r9,  r9, r4                           @p1 += lx4;
    VLD4.8     {d2, d3, d4, d5}, [r9]                @d2: xxxxp1[12]p1[8]p1[4]p1[0]
    VZIP.32    d1,  d2                               @d1:p1[12]p1[8]p1[4]p1[0] - p1[12]p1[8]p1[4]p1[0]
    
    VABD.U8     d2, d0, d1
    VPADDL.U8   d2, d2
    VPADDL.U16  d2, d2                              @d2: sad
    VPADD.U32   d6, d6, d2
    
    add        r9,  r9, r4                           @p1 += lx4;
    add        r1,  r1, #8                           @blk += 4;blk += 4;
    
    VLD1.8     d0,  [r1]                             @d0: cur_word
    VLD4.8     {d1, d2, d3, d4}, [r9]                @d1: xxxxp1[12]p1[8]p1[4]p1[0]
    add        r9,  r9, r4                           @p1 += lx4;
    VLD4.8     {d2, d3, d4, d5}, [r9]                @d2: xxxxp1[12]p1[8]p1[4]p1[0]
    VZIP.32    d1,  d2                               @d1:p1[12]p1[8]p1[4]p1[0] - p1[12]p1[8]p1[4]p1[0]
    
    VABD.U8     d2, d0, d1
    VPADDL.U8   d2, d2
    VPADDL.U16  d2, d2                               @d2: sad
    VPADD.U32   d6, d6, d2
    VPADDL.U32  d6, d6
    VMOV.32     r8, d6[0]                            @r8: sad
    
    add        r9,  r9, r4                           @p1 += lx4;
    add        r1,  r1, #8                           @blk += 4;blk += 4;
    
    str        r8,  [fp, r7, lsl #2]                 @saddata[i] = sad;
    
    cmp        r7, #0
    ble        2f
    cmp        r8, r2, lsr #16                       @if ((ULong)sad > ((ULong)dmin_lx >> 16))
    bgt        3f
2:
    add        r7, r7, #1
    cmp        r7, #16
    blt        1b
    
3:
    ldmia      fp,  {r7, r10}                         @r7: saddata[0]; r10:saddata[1]
    add        r10, r10, #1                           @(saddata[1] + 1)
    
    subs       r7,  r7, r10, lsr #1                   @r7: difmad = saddata[0] - ((saddata[1] + 1) >> 1);
    bgt        4f
    mov        r10, #0
    sub        r7,  r10, r7
4:
    ldr        r10, [r3]
    add        r7,  r7, r10
    str        r7,  [r3]                              @(*abs_dif_mad_avg) += ((difmad > 0) ? difmad : -difmad);
    ldr        r10, [r6]
    add        r10, r10, #1
    str        r10, [r6]                              @(*countbreak)++;
    mov        r0, r8
    
    add        sp, fp, #64                            @recover sp
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |AVCAVCSAD_MB_HTFM_Collect|
    
    
    .section .text
    .global	AVCSAD_MB_HTFM
AVCSAD_MB_HTFM:
    stmdb      sp!, {r4 - r12, lr}
    @@@@@@@@input parameters: r0: ref; r1:blk; r2:dmin_lx; r3:extra_info@@@@@@@
    mvn        r4,  #0
    lsl        r4,  r4, #16
    lsr        r4,  r4, #14                          @generate mask: 0x3fffc
    and        r4,  r4, r2, lsl #2                   @r4: lx4
    add        r5,  r3, #128                         @r5: Int *offsetRef = (Int*) extra_info + 32;
    lsr        r6,  r2, #20                          @r6: madstar = (ULong)dmin_lx >> 20;
    
    mov        r10, #0                               @r10: sadstar = 0;
    mov        r7,  #0                               @r7: i
    VMOV.I64   d6,  #0                               @d6: sad
1:
    lsl        r11, r7, #2
    ldr        r8,  [r5, r11]                        @r8: offsetRef[i]
    add        r9,  r0, r8                           @r9: p1 = ref + offsetRef[i];
    
    VLD1.8     d0,  [r1]                             @d0: cur_word
    VLD4.8     {d1, d2, d3, d4}, [r9]                @d1: xxxxp1[12]p1[8]p1[4]p1[0]
    add        r9,  r9, r4                           @p1 += lx4;
    VLD4.8     {d2, d3, d4, d5}, [r9]                @d2: xxxxp1[12]p1[8]p1[4]p1[0]
    VZIP.32    d1,  d2                               @d1:p1[12]p1[8]p1[4]p1[0] - p1[12]p1[8]p1[4]p1[0]
    
    VABD.U8     d2, d0, d1
    VPADDL.U8   d2, d2
    VPADDL.U16  d2, d2                              @d2: sad
    VPADD.U32   d6, d6, d2
    
    add        r9,  r9, r4                           @p1 += lx4;
    add        r1,  r1, #8                           @blk += 4;blk += 4;
    
    VLD1.8     d0,  [r1]                             @d0: cur_word
    VLD4.8     {d1, d2, d3, d4}, [r9]                @d1: xxxxp1[12]p1[8]p1[4]p1[0]
    add        r9,  r9, r4                           @p1 += lx4;
    VLD4.8     {d2, d3, d4, d5}, [r9]                @d2: xxxxp1[12]p1[8]p1[4]p1[0]
    VZIP.32    d1,  d2                               @d1:p1[12]p1[8]p1[4]p1[0] - p1[12]p1[8]p1[4]p1[0]
    
    VABD.U8     d2, d0, d1
    VPADDL.U8   d2, d2
    VPADDL.U16  d2, d2                              @d2: sad
    VPADD.U32   d6, d6, d2
    VPADDL.U32  d6, d6
    VMOV.32     r11, d6[0]                          @r11: sad
    
    add        r9,  r9, r4                           @p1 += lx4;
    add        r1,  r1, #8                           @blk += 4;blk += 4;
    
    add        r10, r10, r6                          @sadstar += madstar;
    
    cmp        r11, r2, lsr #16
    bgt        2f
    ldr        r12, [r3]
    add        r3,  r3, #1
    sub        r12, r10, r12                         @r12: (sadstar - *nrmlz_th++)
    cmp        r11, r12
    bgt        2f
    
    add        r7,  #1
    cmp        r7,  #16
    blt        1b
    mov        r0, r11
    b          3f

2:
    mov        r0, #1
    lsl        r0, #16

3:
    ldmia      sp!, {r4 - r12, pc}
    @ENDP  @ |AVCSAD_MB_HTFM|
    
    .end
    