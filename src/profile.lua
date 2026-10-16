-- Steam build 25480438. Each offset is pinned to the native consumer, not a name guess.
return {
    steam_build='25480438',
    exe_sha256='F5FEE03DCFDB2E553A4752C283590950AC13316B376D8196AA556FF0400D5F06',
    game_sha256='2E2C3B7C2500646DADD5F2B4C6E0504DBB7E7896139F64CDDC0D1813C718F51E',
    patch_rva=0x9a0da8, instruction_rva=0x9a0dab,
    resume_rva=0x9a0db0, skip_rva=0x9a0a9c, player_global=0x3326468,
    original='2eae024c8b442440',
    mission_scope={
        game_global=0x3326340,state_offset=0xac21c,mode_global=0x33266a0,
        names={'None','Splash','TitleScreen','Ship','Mission','PrepareShip','PrepareMission','PrepareTestLevel','PrepareDebugMission'},
        pins={
            {rva=0x541409,hex='83b81cc20a0004'},
            {rva=0xab309c,hex='899f1cc20a00'},
            {rva=0xad4c49,hex='8b4840'},
        },
    },
    pins={
        -- Native local-avatar consumer: active local count +0x88 and unit +0x3A8.
        {rva=0x5bd685,hex='488b05dc8dd60283b8880000000074128b90a8030000'},
        -- Candidate producer's frame and registers.
        {rva=0x9a05b0,hex='4c8bdc5553565741554157498daba8feffff4881ec28020000'},
        -- rdx (the descriptor passed by the native caller) is saved at rsp+0x28.
        {rva=0x9a0628,hex='488954242848035948488bca48895c2440'},
        -- r15 is the candidate zone's InteractType at +0x44 (primary = 1).
        {rva=0x9a0cad,hex='4c637a44f30f58d144897c2430'},
        -- r12 addresses the candidate entity/zone pair; r13 the current
        -- Interactable runtime row used to validate a cached support origin.
        {rva=0x9a0b6a,hex='4c8b1df76198024c8da0001c00004e8d2460'},
        {rva=0x9a0bf8,hex='4c69e9700300004d03ab70400100'},
        -- Allowed-types gate, immediately after the one displaced instruction.
        {rva=0x9a0db0,hex='418b907808000085d2742a'},
        -- Original skip restores the loop's state before continuing to next candidate.
        {rva=0x9a0a9c,hex='8b7c24204c8b7c2428'},
        -- Caller: descriptor = rbp, index = ebx, interactor manager = [rsp+0x38].
        {rva=0x9a35eb,hex='488b4c2438448bc3488bd5e8b5cfffff'},
    }
}
