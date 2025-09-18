// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract RPMarket is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum OrderStatus { Active, Filled, Cancelled }

    struct Order {
        uint256 id;
        address maker;
        address token;
        uint256 tokenAmount;
        uint256 usdtAmount;
        bool isSellOrder;
        OrderStatus status;
    }

    address public owner;
    IERC20 public immutable usdt;
    uint256 public commissionBps; // in basis points, e.g. 100 = 1%
    uint256 public heldCommission;
    uint256 public nextOrderId;

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;
    uint256[] public activeOrderIds;
    mapping(uint256 => uint256) private activeOrderIndex;

    event OrderCreated(uint256 indexed id, address indexed maker, bool isSellOrder);
    event OrderFilled(uint256 indexed id, address indexed filler);
    event OrderCancelled(uint256 indexed id);
    event CommissionReleased(address indexed to, uint256 amount);
    event CommissionRateUpdated(uint256 bps);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _usdt) {
        usdt = IERC20(_usdt);
        owner = msg.sender;
    }

    // ===== ORDER CREATION =====

    function createSellOrder(address token, uint256 tokenAmount, uint256 usdtAmount) external nonReentrant {
        require(tokenAmount > 0 && usdtAmount > 0, "Invalid amounts");
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        _createOrder(token, tokenAmount, usdtAmount, true);
    }

    function createBuyOrder(address token, uint256 tokenAmount, uint256 usdtAmount) external nonReentrant {
        require(tokenAmount > 0 && usdtAmount > 0, "Invalid amounts");
        usdt.safeTransferFrom(msg.sender, address(this), usdtAmount);
        _createOrder(token, tokenAmount, usdtAmount, false);
    }

    function _createOrder(address token, uint256 tokenAmount, uint256 usdtAmount, bool isSellOrder) internal {
        orders[nextOrderId] = Order({
            id: nextOrderId,
            maker: msg.sender,
            token: token,
            tokenAmount: tokenAmount,
            usdtAmount: usdtAmount,
            isSellOrder: isSellOrder,
            status: OrderStatus.Active
        });

        userOrders[msg.sender].push(nextOrderId);
        activeOrderIndex[nextOrderId] = activeOrderIds.length;
        activeOrderIds.push(nextOrderId);

        emit OrderCreated(nextOrderId, msg.sender, isSellOrder);
        nextOrderId++;
    }

    // ===== FILL ORDER =====

    function fillOrder(uint256 id) external nonReentrant {
        Order storage order = orders[id];
        require(order.status == OrderStatus.Active, "Order not active");

        order.status = OrderStatus.Filled;
        _removeActiveOrder(id);

        uint256 commission = (order.usdtAmount * commissionBps) / 10000;
        uint256 netAmount = order.usdtAmount - commission;
        heldCommission += commission;

        if (order.isSellOrder) {
            // Buyer sends USDT; seller gets net; buyer gets tokens
            usdt.safeTransferFrom(msg.sender, address(this), order.usdtAmount);
            usdt.safeTransfer(order.maker, netAmount);
            IERC20(order.token).safeTransfer(msg.sender, order.tokenAmount);
        } else {
            // Seller sends token to maker; buyer gets net USDT
            IERC20(order.token).safeTransferFrom(msg.sender, order.maker, order.tokenAmount);
            usdt.safeTransfer(msg.sender, netAmount);
        }

        emit OrderFilled(id, msg.sender);
    }

    // ===== CANCEL ORDER =====

    function cancelOrder(uint256 id) external nonReentrant {
        Order storage order = orders[id];
        require(order.status == OrderStatus.Active, "Order not active");
        require(msg.sender == order.maker || msg.sender == owner, "Not authorized");

        order.status = OrderStatus.Cancelled;
        _removeActiveOrder(id);

        if (order.isSellOrder) {
            IERC20(order.token).safeTransfer(order.maker, order.tokenAmount);
        } else {
            usdt.safeTransfer(order.maker, order.usdtAmount);
        }

        emit OrderCancelled(id);
    }

    // ===== ADMIN / COMMISSION =====

    function setCommissionBps(uint256 bps) external onlyOwner {
        require(bps <= 1000, "Too high"); // Max 10%
        commissionBps = bps;
        emit CommissionRateUpdated(bps);
    }

    function getCommissionBps() external view returns (uint256) {
        return commissionBps;
    }

    function releaseCommission(address to) external onlyOwner nonReentrant {
        require(heldCommission > 0, "Nothing to release");
        uint256 amount = heldCommission;
        heldCommission = 0;
        usdt.safeTransfer(to, amount);
        emit CommissionReleased(to, amount);
    }

    function getHeldCommission() external view returns (uint256) {
        return heldCommission;
    }

    // ===== ENUMERATION =====

    function getUserOrderIds(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }

    function getUserActiveOrders(address user) external view returns (Order[] memory) {
        uint256[] memory ids = userOrders[user];
        uint256 activeCount;

        for (uint256 i = 0; i < ids.length; i++) {
            if (orders[ids[i]].status == OrderStatus.Active) {
                activeCount++;
            }
        }

        Order[] memory result = new Order[](activeCount);
        uint256 j;
        for (uint256 i = 0; i < ids.length; i++) {
            if (orders[ids[i]].status == OrderStatus.Active) {
                result[j++] = orders[ids[i]];
            }
        }

        return result;
    }

    function getActiveOrderIds() external view returns (uint256[] memory) {
        return activeOrderIds;
    }

    function getActiveOrders() external view returns (Order[] memory) {
        uint256 len = activeOrderIds.length;
        Order[] memory result = new Order[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = orders[activeOrderIds[i]];
        }
        return result;
    }

    // ===== INTERNAL =====

    function _removeActiveOrder(uint256 id) internal {
        uint256 index = activeOrderIndex[id];
        uint256 lastId = activeOrderIds[activeOrderIds.length - 1];
        activeOrderIds[index] = lastId;
        activeOrderIndex[lastId] = index;
        activeOrderIds.pop();
        delete activeOrderIndex[id];
    }
}
