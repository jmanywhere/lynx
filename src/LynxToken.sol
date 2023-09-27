// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import "./interfaces/IUniswap.sol";

error LYNX__MaxWalletReached(address wallet, uint triedBalance);
error LYNX__Blacklisted();
error LYNX__InvalidThreshold();

contract Lynx is Ownable, ERC20 {
    //---------------------------------------------------------------------------------
    // Structs
    //---------------------------------------------------------------------------------

    struct SnapshotInfo {
        uint tier1Total; // Tier 1 eligible balance
        uint tier2Total; // Tier 2 eligible balance
        uint snapshotTakenTimestamp; // Timestamp of the snapshot
    }
    //---------------------------------------------------------------------------------
    // State Variables
    //---------------------------------------------------------------------------------
    mapping(address user => mapping(uint snapId => uint amount))
        public snapshotInfo;
    mapping(address user => uint lastSnapshotId) public lastSnapshotId;
    mapping(uint snapId => SnapshotInfo) public snapshots;
    mapping(address wallet => bool excludedStatus) public isExcludedFromTax;
    mapping(address wallet => bool excludedStatus)
        public isExcludedFromMaxWallet;
    mapping(address wallet => bool blacklistedStatus) public isBlacklisted;
    mapping(address wallet => bool dividendExcepmtionStatus)
        public isDividendExempt;
    mapping(address lpAddress => bool) public isLpAddress;

    uint private constant MAX_SUPPLY = 5_000_000 ether;
    uint private constant TIER_1 = 50_000 ether; // TIER 1 is top TIER
    uint private constant TIER_2 = 1_000 ether; // TIER 2 is middle TIER
    uint private constant TAX_PERCENT = 100;
    IUniswapV2Router02 public router;

    address public mainPair;
    address private immutable WETH;
    address payable public immutable ADMIN_WALLET;
    uint public currentSnapId = 0;
    uint public taxThreshold;

    uint public maxWallet;
    uint public buyTax = 5;
    uint public sellTax = 5;

    bool private isSwapping = false;

    //---------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------

    event WalletExcludedFromTax(address indexed _user, bool excluded);
    event WalletExcludedFromMax(address indexed _user, bool excluded);
    event BlacklistWalletUpdate(address indexed _user, bool blacklisted);
    event BlacklistWalletsUpdate(address[] _users, bool blacklisted);
    event SetAddressAsLp(address indexed _lpAddress, bool isLpAddress);
    event SnapshotTaken(uint indexed snapId, uint timestamp);

    //---------------------------------------------------------------------------------
    // Constructor
    //---------------------------------------------------------------------------------
    constructor(address _admin) ERC20("LYNX", "LYNX") {
        _mint(msg.sender, MAX_SUPPLY);

        maxWallet = (MAX_SUPPLY * 1_5) / 100_0; // 1.5% of total supply
        taxThreshold = MAX_SUPPLY / 100_0; // 0.1% of total supply

        // Ethereum Mainnet UniswapV2 Router
        router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        WETH = router.WETH();
        // Create the Pair for this token with WETH
        mainPair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            WETH
        );
        isLpAddress[mainPair] = true;

        isExcludedFromMaxWallet[address(this)] = true;
        isExcludedFromMaxWallet[owner()] = true;
        isExcludedFromMaxWallet[address(router)] = true;

        isExcludedFromTax[address(this)] = true;
        isExcludedFromTax[address(router)] = true;

        isDividendExempt[address(this)] = true;
        isDividendExempt[address(router)] = true;
        isDividendExempt[address(mainPair)] = true;
        ADMIN_WALLET = payable(_admin);
    }

    //---------------------------------------------------------------------------------
    // External & Public Functions
    //---------------------------------------------------------------------------------

    /**
     * Set wether an address is excluded from taxes or NOT.
     * @param _user User which status will be updated
     * @param _excluded The new excluded status. True is Excluded, False is NOT excluded
     */
    function setExcludeFromTax(
        address _user,
        bool _excluded
    ) external onlyOwner {
        isExcludedFromTax[_user] = _excluded;
        emit WalletExcludedFromTax(_user, _excluded);
    }

    /**
     * Exclude or include a wallet of MAX wallet limit (AntiWhale)
     * @param _user Address which status will be updated
     * @param _excluded The new excluded status. True is Excluded, False is NOT excluded
     */
    function setExcludedFromMaxWallet(
        address _user,
        bool _excluded
    ) external onlyOwner {
        isExcludedFromMaxWallet[_user] = _excluded;
        emit WalletExcludedFromMax(_user, _excluded);
    }

    /**
     * @notice Set the address as Blacklisted
     * @param _user Address which status will be updated
     */
    function blacklistAddress(address _user) external onlyOwner {
        isBlacklisted[_user] = true;
        isDividendExempt[_user] = true;
        emit BlacklistWalletUpdate(_user, true);
    }

    /**
     * @notice Set the addresses as Blacklisted
     * @param _users Addresses which status will be updated
     */
    function blacklistAddresses(address[] calldata _users) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            isBlacklisted[_users[i]] = true;
            isDividendExempt[_users[i]] = true;
        }
        emit BlacklistWalletsUpdate(_users, true);
    }

    /**
     * @notice Remove the address as Blacklisted
     * @param _user Addresses which status will be updated
     */
    function unblacklistAddress(address _user) external onlyOwner {
        isBlacklisted[_user] = false;
        isDividendExempt[_user] = false;
        emit BlacklistWalletUpdate(_user, false);
    }

    /**
     * @notice Remove the addresses as Blacklisted
     * @param _users Addresses which status will be updated
     */
    function unblacklistAddresses(
        address[] calldata _users
    ) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            isBlacklisted[_users[i]] = false;
            isDividendExempt[_users[i]] = false;
        }
        emit BlacklistWalletsUpdate(_users, false);
    }

    /**
     * @notice Set an Address as LP
     * @param _lpAddress Address to set as LP
     * @param _isLpAddress enable or disable address as an LP
     */
    function setLpAddress(
        address _lpAddress,
        bool _isLpAddress
    ) external onlyOwner {
        isLpAddress[_lpAddress] = _isLpAddress;
        isDividendExempt[_lpAddress] = _isLpAddress;
        emit SetAddressAsLp(_lpAddress, _isLpAddress);
    }

    /**
     * @notice Create a snapshot of the current balances
     */
    function takeSnapshot() external onlyOwner {
        uint currentSnap = currentSnapId;
        currentSnapId++;

        SnapshotInfo storage snap = snapshots[currentSnap];
        snap.snapshotTakenTimestamp = block.timestamp;
        // roll over total amounts
        snapshots[currentSnapId] = SnapshotInfo({
            tier1Total: snap.tier1Total,
            tier2Total: snap.tier2Total,
            snapshotTakenTimestamp: 0
        });

        emit SnapshotTaken(currentSnap, block.timestamp);
    }

    /**
     * @notice Set the new Tax swap threshold
     * @param _taxThreshold New tax threshold
     */
    function setTaxThreshold(uint _taxThreshold) external onlyOwner {
        if (_taxThreshold > MAX_SUPPLY) revert LYNX__InvalidThreshold();
        taxThreshold = _taxThreshold;
    }

    //---------------------------------------------------------------------------------
    // Internal & Private Functions
    //---------------------------------------------------------------------------------

    /**
     * @notice Underlying transfer of tokens used by `transfer` and `transferFrom` in ERC20 which are public
     * @param from Address that holds the funds
     * @param to Address that receives the funds
     * @param amount Amount of funds to send
     */
    function _transfer(
        address from,
        address to,
        uint amount
    ) internal override {
        if (isBlacklisted[from] || isBlacklisted[to])
            revert LYNX__Blacklisted();

        uint currentBalance = balanceOf(address(this));

        bool taxExclusion = isExcludedFromTax[from] || isExcludedFromTax[to];

        if (!isSwapping && currentBalance >= taxThreshold && !taxExclusion) {
            _swapTokens();
        }

        // Check that sender is free of tax or receiver is free of tax
        if (!taxExclusion) {
            uint tax;
            // if not free of tax, check if is buy or sell
            if (isLpAddress[to]) {
                // IS SELL
                tax = (amount * sellTax) / TAX_PERCENT;
            } else if (isLpAddress[from]) {
                // IS BUY
                tax = (amount * buyTax) / TAX_PERCENT;
            }
            if (tax > 0) {
                super._transfer(from, address(this), tax);
                amount -= tax;
            }
        }

        // check if receiver is free of max wallet
        uint toNEWBalance = balanceOf(to) + amount;
        if (!isExcludedFromMaxWallet[to] && toNEWBalance > maxWallet) {
            revert LYNX__MaxWalletReached(to, toNEWBalance);
        }
        _updateSnapIncrease(to, amount);
        super._transfer(from, to, amount);
    }

    /**
     * @notice Swap any tokens the contract has for ETH and send the ETH directly to the Admin Wallet
     */
    function _swapTokens() private {
        isSwapping = true;
        // Get the current amount of tokens stored in the contract
        uint256 contractTokenBalance = balanceOf(address(this));

        // If the contract has tokens
        if (contractTokenBalance > 0) {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = WETH;
            // Swap all for ETH and send to Admin Wallet
            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                contractTokenBalance,
                0, // Accept any amount of ETH
                path,
                ADMIN_WALLET,
                block.timestamp
            );
        }
        isSwapping = false;
    }

    /**
     * @notice Decrease a wallet's current snapshot balance
     * @param user Wallet to update snapshot info
     * @param amount the difference amount in snapshot
     */
    function _updateSnapDecrease(address user, uint amount) private {
        uint currentSnap = currentSnapId;
        uint currentSnapBalance = snapshotInfo[user][currentSnap];
        uint currentBalance = balanceOf(user);
        uint newBalance = currentBalance - amount;
        SnapshotInfo storage snap = snapshots[currentSnap];
        lastSnapshotId[user] = currentSnap;

        // If user is exempt from dividends, we need to set the snapshot value to 0
        if (isDividendExempt[user]) {
            snapshotInfo[user][currentSnap] = 0;
            // if user is now exempt but used to have funds, we need to decrease the total
            if (currentSnapBalance > 0) {
                if (currentSnapBalance >= TIER_1)
                    snap.tier1Total -= currentSnapBalance;
                else if (currentSnapBalance >= TIER_2)
                    snap.tier2Total -= currentSnapBalance;
            }
        } else {
            snapshotInfo[user][currentSnap] = newBalance;

            /// FROM TIER 1
            if (currentBalance >= TIER_1) {
                // Decrease TIER 1
                snap.tier1Total -= currentBalance;
                // TO SAME TIER
                if (newBalance >= TIER_1) snap.tier1Total += newBalance;
                // TO TIER 2
                if (newBalance < TIER_1 && newBalance >= TIER_2)
                    snap.tier2Total += newBalance;
                // if to NO tier, just decrease is fine
            }
            // FROM TIER 2
            else if (currentBalance >= TIER_2) {
                snap.tier2Total -= currentBalance;
                // TO SAME TIER
                if (newBalance >= TIER_2) snap.tier2Total += newBalance;
                // TO NO TIER JUST DO NOTHING
            }
        }
    }

    /**
     * @notice Increase a wallet's current snapshot balance
     * @param user Wallet to update snapshot info
     * @param amount Difference amount
     */
    function _updateSnapIncrease(address user, uint amount) private {
        uint currentSnap = currentSnapId;
        uint currentBalance = balanceOf(user);
        uint currentSnapBalance = snapshotInfo[user][currentSnap];
        SnapshotInfo storage snap = snapshots[currentSnap];
        lastSnapshotId[user] = currentSnap;
        // If user is exempt from dividends, we need to set the snapshot value to 0
        if (isDividendExempt[user]) {
            snapshotInfo[user][currentSnap] = 0;
            // if user is now exempt but used to have funds, we need to decrease the total
            if (currentSnapBalance > 0) {
                if (currentSnapBalance >= TIER_1)
                    snap.tier1Total -= currentSnapBalance;
                else if (currentSnapBalance >= TIER_2)
                    snap.tier2Total -= currentSnapBalance;
            }
        } else {
            snapshotInfo[user][currentSnap] = currentBalance + amount;
            uint newBalance = currentBalance + amount;
            // Check if there is any tier advancement

            // FROM NO TIER
            if (currentBalance < TIER_2) {
                // TO TIER 1
                if (newBalance >= TIER_1)
                    snap.tier1Total += newBalance;
                    // TO TIER 2
                else if (newBalance >= TIER_2) snap.tier2Total += newBalance;
                // TO NO TIER DO NOTHING
            }
            // FROM TIER 2
            else if (currentBalance >= TIER_2 && currentBalance < TIER_1) {
                snap.tier2Total -= currentBalance;
                // TO TIER 1
                if (newBalance >= TIER_1)
                    snap.tier1Total += newBalance;

                    // TO SAME TIER
                else if (newBalance >= TIER_2) snap.tier2Total += newBalance;
            }
            // FROM TIER 1
            else if (currentBalance >= TIER_1) {
                // Stay in same tier
                snap.tier1Total -= currentBalance;
                snap.tier1Total += newBalance;
            }
        }
    }

    //---------------------------------------------------------------------------------
    // External & Public VIEW | PURE Functions
    //---------------------------------------------------------------------------------

    function getUserSnapshotAt(
        address user,
        uint snapId
    ) external view returns (uint) {
        // If snapshot ID hasn't been taken, return 0
        if (snapId > currentSnapId) return 0;
        uint lastUserSnap = lastSnapshotId[user];
        // if last snapshot is before the requested snapshot, return current balance of the user
        if (snapId > lastUserSnap) return balanceOf(user);
        // else return the snapshot balance
        return snapshotInfo[user][snapId];
    }

    //---------------------------------------------------------------------------------
    // Internal & Private VIEW | PURE Functions
    //---------------------------------------------------------------------------------
}
