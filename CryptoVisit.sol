// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * CryptoVisit — Loyalty Token for Cafe Visits
 * Built on Base. Each cafe visit = CVT tokens for the customer.
 *
 * Flow:
 *   1. Owner registers a cafe (cafe wallet address)
 *   2. Cafe generates a QR code linking to the dApp
 *   3. Customer scans QR → calls claimVisit(cafeAddress)
 *   4. Customer receives CVT tokens
 *   5. Tokens can be redeemed at the cafe for discounts
 */
contract CryptoVisit {

    // ─── Token metadata ───────────────────────────────────────────────────────
    string public constant name     = "CryptoVisit Token";
    string public constant symbol   = "CVT";
    uint8  public constant decimals = 18;

    uint256 public totalSupply;

    // ─── State ────────────────────────────────────────────────────────────────
    address public owner;

    /// @notice hard cap — no more than 100,000,000 CVT will ever exist
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18;

    /// @notice tokens minted per visit (10 CVT)
    uint256 public constant TOKENS_PER_VISIT = 10 * 10**18;

    /// @notice minimum seconds between two visits to the same cafe by the same wallet
    uint256 public constant VISIT_COOLDOWN = 4 hours;

    struct Cafe {
        bool    registered;
        string  name;
        uint256 totalVisits;
    }

    mapping(address => uint256)           public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => Cafe)              public cafes;
    /// visitor => cafe => last claim timestamp
    mapping(address => mapping(address => uint256)) public lastVisit;

    // ─── Events ───────────────────────────────────────────────────────────────
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
    event CafeRegistered(address indexed cafe, string cafeName);
    event CafeRemoved(address indexed cafe);
    event VisitClaimed(address indexed visitor, address indexed cafe, uint256 tokens);
    event TokensRedeemed(address indexed visitor, address indexed cafe, uint256 tokens);

    // ─── Modifiers ────────────────────────────────────────────────────────────
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier cafeExists(address cafe) {
        require(cafes[cafe].registered, "Cafe not registered");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────
    constructor() {
        owner = msg.sender;
    }

    // ─── Admin ────────────────────────────────────────────────────────────────

    /// @notice Register a new cafe partner
    function registerCafe(address cafe, string calldata cafeName) external onlyOwner {
        require(cafe != address(0), "Zero address");
        require(!cafes[cafe].registered, "Already registered");
        cafes[cafe] = Cafe({ registered: true, name: cafeName, totalVisits: 0 });
        emit CafeRegistered(cafe, cafeName);
    }

    /// @notice Remove a cafe (stops future claims but keeps past token balances)
    function removeCafe(address cafe) external onlyOwner {
        require(cafes[cafe].registered, "Not registered");
        cafes[cafe].registered = false;
        emit CafeRemoved(cafe);
    }

    /// @notice Transfer contract ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    // ─── Core: Visit & Redeem ─────────────────────────────────────────────────

    /**
     * @notice Customer claims tokens for visiting a cafe.
     *         Called by the customer after scanning the QR code.
     * @param cafe  The registered cafe wallet address shown in the QR code
     */
    function claimVisit(address cafe) external cafeExists(cafe) {
        uint256 last = lastVisit[msg.sender][cafe];
        require(
            block.timestamp >= last + VISIT_COOLDOWN,
            "Too soon — wait 4 hours between visits"
        );

        lastVisit[msg.sender][cafe] = block.timestamp;
        cafes[cafe].totalVisits += 1;

        require(totalSupply + TOKENS_PER_VISIT <= MAX_SUPPLY, "Max supply reached");
        _mint(msg.sender, TOKENS_PER_VISIT);
        emit VisitClaimed(msg.sender, cafe, TOKENS_PER_VISIT);
    }

    /**
     * @notice Customer redeems tokens at a cafe for a discount.
     *         Called by the CAFE wallet on behalf of the customer.
     * @param visitor   Customer wallet
     * @param amount    Amount of CVT to burn (e.g. 50 CVT = 10% off)
     */
    function redeemTokens(address visitor, uint256 amount)
        external
        cafeExists(msg.sender)
    {
        require(balanceOf[visitor] >= amount, "Insufficient CVT balance");
        _burn(visitor, amount);
        emit TokensRedeemed(visitor, msg.sender, amount);
    }

    // ─── ERC-20 standard ─────────────────────────────────────────────────────

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    // ─── Internal helpers ─────────────────────────────────────────────────────

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "Zero address");
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply     += amount;
        balanceOf[to]   += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        require(balanceOf[from] >= amount, "Insufficient balance");
        balanceOf[from] -= amount;
        totalSupply     -= amount;
        emit Transfer(from, address(0), amount);
    }

    // ─── View helpers ─────────────────────────────────────────────────────────

    /// @notice Seconds until a visitor can claim again at a specific cafe
    function cooldownRemaining(address visitor, address cafe)
        external
        view
        returns (uint256)
    {
        uint256 last = lastVisit[visitor][cafe];
        uint256 unlockAt = last + VISIT_COOLDOWN;
        if (block.timestamp >= unlockAt) return 0;
        return unlockAt - block.timestamp;
    }

    /// @notice Get cafe info
    function getCafe(address cafe)
        external
        view
        returns (bool registered, string memory cafeName, uint256 totalVisits)
    {
        Cafe storage c = cafes[cafe];
        return (c.registered, c.name, c.totalVisits);
    }
}
