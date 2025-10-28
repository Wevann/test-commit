// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*
  BasePremiumToken.sol
  "Đẳng cấp" demo token cho Base (EVM-compatible)
  - Dùng OpenZeppelin contracts (ERC20, ERC20Permit, Ownable, Pausable, ReentrancyGuard)
  - Tính năng: mint/burn, pause, batchTransfer, rescue tokens, permit (EIP-2612)
  - Thiết kế an toàn và gọn: checks-effects-interactions, events, access control

  Lưu ý: để compile & deploy, dự án của bạn cần cài OpenZeppelin:
    npm install @openzeppelin/contracts
*/

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BasePremiumToken is ERC20, ERC20Permit, Pausable, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Max supply cap (optional) — set to 100 million tokens with 18 decimals
    uint256 public immutable MAX_SUPPLY;

    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);
    event BatchTransfer(address indexed sender, uint256 totalRecipients, uint256 totalAmount);
    event RescuedERC20(address indexed token, address indexed to, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        require(maxSupply_ > 0, "Max supply must be > 0");
        MAX_SUPPLY = maxSupply_;

        // Optionally mint a small initial supply to owner for liquidity/airdrops
        uint256 initial = (maxSupply_ * 1) / 100; // 1% initial
        if (initial > 0) {
            _mint(_msgSender(), initial);
            emit TokensMinted(_msgSender(), initial);
        }
    }

    // ----------------------
    // Mint & Burn (Owner)
    // ----------------------

    /// @notice Mint tokens to an address (owner only)
    /// @dev respects MAX_SUPPLY cap
    function mint(address to, uint256 amount) external onlyOwner whenNotPaused nonReentrant {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    /// @notice Burn tokens from caller
    function burn(uint256 amount) external whenNotPaused nonReentrant {
        _burn(_msgSender(), amount);
        emit TokensBurned(_msgSender(), amount);
    }

    // ----------------------
    // Pause control (Owner)
    // ----------------------
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ----------------------
    // Batch transfer utility
    // ----------------------
    /// @notice Gas-optimized-ish batch transfer for a single sender
    /// @dev arrays must have same length
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused nonReentrant {
        uint256 n = recipients.length;
        require(n == amounts.length, "Length mismatch");
        require(n > 0, "No recipients");

        uint256 total = 0;
        for (uint256 i = 0; i < n; ++i) {
            total += amounts[i];
        }

        // Check balance only once
        require(balanceOf(_msgSender()) >= total, "Insufficient balance");

        for (uint256 i = 0; i < n; ++i) {
            _transfer(_msgSender(), recipients[i], amounts[i]);
        }

        emit BatchTransfer(_msgSender(), n, total);
    }

    // ----------------------
    // Rescue tokens (emergency)
    // ----------------------
    /// @notice Rescue accidentally sent ERC20 tokens to this contract
    /// @dev Owner only. Cannot rescue this contract's own token to avoid misuse.
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner nonReentrant {
        require(token != address(this), "Cannot rescue native token");
        IERC20(token).safeTransfer(to, amount);
        emit RescuedERC20(token, to, amount);
    }

    // ----------------------
    // Overrides & Hooks
    // ----------------------

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    // The following functions are overrides required by Solidity for multiple inheritance
    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal override(ERC20) {
        super._mint(account, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20) {
        super._burn(account, amount);
    }

    // ----------------------
    // Gas & UX tips (comments for deployers)
    // ----------------------
    /*
      - Deploy on Base (or any EVM) using Hardhat/Foundry.
      - Use verify plugin to publish source.
      - For minting patterns in production, consider a Minter role instead of owner — use AccessControl.
      - For upgradeability use OpenZeppelin Upgradeable contracts and a Proxy.
      - Use Etherscan/BlockExplorer verification after deployment for transparency.
    */
}

