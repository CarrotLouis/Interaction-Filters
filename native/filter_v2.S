# Six independent local-interactor filters; no calls into Lua or the engine.
# Control: mask +0; sequence +4; six counters +8; origin count +32;
# entries +64, stride16: entity u32, origin u32 (own1/team2/field3), record u64.
# Diagnostic words at +0x2100, beyond the complete source cache. No engine calls.
.intel_syntax noprefix
.text
.global ppb_filter
ppb_filter:
    mov r8, QWORD PTR [rsp+0x40]
    pushfq
    push rax
    push rcx
    push rdx
    push r9
    push r10
    push r11
    mov rax, QWORD PTR [rip+control_address]
    lock inc DWORD PTR [rax+0x2100] # visits
    mov DWORD PTR [rax+0x213c], r15d # last type, including unsupported types
    mov ecx, r15d
    cmp ecx, 64
    jae type_counted
    lock inc DWORD PTR [rax+rcx*4+0x2140]
type_counted:
    cmp r15d, 1
    jne primary_counted
    lock inc DWORD PTR [rax+0x2104]
primary_counted:
    cmp DWORD PTR [rax], 0
    je pass
    cmp r15d, 1
    je primary
    cmp r15d, 3
    je support
    cmp r15d, 11
    je bottle
    cmp r15d, 10
    je sample
    cmp r15d, 48
    je info
    jmp pass
primary:
    xor edx, edx
    jmp enabled
bottle:
    mov edx, 3
    jmp enabled
sample:
    mov edx, 4
    jmp enabled
info:
    mov edx, 5
    jmp enabled
support:
    test DWORD PTR [rax], 6
    je pass
    mov r10d, DWORD PTR [rax+4]
    test r10d, 1
    jne pass
    mov r9d, DWORD PTR [rax+32]
    cmp r9d, 512
    ja pass
    test r9d, r9d
    je pass
    lea r11, [rax+64]
    mov ecx, DWORD PTR [r12]
find_source:
    cmp DWORD PTR [r11], ecx
    jne next_source
    cmp QWORD PTR [r11+8], r13
    jne pass
    mov edx, DWORD PTR [r11+4]
    cmp r10d, DWORD PTR [rax+4]
    jne pass
    cmp edx, 2
    je team
    cmp edx, 3
    jne pass
    mov edx, 2
    jmp enabled
team:
    mov edx, 1
    jmp enabled
next_source:
    add r11, 16
    dec r9d
    jne find_source
    jmp pass
enabled:
    bt DWORD PTR [rax], edx
    jnc pass
    mov r11d, edx
    lock inc DWORD PTR [rax+0x2108] # enabled candidates
    mov DWORD PTR [rax+0x2120], r15d
    mov r10, rax
    mov rax, QWORD PTR [rsp+0x60] # rsp+0x28 before seven saved words
    test rax, rax
    je missing_descriptor
    mov ecx, DWORD PTR [rax+0x0c]
    mov DWORD PTR [r10+0x2124], ecx # diagnostic unit handle
    mov ecx, DWORD PTR [rax+0x10]
    mov DWORD PTR [r10+0x2240], ecx # actual avatar network ID
    mov edx, DWORD PTR [rax]
    mov DWORD PTR [r10+0x212c], edx
    mov edx, DWORD PTR [rax+4]
    mov DWORD PTR [r10+0x2130], edx
    mov edx, DWORD PTR [rax+0x14]
    mov DWORD PTR [r10+0x2134], edx
    mov r9, rax
    mov rax, QWORD PTR [rip+player_global_address]
    mov rax, QWORD PTR [rax]
    test rax, rax
    je local_not_ready
    cmp DWORD PTR [rax+0x88], 1 # native active local-player count
    jne local_not_ready
    mov edx, DWORD PTR [rax+0x3a8]
    mov DWORD PTR [r10+0x2128], edx
    cmp edx, 0x7fff
    je local_not_ready
    cmp ecx, edx
    jne different_actor
    lock inc DWORD PTR [r10+0x2118] # exact current local avatar NETWORK ID
    # These old assumptions are diagnostic only. Network identity, rather than a
    # blueprint hash or network authority bit, establishes the local interactor.
    cmp DWORD PTR [r9], 0x294dfa97
    jne legacy_rejected
    cmp DWORD PTR [r9+4], 0x4d1c334d
    jne legacy_rejected
    test BYTE PTR [r9+0x14], 1
    jne local_candidate
legacy_rejected:
    lock inc DWORD PTR [r10+0x211c]
local_candidate:
    cmp QWORD PTR [r8], r12
    jne counted
    mov QWORD PTR [r8], 0
    lock inc DWORD PTR [r10+0x2138]
counted:
    mov rax, QWORD PTR [rip+control_address]
    lock inc DWORD PTR [rax+r11*4+8]
    pop r11
    pop r10
    pop r9
    pop rdx
    pop rcx
    pop rax
    popfq
    jmp QWORD PTR [rip+skip_address]
missing_descriptor:
    lock inc DWORD PTR [r10+0x210c]
    jmp pass
local_not_ready:
    lock inc DWORD PTR [r10+0x2110]
    jmp pass
different_actor:
    lock inc DWORD PTR [r10+0x2114]
pass:
    pop r11
    pop r10
    pop r9
    pop rdx
    pop rcx
    pop rax
    popfq
    jmp QWORD PTR [rip+resume_address]
.balign 8, 0x90
player_global_address: .quad 0x1111111111111111
control_address:       .quad 0x2222222222222222
skip_address:          .quad 0x3333333333333333
resume_address:        .quad 0x4444444444444444
.balign 16, 0x90
.global ppb_compare_exchange
ppb_compare_exchange:
    mov rax, r8
    lock cmpxchg QWORD PTR [rcx], rdx
    ret
