// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ISablier.sol";

contract MultiUtilityNFT is ERC721, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    enum Phase { Phase1, Phase2, Phase3 }
    Phase public currentPhase;

    bytes32 public phase1MerkleRoot;
    bytes32 public phase2MerkleRoot;

    IERC20 public immutable paymentToken;
    ISablier public immutable sablier;

    uint256 public immutable discountPrice;
    uint256 public immutable fullPrice;

    uint256 private _tokenIdCounter;
    mapping(bytes => bool) public usedSignatures;

    event Minted(address indexed user, uint256 tokenId, Phase phase);
    event VestingStarted(uint256 streamId, uint256 amount);

    constructor(
        address _paymentToken,
        address _sablier,
        uint256 _discountPrice,
        uint256 _fullPrice
    ) ERC721("MultiUtilityNFT", "MUNFT") {
        paymentToken = IERC20(_paymentToken);
        sablier = ISablier(_sablier);
        discountPrice = _discountPrice;
        fullPrice = _fullPrice;
        currentPhase = Phase.Phase1;
    }

    function setPhase1MerkleRoot(bytes32 root) external onlyOwner {
        phase1MerkleRoot = root;
    }

    function setPhase2MerkleRoot(bytes32 root) external onlyOwner {
        phase2MerkleRoot = root;
    }

    function advancePhase() external onlyOwner {
        require(uint(currentPhase) < 2, "Already in Phase3");
        currentPhase = Phase(uint(currentPhase) + 1);
    }

    function mintPhase1(bytes32[] calldata merkleProof) external nonReentrant {
        require(currentPhase == Phase.Phase1, "Not Phase1");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, phase1MerkleRoot, leaf), "Invalid proof");
        _mintNFT();
        emit Minted(msg.sender, _tokenIdCounter - 1, Phase.Phase1);
    }

    function mintWithDiscount(bytes32[] calldata merkleProof, bytes calldata signature) external nonReentrant {
        require(currentPhase == Phase.Phase2, "Not Phase2");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(merkleProof, phase2MerkleRoot, leaf), "Invalid proof");
        require(!usedSignatures[signature], "Signature reused");

        bytes32 messageHash = keccak256(abi.encode(msg.sender, discountPrice, address(this)));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        require(ethSignedMessageHash.recover(signature) == owner(), "Invalid signature");

        usedSignatures[signature] = true;
        paymentToken.transferFrom(msg.sender, address(this), discountPrice);
        _mintNFT();
        emit Minted(msg.sender, _tokenIdCounter - 1, Phase.Phase2);
    }

    function mint() external nonReentrant {
        require(currentPhase == Phase.Phase3, "Not Phase3");
        paymentToken.transferFrom(msg.sender, address(this), fullPrice);
        _mintNFT();
        emit Minted(msg.sender, _tokenIdCounter - 1, Phase.Phase3);
    }

    function startVesting() external onlyOwner {
        require(currentPhase == Phase.Phase3, "Vesting after Phase3");
        uint256 amount = paymentToken.balanceOf(address(this));
        paymentToken.approve(address(sablier), amount);

        ISablier.CreateWithDurations memory params = ISablier.CreateWithDurations({
            sender: address(this),
            cancelable: false,
            transferable: true,
            recipient: owner(),
            totalAmount: uint128(amount),
            asset: paymentToken,
            cliffDuration: 0,
            totalDuration: 365 days
        });

        uint256 streamId = sablier.createWithDurations(params);
        emit VestingStarted(streamId, amount);
    }

    function _mintNFT() private {
        uint256 tokenId = _tokenIdCounter++;
        _safeMint(msg.sender, tokenId);
    }
}