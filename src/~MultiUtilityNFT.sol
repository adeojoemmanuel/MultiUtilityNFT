    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
    import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
    import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
    import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";
    import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    interface ISablier {
        function createStream(address recipient, uint256 depositAmount, address tokenAddress, uint256 startTime, uint256 stopTime) external;
    }

    contract MultiUtilityNFT is ERC721, Ownable, ReentrancyGuard {
        using ECDSA for bytes32;

        enum MintPhase { Phase1, Phase2, Phase3 }
        MintPhase public currentPhase;

        bytes32 public phase1MerkleRoot;
        bytes32 public phase2MerkleRoot;
        IERC20 public paymentToken;
        ISablier public sablier;

        uint256 public fullPrice;
        uint256 public discountedPrice;
        uint256 private _tokenIdCounter = 1;

        mapping(bytes32 => bool) public usedSignatures;

        event Minted(address indexed user, uint256 tokenId, MintPhase phase, uint256 price);

        constructor(
            string memory name,
            string memory symbol,
            address _paymentToken,
            address _sablier,
            uint256 _fullPrice,
            uint256 _discountedPrice
        ) ERC721(name, symbol) {
            paymentToken = IERC20(_paymentToken);
            sablier = ISablier(_sablier);
            fullPrice = _fullPrice;
            discountedPrice = _discountedPrice;
        }

        function setPhase(MintPhase phase) external onlyOwner {
            currentPhase = phase;
        }

        function setMerkleRoots(bytes32 root1, bytes32 root2) external onlyOwner {
            phase1MerkleRoot = root1;
            phase2MerkleRoot = root2;
        }

        function mintPhase1(bytes32[] calldata proof) external nonReentrant {
            require(currentPhase == MintPhase.Phase1, "Not Phase 1");
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(proof, phase1MerkleRoot, leaf), "Invalid proof");
            _mintNFT(msg.sender, 0);
        }

        function mintPhase2(bytes32[] calldata proof, bytes memory signature) external nonReentrant {
            require(currentPhase == MintPhase.Phase2, "Not Phase 2");
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(proof, phase2MerkleRoot, leaf), "Invalid proof");
            
            bytes32 messageHash = keccak256(abi.encodePacked(msg.sender));
            bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
            address signer = ethSignedMessageHash.recover(signature);
            require(signer == owner(), "Invalid signature");
            require(!usedSignatures[messageHash], "Signature reused");
            usedSignatures[messageHash] = true;

            paymentToken.transferFrom(msg.sender, address(this), discountedPrice);
            _mintNFT(msg.sender, discountedPrice);
        }

        function mintPhase3() external nonReentrant {
            require(currentPhase == MintPhase.Phase3, "Not Phase 3");
            paymentToken.transferFrom(msg.sender, address(this), fullPrice);
            _mintNFT(msg.sender, fullPrice);
        }

        function createVestingStream() external onlyOwner {
            uint256 amount = paymentToken.balanceOf(address(this));
            paymentToken.approve(address(sablier), amount);
            sablier.createStream(owner(), amount, address(paymentToken), block.timestamp, block.timestamp + 365 days);
        }

        function _mintNFT(address to, uint256 price) private {
            uint256 tokenId = _tokenIdCounter++;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId, currentPhase, price);
        }
    }