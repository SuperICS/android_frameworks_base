@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@AVCPaddingEdge, AVCPrepareCurMB, IntraDecisionABE
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
    .section .text
    .global  IntraDecisionABE
IntraDecisionABE:
    stmdb      sp!, {r4 - r8, lr}
    sub        r4,   r1,   r2                       @r4:out = cur - pitch;
    VLD1.8     {d0, d1},  [r4]                      @Q0:out[15] - out[0]
    VLD1.8     {d2, d3},  [r1]                      @Q1:cur[15] - cur[0]
    VABD.U8    Q0,   Q0,   Q1
    VADDL.U8   Q0,   d0,   d1                       @xx xx xx xx-xx xx xx xx
    VADDL.U16  Q0,   d0,   d1                       @xxxx xxxx xxxx xxxx
    VADD.U32   d0,   d0,   d1
    VPADDL.U32 d0,   d0
    VMOV.32    r8,   d0[0]                          @r8:SBE
    
    sub        r4,   r1,   #1                       @r4:out = cur - 1;; r1:cur
    mov        r5,   #16
1:
    ldrb       r6,  [r4], r2
    ldrb       r7,  [r1], r2
    subs       r6,  r6,   r7
    addge      r8,  r8,   r6
    sublt      r8,  r8,   r6
    subs       r5,  r5,   #1
    bgt        1b
    
    ldr        r4,  [r0]                            @r4:*min_cost
    mov        r5,  #8
    mul        r6,  r8,   r5                        @r6:(SBE * 8)
    subs       r7,  r6,   r4
    movge      r0,  #0
    bge        2f
    cmp        r3,  #1
    addeq      r6,  r4,   r6
    asreq      r6,  r6,   #1
    str        r6,  [r0]
    mov        r0,  #1
2:
    ldmia      sp!, {r4 - r8, pc}
    @ENDP  @ |IntraDecisionABE|
    
    
    .section .text
    .global  AVCPaddingEdge
AVCPaddingEdge:
    stmdb      sp!, {r1 - r10, lr}
    ldr        r1,  [r0,  #40]                      @r1:width = refPic->width;
    ldr        r2,  [r0,  #44]                      @r2:height = refPic->height;
    ldr        r3,  [r0,  #48]                      @r3:pitch = refPic->pitch;
    ldr        r4,  [r0,  #4]                       @r4:src = refPic->Sl;
    
    sub        r7,  r1,  #1                         @r7: width-1
    ldrb       r5,  [r4]                            @r5:temp1 = *src;
    ldrb       r6,  [r4,  r7]                       @r6:temp2 = src[width-1];
    VDUP.8     Q0,  r5                              @d0,d1: (temp1 temp1 temp1 temp1)(temp1 temp1 temp1 temp1)
    VDUP.8     Q1,  r6                              @Q1: [temp2,temp2,temp2,temp2]
    
    @@@@@@@@@@@@@@@@@@@@@@@@@r5, r6 available
    sub        r5,  r4,  r3,  lsl #4                @r5:dst = src - (pitch << 4);
    sub        r5,  r5,  #16
    
    VST1.32    {d0, d1},  [r5]!
    
    mov        r6,  r4                              @r6:src
    mov        r8,  r5                              @r8:dst
    mov        r9,  r1                              @r9:width
1:
    VLD1.8     {d0},  [r6]!
    VST1.8     {d0},  [r8]!
    subs       r9,  r9,  #8
    bgt        1b
    
    @@@@@@@@@@@@@@@@@@@@@@@@@r6 r8 r9 available
    add        r5,  r5,  r1                         @r5:(dst += width)
    VST1.32    {d2, d3},  [r5]
    
    sub        r5,  r5,  r1
    sub        r5,  r5,  #16                        @r5:dst = dst - width - 16;
    
    mov        r10,  #15
2:
    mov        r6,  r5                              @r6:dst
    add        r8,  r5,  r3                         @r8:dst + pitch
    mov        r9,  r3                              @r9:pitch
3:
    VLD1.8     {d0},  [r6]!
    VST1.8     {d0},  [r8]!
    subs       r9,  r9,  #8
    bgt        3b
    
    add        r5,  r5,  r3
    subs       r10, r10,  #1
    bgt        2b
    
    add        r9,  r5,  r3                         @r9:(dst - 16)
    add        r5,  r9,  #16                        @r5:dst += (pitch + 16);
    
4:
    ldrb       r6,  [r5]                            @r6:temp1 = *src;
    ldrb       r8,  [r5,  r7]                       @r8:temp2 = src[width-1];
    VDUP.8     Q0,  r6                              @d0,d1: (temp1 temp1 temp1 temp1)(temp1 temp1 temp1 temp1)
    VDUP.8     Q1,  r8                              @Q1: [temp2,temp2,temp2,temp2]
    
    VST1.32    {d0, d1},  [r9]!
    add        r9,  r9,   r1
    VST1.32    {d2, d3},  [r9]
    
    add        r5,  r5,   r3
    sub        r9,  r5,   #16
    
    subs       r2,  r2,   #1
    bgt        4b
    
    
    mov        r2,  #16
5:
    mov        r6,  r9                              @r6:dst
    sub        r7,  r9,  r3                         @r7:dst - pitch
    mov        r8,  r3                              @r8:pitch
6:
    VLD1.8     {d0},  [r7]!
    VST1.8     {d0},  [r6]!
    subs       r8,  r8,  #8
    bgt        6b
    
    add        r9,  r9,  r3
    subs       r2,  r2,  #1
    bgt        5b
    
    ldmia      sp!, {r1 - r10, pc}
    @ENDP  @ |AVCPaddingEdge|
    
    
    .section .text
    .global  AVCPrepareCurMB
AVCPrepareCurMB:
    stmdb      sp!, {r3 - r4, lr}
    ldr        r3,  =10740
    add        r3,  r0,   r3                       @r3:void* tmp = (void*)(encvid->currYMB);
    
    mov        r4,  #16
1:
    VLD1.32    {d0,d1},   [r1],  r2
    VST1.32    {d0,d1},   [r3]!
    subs       r4,  r4,  #1
    bgt        1b
    
    ldmia      sp!, {r3 - r4, pc}
    @ENDP  @ |AVCPrepareCurMB|
    
    