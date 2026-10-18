-- Steam build 25480438. Each offset is pinned to the native consumer, not a name guess.
return {
    steam_build='25480438',
    exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
    game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E',
    player_global=0x3326468, interactable_global=0x3326d68,
    mission_scope={
        game_global=0x3326340,state_offset=0xac21c,mode_global=0x33266a0,
        names={'None','Splash','TitleScreen','Ship','Mission','PrepareShip','PrepareMission','PrepareTestLevel','PrepareDebugMission'},
        pins={
            {rva=0x541409,hex='83b81cc20a0004'},
            {rva=0xab309c,hex='899f1cc20a00'},
            {rva=0xad4c49,hex='8b4840'},
        },
    },
    cache={interactor_global=0x33269a0,invalid_request_target=0x3483c4c,slots=2048,max_actors=256,max_targets=16384,
        max_candidates=256,max_hash=65536,max_probes=128},
    pins={
        {rva=0x976fe9,hex='4c8d9900400000'}, -- lea r11, [rcx + 0x4000]
        {rva=0x976ff7,hex='41b900080000'}, -- mov r9d, 0x800
        {rva=0x9a34f5,hex='8b055107ae02'}, -- mov eax, dword ptr [rip + 0x2ae0751]
        {rva=0x9a34fb,hex='398620080000'}, -- cmp dword ptr [rsi + 0x820], eax
        {rva=0x9a35d9,hex='8b056d06ae02'}, -- mov eax, dword ptr [rip + 0x2ae066d]
        {rva=0x9a35df,hex='398620080000'}, -- cmp dword ptr [rsi + 0x820], eax
        {rva=0x97700d,hex='48898900400100'}, -- mov qword ptr [rcx + 0x14000], rcx
        {rva=0x977017,hex='44898908400100'}, -- mov dword ptr [rcx + 0x14008], r9d
        {rva=0x97701e,hex='c7810c400100ffffffff'}, -- mov dword ptr [rcx + 0x1400c], 0xffffffff
        {rva=0x977028,hex='c7811040010002000000'}, -- mov dword ptr [rcx + 0x14010], 2
        {rva=0x97705d,hex='4d899818400100'}, -- mov qword ptr [r8 + 0x14018], r11
        {rva=0x977068,hex='49c780204001000000803d'}, -- mov qword ptr [r8 + 0x14020], 0x3d800000
        {rva=0x977080,hex='c700ffffffff'}, -- mov dword ptr [rax], 0xffffffff
        {rva=0x977086,hex='488d4014'}, -- lea rax, [rax + 0x14]
        {rva=0x97708a,hex='4983e901'}, -- sub r9, 1
        {rva=0x977b9d,hex='4803b970400100'}, -- add rdi, qword ptr [rcx + 0x14070]
        {rva=0x977be5,hex='894740'}, -- mov dword ptr [rdi + 0x40], eax
        {rva=0x977bfd,hex='89a904e00000'}, -- mov dword ptr [rcx + 0xe004], ebp
        {rva=0x977c08,hex='898100e00000'}, -- mov dword ptr [rcx + 0xe000], eax
        {rva=0x173529e,hex='8b6924'}, -- mov ebp, dword ptr [rcx + 0x24]
        {rva=0x17352df,hex='488d0480'}, -- lea rax, [rax + rax*4]
        {rva=0x17352e3,hex='44395c820c'}, -- cmp dword ptr [rdx + rax*4 + 0xc], r11d
        {rva=0x173535a,hex='896cbb10'}, -- mov dword ptr [rbx + rdi*4 + 0x10], ebp
        {rva=0x1735364,hex='44897cbb0c'}, -- mov dword ptr [rbx + rdi*4 + 0xc], r15d
        {rva=0x977e2a,hex='4f8d0c40'}, -- lea r9, [r8 + r8*2]
        {rva=0x977e2e,hex='4339848f00e00000'}, -- cmp dword ptr [r15 + r9*4 + 0xe000], eax
        {rva=0x977e60,hex='488932'}, -- mov qword ptr [rdx], rsi
        {rva=0x977eb1,hex='498b8718400100'}, -- mov rax, qword ptr [r15 + 0x14018]
        {rva=0x977ee2,hex='89440b0c'}, -- mov dword ptr [rbx + rcx + 0xc], eax
        {rva=0x977ee6,hex='42c7443540ffffffff'}, -- mov dword ptr [rbp + r14 + 0x40], 0xffffffff
        {rva=0x978435,hex='488d0c92'}, -- lea rcx, [rdx + rdx*4]
        {rva=0x9a34b6,hex='4869f180080000'}, -- imul rsi, rcx, 0x880
        {rva=0x9a34c1,hex='48037248'}, -- add rsi, qword ptr [rdx + 0x48]
        {rva=0x9a34cf,hex='80be3408000000'}, -- cmp byte ptr [rsi + 0x834], 0
        {rva=0x9a35f6,hex='e8b5cfffff'}, -- call 0x9a05b0
        {rva=0x9a0cad,hex='4c637a44'}, -- movsxd r15, dword ptr [rdx + 0x44]
        {rva=0x9a2627,hex='44887660'}, -- mov byte ptr [rsi + 0x60], r14b
        {rva=0x9a262b,hex='807e6600'}, -- cmp byte ptr [rsi + 0x66], 0
        {rva=0x9a2637,hex='450f2fd5'}, -- comiss xmm10, xmm13
        {rva=0x9a264c,hex='4c896db8'}, -- mov qword ptr [rbp - 0x48], r13
        {rva=0x9a2655,hex='f3450f11542408'}, -- movss dword ptr [r12 + 8], xmm10
        {rva=0x9a268c,hex='4d8964c008'}, -- mov qword ptr [r8 + rax*8 + 8], r12
        {rva=0x9a286b,hex='498911'}, -- mov qword ptr [r9], rdx
        {rva=0x9a0db0,hex='418b9078080000'}, -- mov edx, dword ptr [r8 + 0x878]
        {rva=0x9a0dd0,hex='453bbc8838080000'}, -- cmp r15d, dword ptr [r8 + rcx*4 + 0x838]
        {rva=0x5bd685,hex='488b05dc8dd60283b8880000000074128b90a8030000'},
        {rva=0x60c6f2,hex='c7842ba8030000ff7f0000'},
    }
}
