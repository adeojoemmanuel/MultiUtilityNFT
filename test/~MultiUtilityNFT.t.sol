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

    function setUp() public {
        vm.startPrank(owner);
        token = new PaymentToken();
        sablier = new MockSablier();
        nft = new MultiUtilityNFT(
            address(token),
            address(sablier),
            0.8 ether,  // Discount price
            1 ether     // Full price
        );
        
        // Setup Merkle roots
        phase1Root = bytes32(0x123...);
        phase2Root = bytes32(0x456...);
        nft.setPhase1MerkleRoot(phase1Root);
        nft.setPhase2MerkleRoot(phase2Root);
        
        // Fund users
        token.transfer(user1, 10 ether);
        token.transfer(user2, 10 ether);
        vm.stopPrank();
    }

    // Phase 1 Tests
    function test_phase1_mint() public {
        bytes32[] memory proof = new bytes32[](0); // Generate valid proof
        vm.prank(user1);
        nft.mintPhase1(proof);
        assertEq(nft.balanceOf(user1), 1);
    }

    // Phase 2 Tests
    function test_phase2_discount_mint() public {
        nft.advancePhase();
        bytes memory sig = _signDiscount(user2);
        bytes32[] memory proof = new bytes32[](0); // Generate valid proof
        
        vm.prank(user2);
        token.approve(address(nft), 0.8 ether);
        nft.mintWithDiscount(proof, sig);
        
        assertEq(nft.balanceOf(user2), 1);
    }

    // Phase 3 Tests
    function test_public_mint() public {
        nft.advancePhase();
        nft.advancePhase();
        
        vm.prank(user1);
        token.approve(address(nft), 1 ether);
        nft.mint();
        
        assertEq(nft.balanceOf(user1), 1);
    }

    // Vesting Tests
    function test_vesting_flow() public {
        // Setup Phase 3
        nft.advancePhase();
        nft.advancePhase();
        
        // Mint to accumulate funds
        vm.prank(user1);
        token.approve(address(nft), 1 ether);
        nft.mint();

        vm.prank(owner);
        nft.startVesting();
        
        (,, IERC20 asset, uint128 amount,,) = sablier.streams(0);
        assertEq(address(asset), address(token));
        assertEq(amount, 1 ether);
    }

    // Edge Cases
    function test_invalid_merkle_proof() public {
        bytes32[] memory invalidProof;
        vm.prank(user1);
        vm.expectRevert("Invalid proof");
        nft.mintPhase1(invalidProof);
    }

    function test_reused_signature() public {
        nft.advancePhase();
        bytes memory sig = _signDiscount(user2);
        
        vm.startPrank(user2);
        token.approve(address(nft), 1.6 ether);
        nft.mintWithDiscount(new bytes32[](0), sig);
        
        vm.expectRevert("Signature reused");
        nft.mintWithDiscount(new bytes32[](0), sig);
    }

    // Helper Functions
    function _signDiscount(address user) internal returns (bytes memory) {
        bytes32 hash = keccak256(abi.encode(user, 0.8 ether, address(nft)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash); // Owner's private key
        return abi.encodePacked(r, s, v);
    }
}