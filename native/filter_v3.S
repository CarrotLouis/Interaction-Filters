# Called, rather than jumped to, after the native candidate collector.
# Win64 frame has registered UNWIND_INFO. No source/ownership engine calls.
.intel_syntax noprefix
.text
ppb_image:
# Retain the low displacement byte of the existing CALL. Only its upper three
# bytes are changed in one aligned 8-byte compare/exchange at game+0x9A35F8.
.org 0xb0, 0x90
.global ppb_filter
ppb_filter:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40
.global ppb_body
ppb_body:
    mov rbx, rcx
    mov rsi, rdx
    mov edi, r8d
    call QWORD PTR [rip+collect_address]
    mov QWORD PTR [rsp+0x30], rax
    mov r9, QWORD PTR [rip+control_address]
    lock inc DWORD PTR [r9+0x2100]
    cmp DWORD PTR [r9], 1
    jne finish
    test rsi, rsi
    je missing_descriptor
    mov ecx, DWORD PTR [rsi+0x10]
    mov DWORD PTR [r9+0x2240], ecx
    mov eax, DWORD PTR [rsi+0x0c]
    mov DWORD PTR [r9+0x2124], eax
    mov eax, DWORD PTR [rsi]
    mov DWORD PTR [r9+0x212c], eax
    mov eax, DWORD PTR [rsi+4]
    mov DWORD PTR [r9+0x2130], eax
    mov eax, DWORD PTR [rsi+0x14]
    mov DWORD PTR [r9+0x2134], eax
    mov rax, QWORD PTR [rip+player_global_address]
    mov rax, QWORD PTR [rax]
    test rax, rax
    je local_not_ready
    cmp DWORD PTR [rax+0x88], 1
    jne local_not_ready
    mov edx, DWORD PTR [rax+0x3a8]
    mov DWORD PTR [r9+0x2128], edx
    cmp edx, 0x7fff
    je local_not_ready
    cmp ecx, edx
    jne different_actor
    lock inc DWORD PTR [r9+0x2118]
    imul rdi, rdi, 0x880
    add rdi, QWORD PTR [rbx+0x48]
    mov rsi, rdi
    mov rbx, r9
    mov eax, DWORD PTR [rsi+0x808]
    cmp eax, 256
    ja finish
    mov DWORD PTR [rsp+0x20], eax
    mov DWORD PTR [rsp+0x24], 0
    xor edi, edi
next_candidate:
    cmp edi, DWORD PTR [rsp+0x20]
    jae commit_count
    mov rcx, QWORD PTR [rsi+rdi*8+8]
    mov QWORD PTR [rsp+0x28], rcx
    call ppb_classify
    mov DWORD PTR [rbx+0x213c], eax
    cmp eax, 64
    jae type_counted
    lock inc DWORD PTR [rbx+rax*4+0x2140]
type_counted:
    cmp eax, 1
    jne keep_candidate
    lock inc DWORD PTR [rbx+0x2104]
    lock inc DWORD PTR [rbx+0x2108]
    mov DWORD PTR [rbx+0x2120], 1
    lock inc DWORD PTR [rbx+8]
    mov rax, QWORD PTR [rsp+0x28]
    cmp QWORD PTR [rsi], rax
    jne advance
    mov QWORD PTR [rsi], 0
    lock inc DWORD PTR [rbx+0x2138]
    jmp advance
keep_candidate:
    mov eax, DWORD PTR [rsp+0x24]
    mov rdx, QWORD PTR [rsp+0x28]
    mov QWORD PTR [rsi+rax*8+8], rdx
    inc DWORD PTR [rsp+0x24]
advance:
    inc edi
    jmp next_candidate
commit_count:
    mov eax, DWORD PTR [rsp+0x24]
    mov DWORD PTR [rsi+0x808], eax
    mov rcx, QWORD PTR [rsi]
    test rcx, rcx
    je finish
    call ppb_classify
    cmp eax, 1
    jne finish
    mov QWORD PTR [rsi], 0
    lock inc DWORD PTR [rbx+0x2138]
    jmp finish
missing_descriptor:
    lock inc DWORD PTR [r9+0x210c]
    jmp finish
local_not_ready:
    lock inc DWORD PTR [r9+0x2110]
    jmp finish
different_actor:
    lock inc DWORD PTR [r9+0x2114]
finish:
.global ppb_epilogue
ppb_epilogue:
    mov rax, QWORD PTR [rsp+0x30]
    add rsp, 0x40
    pop rdi
    pop rsi
    pop rbx
    ret
.global ppb_wrapper_end
ppb_wrapper_end:
.balign 16, 0x90
# Leaf classifier: current engine candidate pair -> native zone type.
# The native caller consumes these same pairs/rows immediately after returning.
# Unknown layouts/indices/hash chains fail open. No nonvolatile registers touched.
ppb_classify:
    test rcx, rcx
    je unknown_type
    mov r11d, DWORD PTR [rcx+4]
    cmp r11d, 8
    jae unknown_type
    mov edx, DWORD PTR [rcx]
    mov r10, QWORD PTR [rip+interactable_global_address]
    mov r10, QWORD PTR [r10]
    test r10, r10
    je unknown_type
    mov r9d, DWORD PTR [r10+0x14058]
    test r9d, r9d
    je unknown_type
    cmp r9d, 65536
    ja unknown_type
    lea eax, [r9-1]
    test eax, r9d
    jne unknown_type
    dec r9d
    mov r8d, DWORD PTR [r10+0x14060]
    imul r8d, edx
    mov rcx, QWORD PTR [r10+0x14050]
    test rcx, rcx
    je unknown_type
    xor eax, eax
probe:
    and r8d, r9d
    cmp DWORD PTR [rcx+r8*8], edx
    je found
    inc r8d
    inc eax
    cmp eax, 64
    jae unknown_type
    cmp eax, r9d
    jbe probe
    jmp unknown_type
found:
    mov eax, DWORD PTR [rcx+r8*8+4]
    cmp eax, DWORD PTR [r10+0x14040]
    jae unknown_type
    imul rax, rax, 0x370
    mov rcx, QWORD PTR [r10+0x14070]
    test rcx, rcx
    je unknown_type
    add rax, rcx
    cmp r11d, DWORD PTR [rax+0x340]
    jae unknown_type
    imul r11, r11, 0x68
    mov eax, DWORD PTR [rax+r11+0x44]
    ret
unknown_type:
    mov eax, 0xffffffff
    ret
.balign 8, 0x90
player_global_address:       .quad 0x1111111111111111
control_address:             .quad 0x2222222222222222
collect_address:             .quad 0x3333333333333333
interactable_global_address: .quad 0x4444444444444444
.balign 16, 0x90
.global ppb_compare_exchange
ppb_compare_exchange:
    mov rax, r8
    lock cmpxchg QWORD PTR [rcx], rdx
    ret
.balign 4, 0x90
.global ppb_unwind
ppb_unwind:
    .byte 1, 7, 4, 0
    .byte 7, 0x72, 3, 0x70, 2, 0x60, 1, 0x30
.global ppb_function_table
ppb_function_table:
    .long ppb_filter-ppb_image, ppb_wrapper_end-ppb_image, ppb_unwind-ppb_image
