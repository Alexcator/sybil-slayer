// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

/**
 * @title AntiSybil
 * @dev The AntiSybil contract is an ERC721 token contract with additional functionality for managing anti-sybil status.
 */
contract AntiSybil is
    ERC721URIStorageUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    EIP712Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    /*#########################
    ##        Structs        ##
    ##########################*/

    /**
     * @dev The Score struct represents a user's score.
     * @param tokenId The token id with score for the specified address.
     * @param updated The timestamp when the score was last updated for the specified address.
     * @param value The score for the specified address.
     */
    struct Score {
        uint256 tokenId;
        uint256 updated;
        uint16 value;
    }

    /*#########################
    ##       Variables       ##
    ##########################*/

    string private _baseUri;
    uint16 private _calcModelsCount;
    uint16 private _sybilThreshold;

    /*#########################
    ##        Mappings       ##
    ##########################*/

    /**
     * @dev A mapping of token id to calculation model.
     */
    mapping(uint256 => uint16) public tokenIdToCalcModel;

    /**
     * @dev A mapping of token id to chain id.
     */
    mapping(uint256 => uint256) public tokenIdToChainId;

    /**
     * @dev A mapping of calculation model to mint count used.
     */
    mapping(uint16 => uint256) public calculationModelToMintCountUsed;

    /**
     * @dev A mapping of addresses, chains and calculation methods to scores.
     */
    mapping(address => mapping(uint256 => mapping(uint16 => Score)))
        private _score;

    /**
     * @dev A mapping of addresses to nonces for replay protection.
     */
    mapping(address => uint256) private _nonce;

    /**
     * @dev A mapping of wallet to its token ids.
     */
    mapping(address => uint256[]) private _walletToTokenIds;

    /*#########################
    ##        Modifiers      ##
    ##########################*/

    /**
     * @dev Emitted when a score is minted or changed.
     * @param tokenId The changed token id.
     * @param owner The address to which the score is being changed.
     * @param score The score being changed.
     * @param calculationModel The scoring calculation model.
     * @param chainId The blockchain id in which the score was calculated.
     */
    event ChangedScore(
        uint256 indexed tokenId,
        address indexed owner,
        uint16 score,
        uint16 calculationModel,
        uint256 chainId,
        string metadataUrl
    );

    /**
     * @dev Emitted when the base URI is changed.
     * @param baseUri The new base URI.
     */
    event ChangedBaseURI(string indexed baseUri);

    /**
     * Emitted when the calculation models count is changed.
     */
    event ChangedCalculationModelsCount(uint256 indexed calcModelsCount);

    /*#########################
    ##      Constructor      ##
    ##########################*/

    /**
     * @dev Constructor for the AntiSybil ERC721Upgradeable contract.
     * @param initialCalcModelsCount The initial scoring calculation models count.
     * Initializes the token ID counter to zero and sets the initial minting fee.
     */
    function initialize(
        uint16 initialCalcModelsCount
    ) public initializer {
        __ERC721_init("AntiSybil", "ASS");
        __EIP712_init("ASS", "1.0");
        __Ownable_init();

        _tokenIds.increment();
        require(
            initialCalcModelsCount > 0,
            "constructor: initialCalcModelsCount should be greater than 0"
        );
        _calcModelsCount = initialCalcModelsCount;
    }

    /*#########################
    ##    Write Functions    ##
    ##########################*/

    /**
     * @dev Sets the score for the calling address.
     * @param signature The signature used to verify the message.
     * @param score The score being set.
     * @param calculationModel The scoring calculation model.
     * @param deadline The deadline for submitting the transaction.
     * @param metadataUrl The URI for the token metadata.
     * @param chainId The blockchain id in which the score was calculated.
     */
    function setScore(
        bytes calldata signature,
        uint16 score,
        uint16 calculationModel,
        uint256 deadline,
        string calldata metadataUrl,
        uint256 chainId
    ) external payable whenNotPaused {
        require(score <= 10000, "setScore: Score must be less than 10000");
        require(
            block.timestamp <= deadline,
            "setScore: Signed transaction expired"
        );
        require(
            calculationModel < _calcModelsCount,
            "setScore: calculationModel should be less than calculation model count"
        );

        // Verify the signer of the message
        bytes32 messageHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "SetScoreMessage(uint16 score,uint16 calculationModel,address to,uint256 nonce,uint256 deadline,bytes32 metadataUrl,uint256 chainId)"
                    ),
                    score,
                    calculationModel,
                    msg.sender,
                    _nonce[msg.sender]++,
                    deadline,
                    keccak256(bytes(metadataUrl)),
                    chainId
                )
            )
        );

        address signer = ECDSAUpgradeable.recover(messageHash, signature);
        require(
            signer == owner() && signer != address(0),
            "setScore: Invalid signature"
        );

        bool isNewScore = false;
        Score storage scoreStruct = _score[msg.sender][chainId][
            calculationModel
        ];
        if (scoreStruct.updated == 0) {
            isNewScore = true;
            scoreStruct.tokenId = _tokenIds.current();
        }

        uint256 tokenId = scoreStruct.tokenId;
        scoreStruct.updated = block.timestamp;
        if (scoreStruct.value != score) {
            scoreStruct.value = score;
        }

        if (isNewScore) {
            _safeMint(msg.sender, tokenId);
            _tokenIds.increment();
            ++calculationModelToMintCountUsed[calculationModel];

            tokenIdToCalcModel[tokenId] = calculationModel;
            tokenIdToChainId[tokenId] = chainId;
            _walletToTokenIds[msg.sender].push(tokenId);
        }

        _setTokenURI(tokenId, metadataUrl);

        emit ChangedScore(
            tokenId,
            msg.sender,
            score,
            calculationModel,
            chainId,
            metadataUrl
        );
    }

    /**
     * @dev Sets the sybil threshold.
     * @param sybilThreshold The sybil threshold.
     * @notice Only the contract owner can call this function.
     * @notice
     */
    function setSybilThreshold(uint16 sybilThreshold) external onlyOwner {
        _sybilThreshold = sybilThreshold;
    }

    /**
     * @dev Pauses the contract.
     * See {Pausable-_pause}.
     * Can only be called by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     * See {Pausable-_unpause}.
     * Can only be called by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Changes the base URI for token metadata.
     * @param baseUri The new base URI.
     */
    function setBaseUri(string memory baseUri) external onlyOwner {
        _baseUri = baseUri;

        emit ChangedBaseURI(baseUri);
    }

    /**
     * @dev Sets the number of scoring calculation models.
     * @param calcModelsCount The number of scoring calculation models to set.
     */
    function setCalcModelsCount(uint16 calcModelsCount) external onlyOwner {
        require(
            calcModelsCount > 0,
            "setCalcModelsCount: calcModelsCount should be greater than 0"
        );
        _calcModelsCount = calcModelsCount;

        emit ChangedCalculationModelsCount(calcModelsCount);
    }

    /*#########################
    ##    Read Functions    ##
    ##########################*/

    /**
     * Check if wallet is sybil.
     * @param blockchainId The blockchain id in which the score was calculated.
     * @param calcModel The scoring calculation model.
     */
    function isSybil(
        uint256 blockchainId,
        uint16 calcModel
    ) external view returns (bool) {
        Score storage scoreStruct = _score[msg.sender][blockchainId][
            calcModel
        ];
        return scoreStruct.value <= _sybilThreshold;
    }

    /**
     * @dev Get the current token id.
     * @return The current token id.
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev Returns the score and associated metadata for a given address.
     * @param addr The address to get the score for.
     * @param blockchainId The blockchain id in which the score was calculated.
     * @param calcModel The scoring calculation model.
     * @return score The score for the specified address.
     * @return updated The timestamp when the score was last updated for the specified address.
     * @return tokenId The token id with score for the specified address.
     * @return calculationModel The scoring calculation model.
     * @return chainId The blockchain id in which the score was calculated.
     * @return owner The score owner.
     */
    function getScore(
        address addr,
        uint256 blockchainId,
        uint16 calcModel
    )
        external
        view
        returns (
            uint16 score,
            uint256 updated,
            uint256 tokenId,
            uint16 calculationModel,
            uint256 chainId,
            address owner
        )
    {
        Score storage scoreStruct = _score[addr][blockchainId][calcModel];

        score = scoreStruct.value;
        updated = scoreStruct.updated;
        tokenId = scoreStruct.tokenId;
        calculationModel = calcModel;
        chainId = blockchainId;
        owner = addr;
    }

    /**
     * @dev Returns the score and associated metadata for a given token id.
     * @param id The token id to get the score for.
     * @return score The score for the specified address.
     * @return updated The timestamp when the score was last updated for the specified address.
     * @return tokenId The token id with score for the specified address.
     * @return calculationModel The scoring calculation model.
     * @return chainId The blockchain id in which the score was calculated.
     * @return owner The score owner.
     */
    function getScoreByTokenId(
        uint256 id
    )
        external
        view
        returns (
            uint16 score,
            uint256 updated,
            uint256 tokenId,
            uint16 calculationModel,
            uint256 chainId,
            address owner
        )
    {
        address scoreOwner = ownerOf(id);
        calculationModel = tokenIdToCalcModel[id];
        chainId = tokenIdToChainId[id];

        Score storage scoreStruct = _score[scoreOwner][chainId][
            calculationModel
        ];

        score = scoreStruct.value;
        updated = scoreStruct.updated;
        tokenId = scoreStruct.tokenId;
        owner = scoreOwner;
    }

    /**
     * @dev Returns the token IDs associated with a given address.
     * @param addr The address for which to retrieve the token IDs.
     * @return An array of token IDs owned by the specified address.
     */
    function getTokenIds(
        address addr
    ) external view returns (uint256[] memory) {
        require(_tokenIds.current() > 0, "getTokenIds: No tokens minted");

        return _walletToTokenIds[addr];
    }

    /**
     * @dev Returns the current sybil threshold.
     * @return The current sybil threshold.
     * @notice Only the contract owner can call this function.
     */
    function getSybilThreshold() external view returns (uint256) {
        return _sybilThreshold;
    }

    /**
     * @dev Returns the base URI of the token. This method is called internally by the {tokenURI} method.
     * @return A string containing the base URI of the token.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev Returns an URI for a given token ID.
     * This method is called by the {tokenURI} method from ERC721Upgradeable contract, which in turn can be called by clients to get metadata.
     * @param tokenId The token ID to query for the URI.
     * @return A string containing the URI for the given token ID.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Returns the number of scoring calculation models.
     * @return The number of scoring calculation models.
     */
    function getCalcModelsCount() external view returns (uint16) {
        return _calcModelsCount;
    }

    /**
     * @dev Returns the nonce value for the calling address.
     * @param addr The address to get the nonce for.
     * @return The nonce value for the calling address.
     */
    function getNonce(address addr) external view returns (uint256) {
        return _nonce[addr];
    }

    /**
     * @dev Hook that is called before any token transfer.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param tokenId The ID of the token being transferred.
     * @param batchSize The batch size.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721Upgradeable) {
        require(
            from == address(0),
            "NonTransferrableERC721Token: AntiSybil data can't be transferred."
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}