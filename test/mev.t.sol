// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "src/mev.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint amount) external;
}

interface IUniswapV2Pair {
    function token0() external returns (address);

    function token1() external returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}
contract MevNEWTest is Test {
    address mev1;
    address mev2;

    function setUp() public {
        mev1 = makeAddr("mev1");
        mev2 = makeAddr("mev2");
        payable(mev1).transfer(1 ether);
        payable(mev2).transfer(1 ether);
    }
    Mev mev;
    IWETH weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    function testBuy() public payable {
        // Create Mev instance
        mev = new Mev();
        address mevaddress = address(mev);

        // Wrap ETH to WETH and send to Mev
        uint256 amountIn = 0.0001 ether;
        weth.deposit{value: amountIn}();
        weth.transfer(mevaddress, amountIn);
        console.log("Amount in: ", amountIn);

        address token = 0xB90B2A35C65dBC466b04240097Ca756ad2005295;

        // WETH -> TOKEN
        address pairV2 = 0xe945683B3462D2603a18BDfBB19261C6a4f03aD1;
        IUniswapV2Pair pair = IUniswapV2Pair(pairV2);
        address token0 = pair.token0();
        uint8 zeroForOne = address(weth) == token0 ? 1 : 0;


        uint256 amountOut;
        {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(address(pair)).getReserves();
        uint256 reserveIn;
        uint256 reserveOut;

        if (zeroForOne == 1) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
        }

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator * 99 / 100;
        }
        console.log("Simulated amount out: ", amountOut);
        uint256 shiftToken = 30;
        amountIn = amountIn / 1000000000;
        bytes memory data = abi.encodePacked(
            uint8(shiftToken),
            address(pair),
            uint32(amountOut / (1 << shiftToken))
        );
        console.log("Calldata:");
        console.logBytes(data);
        console.log(amountIn);
        vm.startPrank(mev1);
        uint256 gasBefore = gasleft();
        (bool success,) = mevaddress.call{value: amountIn}(data);
        uint256 gasAfter = gasleft();
        vm.stopPrank();
        require(success);

        console.log("Gas used: ", gasBefore - gasAfter);
        console.log("Mev TOKEN balance: ", IERC20(token).balanceOf(mevaddress));
    }


    function testSell() public payable {
        // Create Mev instance
        mev = new Mev();
        address mevaddress = address(mev);
        address token = 0x66bFf695f3B16a824869a8018a3A6e3685241269;
        address pairV2 = 0x6DF064f04ddfb2Bb53Da21aF9d56701726700145;

        uint256 amountIn = 149000000 * 1 ether;

        deal(token,mevaddress, amountIn * 10000);
        console.log("Amount in TOKEN: ", amountIn);

        uint256 amountOut;
        {
        IUniswapV2Pair pair = IUniswapV2Pair(pairV2);
        address token0 = pair.token0();
        // TOKEN -> WETH
        uint8 zeroForOne = address(token) == token0 ? 1 : 0;
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(address(pair)).getReserves();
        uint256 reserveIn;
        uint256 reserveOut;

        if (zeroForOne == 1) {
            reserveIn = reserve0;
            reserveOut = reserve1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
        }

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
        }
        console.log("Simulated amount out WETH: ", amountOut);

        uint256 shift = 30;
        bytes memory data = abi.encodePacked(
            uint8(shift),
            address(token),
            uint32(amountIn / (1 << shift))
        );
        console.log("Calldata:");
        console.logBytes(data);


        amountOut = amountOut / 1000000000 ;
        console.log(amountOut);
        vm.startPrank(mev2);
        uint256 gasBefore = gasleft();
        (bool success,) = mevaddress.call{value: 1}(data);
        uint256 gasAfter = gasleft();
        vm.stopPrank();
        require(success);

        console.log("Gas used: ", gasBefore - gasAfter);
        console.log("Mev WETH balance: ", IERC20(weth).balanceOf(address(mev)));
    }


    function testWithdraw() public payable {
        mev = new Mev();
        address mevaddress = address(mev);
        deal(address(weth), mevaddress, 1 ether);
        console.log(weth.balanceOf(mevaddress));
        uint amount = 931322574;
        uint256 shift = 30;
        bytes memory data = abi.encodePacked(
            uint8(shift),
            address(weth),
            uint32(amount)
        );
        vm.startPrank(mev2);
        uint256 gasBefore = gasleft();
        (bool success,) = mevaddress.call{ value: 0}(data);
        uint256 gasAfter = gasleft();
        vm.stopPrank();
        require(success);
        console.log("Gas used: ", gasBefore - gasAfter);
        console.log("Mev WETH balance: ", weth.balanceOf(mevaddress));
    }
}
