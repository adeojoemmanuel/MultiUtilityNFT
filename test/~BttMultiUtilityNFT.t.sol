// File: test/MultiUtilityNFT.t.sol
function test_btt_coverage() public {
    // Branch 1: Valid Phase 1 → Valid Phase 2 → Valid Phase 3
    test_phase1_mint();
    nft.advancePhase();
    test_phase2_discount_mint();
    nft.advancePhase();
    test_public_mint();
    test_vesting_flow();

    // Branch 2: Invalid Phase 1 → Skip to Phase 3
    test_invalid_merkle_proof();
    vm.prank(owner);
    nft.advancePhase();
    nft.advancePhase();
    test_public_mint();

    // Branch 3: Phase 2 Signature Reuse
    nft.advancePhase();
    test_reused_signature();
}