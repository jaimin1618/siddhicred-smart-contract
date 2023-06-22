// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SiddhiApp is ERC721, ERC721URIStorage, AccessControl {
    address admin;
    mapping(address => string) aboutIssuer;
    using Counters for Counters.Counter;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER");
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Siddhi Credential Soulbound NFT", "SCSBNFT") {
        admin = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
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

    /*============================================
    ADMIN_ROLE method | manage issuer
    ============================================*/
    function createIssuer(
        address issuerWalletAddress,
        string memory contentHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerRoleAlreadyAssigned(issuerWalletAddress);

        aboutIssuer[issuerWalletAddress] = contentHash;
        _grantRole(ISSUER_ROLE, issuerWalletAddress);
        emit IssuerCreated(issuerWalletAddress, contentHash);
    }

    function removeIssuer(address issuerWalletAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);

        string memory contentHash = aboutIssuer[issuerWalletAddress];
        _revokeRole(ISSUER_ROLE, issuerWalletAddress);
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

    /*============================================
    ISSUER_ROLE methods | Create/Mint/Issue Certificate | Burn/Revoke Certificate
    ============================================*/
    function issueCertificate(address to, string memory contentHash)
        external
        onlyRole(ISSUER_ROLE)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, contentHash);
        emit CertificateIssued(msg.sender, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function burnCertificate(uint256 tokenId) external onlyRole(ISSUER_ROLE) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert TokenNotFound(tokenId);
        emit CertificateRevoked(msg.sender, owner, tokenId);
        _burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
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
    ) internal virtual override {
        require(
            from == address(0),
            "Soulbound tokens cannot be transferred, Token transfer is BLOCKED"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /*============================================
    Other PUBLIC methods
    ============================================*/
    function checkIsIssuerRole(address issuerWalletAddress)
        external
        view
        returns (bool isIssuer)
    {
        return hasRole(ISSUER_ROLE, issuerWalletAddress);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function getIssuerInfo(address issuerWalletAddress)
        external
        view
        returns (string memory contentHash)
    {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);
        return aboutIssuer[issuerWalletAddress];
    }

    /*============================================
    Overriding unnecessary inherited methods
    ============================================*/
    function approve(address to, uint256 tokenId)
        public
        virtual
        override(ERC721, IERC721)
    {}

    function grantRole(bytes32 role, address account) public override {}

    function revokeRole(bytes32 role, address account) public override {}

    function renounceRole(bytes32 role, address account) public override {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {}

    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721, IERC721)
    {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {}

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, IERC721)
        returns (address)
    {}

    function getRoleAdmin(bytes32 role)
        public
        view
        virtual
        override
        returns (bytes32)
    {}

    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override
        returns (bool)
    {}

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721, IERC721)
        returns (bool)
    {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract SiddhiApp is ERC721, ERC721URIStorage, AccessControl {
    address admin;
    mapping(address => string) aboutIssuer;
    using Counters for Counters.Counter;

    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER");
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Siddhi Credential Soulbound NFT", "SCSBNFT") {
        admin = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
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

    /*============================================
    ADMIN_ROLE method | manage issuer
    ============================================*/
    function createIssuer(
        address issuerWalletAddress,
        string memory contentHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerRoleAlreadyAssigned(issuerWalletAddress);

        aboutIssuer[issuerWalletAddress] = contentHash;
        _grantRole(ISSUER_ROLE, issuerWalletAddress);
        emit IssuerCreated(issuerWalletAddress, contentHash);
    }

    function removeIssuer(address issuerWalletAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);

        string memory contentHash = aboutIssuer[issuerWalletAddress];
        _revokeRole(ISSUER_ROLE, issuerWalletAddress);
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

    /*============================================
    ISSUER_ROLE methods | Create/Mint/Issue Certificate | Burn/Revoke Certificate
    ============================================*/
    function issueCertificate(address to, string memory contentHash)
        external
        onlyRole(ISSUER_ROLE)
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, contentHash);
        emit CertificateIssued(msg.sender, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function burnCertificate(uint256 tokenId) external onlyRole(ISSUER_ROLE) {
        address owner = ownerOf(tokenId);
        if (owner == address(0)) revert TokenNotFound(tokenId);
        emit CertificateRevoked(msg.sender, owner, tokenId);
        _burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, AccessControl)
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
    ) internal virtual override {
        require(
            from == address(0),
            "Soulbound tokens cannot be transferred, Token transfer is BLOCKED"
        );
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /*============================================
    Other PUBLIC methods
    ============================================*/
    function checkIsIssuerRole(address issuerWalletAddress)
        external
        view
        returns (bool isIssuer)
    {
        return hasRole(ISSUER_ROLE, issuerWalletAddress);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function getIssuerInfo(address issuerWalletAddress)
        external
        view
        returns (string memory contentHash)
    {
        if (!hasRole(ISSUER_ROLE, issuerWalletAddress))
            revert IssuerNotFound(issuerWalletAddress);
        return aboutIssuer[issuerWalletAddress];
    }

    /*============================================
    Overriding unnecessary inherited methods
    ============================================*/
    function approve(address to, uint256 tokenId)
        public
        virtual
        override(ERC721, IERC721)
    {}

    function grantRole(bytes32 role, address account) public override {}

    function revokeRole(bytes32 role, address account) public override {}

    function renounceRole(bytes32 role, address account) public override {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {}

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override(ERC721, IERC721) {}

    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721, IERC721)
    {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override(ERC721, IERC721) {}

    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, IERC721)
        returns (address)
    {}

    function getRoleAdmin(bytes32 role)
        public
        view
        virtual
        override
        returns (bytes32)
    {}

    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override
        returns (bool)
    {}

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721, IERC721)
        returns (bool)
    {}
}
