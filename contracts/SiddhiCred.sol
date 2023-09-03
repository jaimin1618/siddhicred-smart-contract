// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SiddhiCred is
    ERC721,
    ERC721URIStorage,
    ERC721Enumerable,
    AccessControl
{
    /*============================================
    Data structures and containers
    ============================================*/
    // constants and namespaces
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER");
    bytes32 public constant EARNER_ROLE = keccak256("EARNER");
    using Counters for Counters.Counter;

    // variables
    address public admin;
    Counters.Counter private _tokenIdCounter;

    // mappings
    // issuer public address => Issuer content Hash CID | updates only when new issuer is created or issuer is removed
    mapping(address => string) public aboutIssuer;
    mapping(address => string) public aboutEarner;

    // list of all token/certificates issued by issuer address | updates when new tokens is issued by issuer or token is revoked by issuer
    mapping(address => uint256[]) issuedTokens;

    // list of all issuers | add / remove when issuer is create or removed
    address[] private issuers;

    // address[] private earners; wait do we need this!

    /*============================================
    contract Constructor - ctor
    ============================================*/
    constructor() ERC721("Siddhi Credential Soulbound NFT", "SCSBNFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        admin = msg.sender;
    }

    /*============================================
    Application modifiers 
    ============================================*/
    modifier onlyCertificateIssuer(uint256 tokenId) {
        bool isFound = false;
        uint256 length = issuedTokens[msg.sender].length;

        // check if token is issued by current issuer or NOT
        for (uint256 i = 0; i < length; ++i) {
            uint256 id = issuedTokens[msg.sender][i];
            if (id == tokenId) {
                isFound = true;
                break;
            }
        }

        require(isFound, "This certificate is not issued by current issuer.");
        _;
    }

    modifier onlyEarnerAccount() {
        require(
            hasRole(EARNER_ROLE, msg.sender),
            "Only earner themself can update their information."
        );
        _;
    }

    /*============================================
    Application events
    ============================================*/
    event IssuerCreated(address issuerWalletAddress, string issuerContentHash);
    event IssuerRemoved(address issuerWalletAddress, string issuerContentHash);
    event IssuerUpdated(address issuerWalletAddress, string issuerContentHash);
    event CertificateIssued(
        address issuerWalletAddress,
        address recipient,
        uint256 tokenId
    );
    event CertificateRevoked(
        address issuerWalletAddress,
        address owner,
        uint256 tokenId
    );

    /*============================================
    Application errors
    ============================================*/
    error IssuerRoleAlreadyAssigned(address issuerWalletAddress);
    error IssuerNotFound(address issuerWalletAddress);
    error TokenNotFound(uint256 tokenId);
    error ProvidedPublicAddressIsUserRole(address walletAddress);
    error ProvidedPublicAddressIsIssueRole(address walletAddress);
    error UserAlreadyOwnsTokens(address walletAddress);

    /*============================================
    ADMIN_ROLE method | manage issuer
    ============================================*/
    function createIssuer(
        address issuerWalletAddress,
        string memory contentHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerRoleAlreadyAssigned(issuerWalletAddress);
        if (hasRole(EARNER_ROLE, issuerWalletAddress))
            revert ProvidedPublicAddressIsUserRole(issuerWalletAddress);
        // User account (wallet public address) cannot HOLD ISSUER Role. No Need, will be removed soon.
        if (balanceOf(issuerWalletAddress) > 0)
            revert ProvidedPublicAddressIsUserRole(issuerWalletAddress);

        _grantRole(ISSUER_ROLE, issuerWalletAddress);
        issuers.push(issuerWalletAddress);
        aboutIssuer[issuerWalletAddress] = contentHash;
        emit IssuerCreated(issuerWalletAddress, contentHash);
    }

    function removeIssuer(
        address issuerWalletAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);

        _revokeRole(ISSUER_ROLE, issuerWalletAddress);

        // remove issuer from issuer[] dynamic container
        bool isFound = false;
        uint256 length = issuers.length;
        address lastIssuer = issuers[length - 1];

        for (uint256 i = 0; i < length; ++i) {
            if (issuers[i] == issuerWalletAddress) {
                issuers[i] = lastIssuer;
                isFound = true;
                break;
            }
        }

        if (isFound) {
            // remove duplicate issuer
            issuers.pop();
        }

        // delete issuer contentHash from mapping
        string memory contentHash = aboutIssuer[issuerWalletAddress];
        emit IssuerRemoved(issuerWalletAddress, contentHash);
        delete aboutIssuer[issuerWalletAddress];
    }

    function updateIssuer(
        address issuerWalletAddress,
        string memory contentHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);

        aboutIssuer[issuerWalletAddress] = contentHash;
        emit IssuerUpdated(issuerWalletAddress, contentHash);
    }

    function getIssuersList()
        external
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (address[] memory)
    {
        return issuers;
    }

    function getFirstToken(
        address to,
        string memory contentHash
    ) external returns (uint256 NFTTokenId) {
        require(
            balanceOf(to) == 0,
            "Cannot mint token! User balance is more than Zero (0) and already owns tokens."
        );

        require(
            !hasRole(ISSUER_ROLE, to),
            "Provided public address is already issuer! Cannot issue certificate to issuer."
        );

        // comment out this line - to let first token issued to guest accounts for showcase.
        require(
            hasRole(EARNER_ROLE, to),
            "Provided public address must register as a user before getting first token."
        );

        // issue first certificate
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, contentHash);

        // update tokens issued by issuer mapping and user owned tokens mapping
        issuedTokens[msg.sender].push(tokenId);

        emit CertificateIssued(msg.sender, to, tokenId);
        return tokenId;
    }

    // /*============================================
    // ISSUER_ROLE methods | Create/Mint/Issue Certificate | Burn/Revoke Certificate
    // ============================================*/
    function issueCertificate(
        address to,
        string memory contentHash
    ) external onlyRole(ISSUER_ROLE) returns (uint256 NFTTokenId) {
        require(
            !hasRole(ISSUER_ROLE, to),
            "Provided public address is already issuer! Cannot issue certificate to issuer."
        );

        require(
            hasRole(EARNER_ROLE, to),
            "Provided public address is NOT REGISTERED as earner, he/she must register as a earner to receive certificate."
        );

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, contentHash);

        // update tokens issued by issuer mapping and user owned tokens mapping
        issuedTokens[msg.sender].push(tokenId);

        emit CertificateIssued(msg.sender, to, tokenId);
        return tokenId;
    }

    function _burn(
        uint256 tokenId
    ) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function burnCertificate(
        uint256 tokenId
    ) external onlyRole(ISSUER_ROLE) onlyCertificateIssuer(tokenId) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert TokenNotFound(tokenId);

        // update tokens issued by issuer mapping
        bool isFound = false;
        uint256 length = issuedTokens[msg.sender].length;
        uint256 lastTokenId = issuedTokens[msg.sender][length - 1];

        for (uint256 i = 0; i < length; ++i) {
            uint256 id = issuedTokens[msg.sender][i];
            if (id == tokenId) {
                issuedTokens[msg.sender][i] = lastTokenId;
                isFound = true;
                break;
            }
        }

        if (isFound) {
            // remove last blank (now duplicated tokenId)
            issuedTokens[msg.sender].pop();
        }

        emit CertificateRevoked(msg.sender, owner, tokenId);
        _burn(tokenId);
    }

    function getIssuedTokenList()
        external
        view
        onlyRole(ISSUER_ROLE)
        returns (uint256[] memory)
    {
        return issuedTokens[msg.sender];
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721Enumerable, ERC721, ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /*============================================
    Things to keep in mind for Overriding _beforeTokenTransfer
    - When from and to are both non-zero, from's tokens will be transferred to to.
    - When from is zero, the tokens will be minted for to => We are using this condition for creating "Soulbound / Mint Only Tokens"
    - When to is zero, from's tokens will be burned.
    - from and to are never both zero.
    - *batchSize is non-zero.
    ============================================*/
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal virtual override(ERC721, ERC721Enumerable) {
        require(
            from == address(0) || to == address(0),
            "Soulbound tokens cannot be transferred, Token transfer is BLOCKED"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /*============================================
    Other PUBLIC methods
    ============================================*/
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function getIssuerInfo(
        address issuerWalletAddress
    ) external view returns (string memory contentHash) {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);
        return aboutIssuer[issuerWalletAddress];
    }

    function getWalletAddressRole(
        address walletAddress
    ) public view returns (string memory role) {
        if (hasRole(DEFAULT_ADMIN_ROLE, walletAddress)) {
            return "ADMIN";
        } else if (hasRole(ISSUER_ROLE, walletAddress)) {
            return "ISSUER";
        } else if (hasRole(EARNER_ROLE, walletAddress)) {
            return "EARNER";
        }

        return "GUEST";
    }

    // get all tokenIds owned by current user
    function tokensOfOwner() public view returns (uint256[] memory tokenId) {
        uint256 tokenCount = balanceOf(msg.sender);
        uint256[] memory tokenIds = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++)
            tokenIds[i] = tokenOfOwnerByIndex(msg.sender, i);

        return tokenIds;
    }

    // upgrade - New user named "EARNER" method
    function registerEarner(string memory cid) external {
        require(
            !hasRole(ISSUER_ROLE, msg.sender),
            "Issuer cannot register as earner."
        );

        require(
            !hasRole(EARNER_ROLE, msg.sender),
            "This account is already registered as earner, cannot re-register it."
        );

        aboutEarner[msg.sender] = cid;
        grantRole(EARNER_ROLE, msg.sender);
    }

    function getEarnerAccountInfo(
        address earnerAddress
    ) external view returns (string memory cid) {
        return aboutEarner[earnerAddress];
    }

    function updateEarnerInfo(string memory newCid) external onlyEarnerAccount {
        aboutEarner[msg.sender] = newCid;
    }

    /*============================================
    Upcoming features - delete account, burn all issued tokens to this account.
    ============================================*/
}
