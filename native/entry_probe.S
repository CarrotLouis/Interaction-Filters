# 0.2.5 diagnostic: SAME CALL site/frame as 0.2.4, NO filtering body.
# Reads only its two patched-in literals and writes private counters.
# RCX/RDX/R8/R9 and XMM arguments reach the original collector unchanged.
.intel_syntax noprefix
.text
ppb_image:
.org 0xb0, 0x90
.global ppb_filter
ppb_filter:
    push rbx
    push rsi
    push rdi
    sub rsp, 0x40
.global ppb_body
ppb_body:
    mov r11, QWORD PTR [rip+control_address]
    lock inc DWORD PTR [r11+0x2244]
    call QWORD PTR [rip+collect_address]
    mov QWORD PTR [rsp+0x30], rax
    mov r11, QWORD PTR [rip+control_address]
    lock inc DWORD PTR [r11+0x2100]
    lock inc DWORD PTR [r11+0x2248]
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
.balign 8, 0x90
control_address: .quad 0x2222222222222222
collect_address: .quad 0x3333333333333333
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
