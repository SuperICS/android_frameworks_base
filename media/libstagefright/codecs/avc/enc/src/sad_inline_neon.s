@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@  __inline int32 sad_4pixel(int32 src1, int32 src2, int32 mask)
@  __inline int32 sad_mb_offset3(uint8 *ref, uint8 *blk, int lx, int dmin)
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  sad_4pixel
sad_4pixel:
    stmdb      sp!, {lr}
    
    VDUP.32    d0,   r0                                     @d0: src1 src1
    VDUP.32    d1,   r1                                     @d1: src2 src2
    VABD.U8    d0,   d0,  d1
    VMOV.32    r0,   d0[0]
    
    ldmia      sp!, {pc}
    @ENDP  @ |sad_4pixel|
    
    
    
    
    .section .text
    .global  sad_mb_offset3
    .global  sad_mb_offset2
    .global  sad_mb_offset1
    .global  simd_sad_mb
sad_mb_offset3:
sad_mb_offset2:
sad_mb_offset1:
simd_sad_mb:
    stmdb      sp!, {r4 - r6, lr}
    
    mov        r5,  #0
    mov        r6,  #16
    
1:
    VLD1.8     {d0, d1},  [r0],  r3                         @d0,d1: K J I H G F E D
    VLD1.8     {d2, d3},  [r1]!                             @d2,d3: x14 x12
    VABD.U8    Q0,   Q0,  Q1
    
    VADDL.U8   Q0,   d0,  d1
    VADDL.U16  Q0,   d0,  d1
    VADD.U32   d0,   d0,  d1
    VPADDL.U32 d0,   d0
    VMOV.32    r4,   d0[0]
    
    add        r5,   r4,  r5
    cmp        r5,   r2
    bgt        2f
    subs       r6,   r6,  #1
    bne        1b
    
2:
    mov       r0,    r5
    ldmia     sp!, {r4 - r6, pc}
    @ENDP  @ |sad_mb_offset3|
    
    .end
    