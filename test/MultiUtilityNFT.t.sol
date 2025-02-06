// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiUtilityNFT.sol";
import "../src/PaymentToken.sol";

contract MockSablier {
    function createStream(address recipient, uint256 depositAmount, address tokenAddress, uint256 startTime, uint256 stopTime) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), depositAmount);
    }
}

contract MultiUtilityNFTTest is Test {
    MultiUtilityNFT nft;
    PaymentToken paymentToken;
    MockSablier sablier;

    address owner = address(1);
    address user1 = address(2);
    address user2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        sablier = new MockSablier();
        nft = new MultiUtilityNFT(
            "TestNFT",
            "TNFT",
            address(paymentToken),
            address(sablier),
            1 ether,
            0.5 ether
        );
        vm.stopPrank();
    }

    function test_Phase1Mint() public {
        // Setup Merkle Tree
        bytes32[] memory leaves = new bytes32[](2);
        leaves[0] = keccak256(abi.encodePacked(owner));
        leaves[1] = keccak256(abi.encodePacked(user1));
        bytes32 root = getRoot(leaves);
        nft.setMerkleRoots(root, bytes32(0));
        nft.setPhase(MultiUtilityNFT.MintPhase.Phase1);

        // Generate Merkle Proof
        bytes32[] memory proof = getProof(leaves, 1);

        vm.prank(user1);
        nft.mintPhase1(proof);
        assertEq(nft.ownerOf(1), user1);
    }

    function test_Phase2Mint() public {
        // Setup Merkle Tree and Phase
        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = keccak256(abi.encodePacked(user1));
        bytes32 root = getRoot(leaves);
        nft.setMerkleRoots(bytes32(0), root);
        nft.setPhase(MultiUtilityNFT.MintPhase.Phase2);

        // Generate Signature
        bytes32 messageHash = keccak256(abi.encodePacked(user1));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Mint
        vm.startPrank(user1);
        paymentToken.approve(address(nft), 0.5 ether);
        nft.mintPhase2(getProof(leaves, 0), signature);
        assertEq(nft.ownerOf(1), user1);
    }

    function getRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        return MerkleProof.processProof(leaves, 0);
    }

    function getProof(bytes32[] memory leaves, uint256 index) internal pure returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaves[index];
        return proof;
    }
}