// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiUtilityNFT.sol";
import "../src/PaymentToken.sol";
import "./mocks/MockSablier.sol";

contract MultiUtilityNFTTest is Test {
    MultiUtilityNFT nft;
    PaymentToken token;
    MockSablier sablier;
    
    address owner = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);
    
    bytes32 phase1Root;
    bytes32 phase2Root;
    bytes32[] phase1Proof;
    bytes32[] phase2Proof;

    function setUp() public {
        vm.startPrank(owner);
        token = new PaymentToken();
        sablier = new MockSablier();
        nft = new MultiUtilityNFT(
            address(token),
            address(sablier),
            0.8 ether,
            1 ether
        );
        
        // Create Merkle tree
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(user1));
        leaves[1] = keccak256(abi.encodePacked(user2));
        phase1Root = buildMerkleTree(leaves);
        phase2Root = keccak256(abi.encodePacked(user2));
        
        nft.setPhase1MerkleRoot(phase1Root);
        nft.setPhase2MerkleRoot(phase2Root);
        
        phase1Proof = generateProof(leaves, 0); // User1 proof
        phase2Proof = generateProof(leaves, 1); // User2 proof
        
        token.transfer(user1, 10 ether);
        token.transfer(user2, 10 ether);
        vm.stopPrank();
    }

    // Phase 1: Valid Merkle Proof
    function test_phase1_valid_mint() public {
        vm.prank(user1);
        nft.mintPhase1(phase1Proof);
        
        assertEq(nft.ownerOf(0), user1);
        assertEq(token.balanceOf(address(nft)), 0);
    }

    // Phase 2: Valid Signature + Proof
    function test_phase2_discount_mint() public {
        nft.advancePhase();
        bytes memory sig = signDiscount(user2);
        
        vm.prank(user2);
        token.approve(address(nft), 0.8 ether);
        nft.mintWithDiscount(sig, phase2Proof);
        
        assertEq(nft.ownerOf(0), user2);
        assertEq(token.balanceOf(address(nft)), 0.8 ether);
    }

    // Edge Cases
    function test_phase1_invalid_proof() public {
        bytes32[] memory invalidProof;
        vm.prank(user1);
        vm.expectRevert("Invalid proof");
        nft.mintPhase1(invalidProof);
    }

    function test_phase2_invalid_signature() public {
        nft.advancePhase();
        bytes memory invalidSig = hex"deadbeef";
        
        vm.prank(user2);
        vm.expectRevert("Invalid signature");
        nft.mintWithDiscount(invalidSig, phase2Proof);
    }

    // Helper Functions
    function buildMerkleTree(bytes32[] memory leaves) internal pure returns (bytes32) {
        uint256 n = leaves.length;
        bytes32[] memory tree = new bytes32[](n * 2);
        
        for (uint i = 0; i < n; i++) {
            tree[n + i] = leaves[i];
        }
        
        for (uint i = n - 1; i > 0; i--) {
            tree[i] = keccak256(abi.encodePacked(tree[i*2], tree[i*2+1]));
        }
        return tree[1];
    }

    function generateProof(bytes32[] memory leaves, uint index) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaves[index == 0 ? 1 : 0];
        return proof;
    }

    function signDiscount(address user) internal returns (bytes memory) {
        bytes32 hash = keccak256(abi.encodePacked(user, 0.8 ether, address(nft)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash); // Owner's private key
        return abi.encodePacked(r, s, v);
    }


    // demo example to be removed
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
}