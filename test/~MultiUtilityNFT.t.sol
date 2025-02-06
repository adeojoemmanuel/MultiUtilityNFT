// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/MultiUtilityNFT.sol";
import "../src/PaymentToken.sol";

contract MockSablier {
    function createStream(
        address recipient,
        uint256 depositAmount,
        address tokenAddress,
        uint256 startTime,
        uint256 stopTime
    ) external {
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), depositAmount);
    }
}

contract MultiUtilityNFTTest is Test {
    MultiUtilityNFT nft;
    PaymentToken paymentToken;
    MockSablier sablier;

    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        vm.startPrank(owner);
        paymentToken = new PaymentToken();
        sablier = new MockSablier();
        nft = new MultiUtilityNFT("TestNFT", "TNFT", address(paymentToken), address(sablier), 1 ether, 0.5 ether);
        vm.stopPrank();
    }

    function test_Phase1Mint() public {
        bytes32 leafOwner = keccak256(abi.encodePacked(owner));
        bytes32 leafUser1 = keccak256(abi.encodePacked(user1));

        bytes32 root = keccak256(abi.encodePacked(leafOwner, leafUser1));

        // Impersonate owner
        vm.startPrank(owner);
        nft.setMerkleRoots(root, bytes32(0));
        nft.setPhase(MultiUtilityNFT.MintPhase.Phase1);
        vm.stopPrank();

        // The proof that user1 is the sibling leaf
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leafOwner;

        // user1 mints
        vm.prank(user1);
        nft.mintPhase1(proof);
        assertEq(nft.ownerOf(1), user1);
    }

    function test_Phase2Mint() public {
        bytes32 leafUser1 = keccak256(abi.encodePacked(user1));
        bytes32 root = leafUser1;

        // Impersonate owner
        vm.startPrank(owner);
        nft.setMerkleRoots(bytes32(0), root);
        nft.setPhase(MultiUtilityNFT.MintPhase.Phase2);
        vm.stopPrank();

        vm.startPrank(owner);
        // Transfer 0.5 ether (500000000000000000 wei) to user1.
        paymentToken.transfer(user1, 0.5 ether);
        vm.stopPrank();

        // Compute the message hash expected by the contract.
        bytes32 messageHash = keccak256(abi.encodePacked(user1));
        // Sign the message with the private key 1
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        //  Merkle proof is empty.
        bytes32[] memory proof = new bytes32[](0);

        // user1 approves the NFT contract to spend 0.5 ether worth of tokens.
        vm.startPrank(user1);
        paymentToken.approve(address(nft), 0.5 ether);
        nft.mintPhase2(proof, signature);
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user1);
    }

    function test_Phase3Mint() public {
        vm.startPrank(owner);
        nft.setPhase(MultiUtilityNFT.MintPhase.Phase3);
        vm.stopPrank();

        // transfer  1 ether to user2
        vm.startPrank(owner);
        paymentToken.transfer(user2, 1 ether);
        vm.stopPrank();

        // user2 approves the NFT contract to spend 1 ether worth of tokens.
        vm.startPrank(user2);
        paymentToken.approve(address(nft), 1 ether);
        nft.mintPhase3();
        vm.stopPrank();

        assertEq(nft.ownerOf(1), user2);
        assertEq(paymentToken.balanceOf(address(nft)), 1 ether);
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
