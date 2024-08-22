// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
contract Mev {
    fallback() external payable {
        assembly { 
            let zeroForOne
            let BuyOrSell
            let amountWETH := mul(callvalue(), 0x3b9aca00) // mul(callvalue(), 1000000000)
            let amount := mul(shr(224, calldataload(0x15)), shl(shr(248, calldataload(0x00)),1)) //mul(uint32(amount), 1 << uint8(shiftToken))
            let inputAddress := shr(96, calldataload(0x01))

            //Switch current owner
            switch caller()
            case 0x2078e690733Fb5e02dcF6678702C6206443c410d {}
            case 0x2078e690733Fb5e02dcF6678702C6206443c420d {
                zeroForOne := 1
            }
            case 0xEcB302F7fEB5e5A6F505a6cefc892961766c75b8 {
                BuyOrSell := 1
            }
            case 0xEcB302F7fEB5e5A6F505a6cefc892961766c75b7 {
                BuyOrSell := 1
                zeroForOne := 1
            }
            // require caller() is owner
            default {
                revert(0,0)
            }

            //Recovery token 
            if iszero(amountWETH) {
                mstore(0x00, 0x23b872dd00000000000000000000000000000000000000000000000000000000) //TRANSFER_FROM_SELECTOR
                mstore(0x04, address())
                mstore(0x24, caller())
                mstore(0x44, amount)
                if iszero(call(gas(), inputAddress, 0, 0x00, 0x64, 0, 0)) {
                    revert(0,0)
                }
                return(0, 0)
            }

            switch BuyOrSell 
            case 0 {
            //transfer
            mstore(0x00, 0x23b872dd00000000000000000000000000000000000000000000000000000000) //TRANSFER_FROM_SELECTOR
            mstore(0x04, address())
            mstore(0x24, inputAddress)
            mstore(0x44, amountWETH)
            if iszero(call(gas(), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 0, 0x00, 0x64, 0, 0)){  //WETH 
             revert (0,0)
            }
            //swap
            mstore(0x00, 0x022c0d9f00000000000000000000000000000000000000000000000000000000) //SWAP_SELECTOR
            switch zeroForOne
                case 0 {
                mstore(0x04, amount)
                mstore(0x24, 0)
                }
                case 1 {
                mstore(0x04, 0)
                mstore(0x24, amount)
                }
            mstore(0x44, address())
            mstore(0x64, 0x80)
            if iszero(call(gas(), inputAddress, 0, 0x00, 0xa4, 0, 0)) {
                revert(0,0)
            }
            } 

            case 1 {

                //Sort tokens token0:token1
                switch lt(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, inputAddress) //WETH
                    case 0 {
                    mstore(0x00, shl(96, inputAddress))
                    mstore(0x14, shl(96, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)) //WETH
                    }
                    case 1 {
                    mstore(0x00, shl(96, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)) //WETH
                    mstore(0x14, shl(96, inputAddress))
                    } 
                let data := keccak256(0x00, 0x28)

                //Calculate pair Uniswap V2
                mstore(0x00, shl(88,0xff5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f)) //hex"ff"+factory
                mstore(0x15, data) //keccak256(token0,token1)
                mstore(0x35, 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f) //pairHash
                let pair := and(keccak256(0x00, 0x55), 0xffffffffffffffffffffffffffffffffffffffff) //toAddress

                //transfer
                mstore(0x00, 0xa9059cbb00000000000000000000000000000000000000000000000000000000) //TRANSFER_SELECTOR
                mstore(0x04, pair)
                mstore(0x24, amount)
                if iszero(call(gas(), inputAddress, 0, 0x00, 0x44, 0, 0)) {
                    revert(0,0)
                }

                //swap
                mstore(0x00, 0x022c0d9f00000000000000000000000000000000000000000000000000000000) //SWAP_SELECTOR
                switch zeroForOne 
                case 0 {
                mstore(0x04, amountWETH)
                mstore(0x24, 0)
                }
                case 1 {
                mstore(0x04, 0)
                mstore(0x24, amountWETH)
                }
                mstore(0x44, address())
                mstore(0x64, 0x80)
                if iszero(call(gas(), pair, 0, 0x00, 0xa4, 0, 0)) {
                    revert(0,0)
                }
            }
        }
    }
}