// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router02.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/interfaces/INonfungiblePositionManager.sol";

contract AdvancedToken is ERC20, Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;
    struct Args {
        string name;
        string symbol;
        uint8 _decimals; 
        uint256 _totalSupply;
        address _serviceFeeReceiver;
        address _taxReceiver;
        uint256 maxTransaction;
        uint256 maxWallet;
        uint256 buyFee; //percent 10^6
        uint256 sellFee; //percent 10^6
        uint256 dexType; //2: v2, 3: pancakev3, 4: uniV3
        address dexRouter;
        uint256 rewardToken; // 1: base token, 2: 
        uint256 buyReward; //percent 10^6
        uint256 sellReward; //percent 10^6
        uint256 lpBuyFee; //percent 10^6
        uint256 lpSellFee; //percent 10^6
        uint256 buyBurnPercent; //percent 10^6
        uint256 sellBurnPercent; //percent 10^6
        uint256 serviceFee;
    }
    uint8 private _decimals; 
    uint256 private _totalSupply;
    address payable private serviceFeeReceiver;
    address payable private taxReceiver;
    uint256 private maxTransaction;
    uint256 private maxWallet;
    uint256 private buyFee; //percent 10^6
    uint256 private sellFee; //percent 10^6
    uint256 public dexType; //2: v2, 3: v3
    address public dexRouter;
    uint256 public rewardToken; // 1: base token, 2: 
    uint256 private buyReward; //percent 10^6
    uint256 private sellReward; //percent 10^6
    uint256 private lpBuyFee; //percent 10^6
    uint256 private lpSellFee; //percent 10^6
    uint256 private buyBurnPercent; //percent 10^6
    uint256 private sellBurnPercent; //percent 10^6
    address public mainPair;
    uint256 private constant MAX = ~uint256(0);

    mapping(address => bool) public automatedMarketMakerPairs;
    mapping(address => bool) public whiteList;

    constructor(
        Args memory args
    ) payable ERC20(args.name, args.symbol) Ownable(msg.sender){
        _decimals = args._decimals;
        _totalSupply = args._totalSupply;
        serviceFeeReceiver = payable(args._serviceFeeReceiver);
        require(
            msg.value >= args.serviceFee, "Service fee is not enough!"
        );
        taxReceiver = payable(args._taxReceiver);
        maxTransaction = args.maxTransaction;
        maxWallet = args.maxWallet;
        buyFee = args.buyFee;
        sellFee = args.sellFee;
        dexType = args.dexType;
        dexRouter = args.dexRouter;
        rewardToken = args.rewardToken;
        buyReward = args.buyReward;
        sellReward = args.sellReward;
        lpBuyFee = args.lpBuyFee;
        lpSellFee = args.lpSellFee;
        buyBurnPercent = args.buyBurnPercent;
        sellBurnPercent = args.sellBurnPercent;
        require(buyFee<= 200000 && sellFee<=200000, "Tax fee can't be greater than 20%!");
        require(buyReward<= 200000 && sellReward<=200000, "Reward fee can't be greater than 20%!");
        require(lpBuyFee<= 200000 && lpSellFee<=200000, "Liquidity adding fee can't be greater than 20%!");
        require(buyBurnPercent<= 200000 && sellBurnPercent<= 200000, "Burning percent can't be greater than 20%!");
        super._approve(address(this), address(dexRouter), MAX);
        _mint(msg.sender, _totalSupply);
        (bool os, ) = payable(serviceFeeReceiver).call{value: args.serviceFee}("");
        require(os);
        if(dexType == 2){
            mainPair = IUniswapV2Factory(IUniswapV2Router02(dexRouter).factory()).createPair(
                address(this),
                IUniswapV2Router02(dexRouter).WETH()
            );
        }else{ // for V3
            uint24 fee;
            if(dexType == 3){
                //pancakeswap V3
                fee = 2500;
            }else if(dexType == 4){
                //uniswap V3
                fee = 3000;
            }
            address token0;
            address token1;
            uint256 amount0ToAdd;
            uint256 amount1ToAdd;
            amount0ToAdd = 1000000000000000000;
            amount1ToAdd = 1000000000000000000;
            if(INonfungiblePositionManager(dexRouter).WETH9()> address(this)){
                token0 = address(this);
                token1 = INonfungiblePositionManager(dexRouter).WETH9();
            }else {
                token0 = INonfungiblePositionManager(dexRouter).WETH9();
                token1 = address(this);
            }
            mainPair = INonfungiblePositionManager(dexRouter).createAndInitializePoolIfNecessary(
                token0,
                token1,
                fee,
                uint160(Math.sqrt(Math.mulDiv(amount1ToAdd, 2**192, amount0ToAdd)))
            );
        }
        setAutomatedMarketMakerPair(mainPair, true);
        
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function updateTaxFee(
        uint256 _buyTaxFee,
        uint256 _sellTaxFee
    ) external onlyOwner {
        require(
            _sellTaxFee <= 200000,
            "sell fee should be less than 20%"
        );
        require(
            _buyTaxFee <= 200000, 
            "buy fee should be less than 20%"
        );
        
        buyFee = _buyTaxFee;
        sellFee = _sellTaxFee;           
    }

    function updateRewardFee(
        uint256 _buyRewardFee,
        uint256 _sellRewardFee
    ) external onlyOwner {
        require(
            _sellRewardFee <= 200000,
            "sell fee should be less than 20%"
        );
        require(
            _buyRewardFee <= 200000, 
            "buy fee should be less than 20%"
        );
        
        buyReward = _buyRewardFee;
        sellReward = _sellRewardFee;           
    }

    function updateLpFee(
        uint256 _lpBuyFee,
        uint256 _lpSellFee
    ) external onlyOwner {
        require(
            _lpSellFee <= 200000,
            "sell fee should be less than 20%"
        );
        require(
            _lpBuyFee <= 200000, 
            "buy fee should be less than 20%"
        );
        
        lpBuyFee = _lpBuyFee;
        lpSellFee = _lpSellFee;           
    }

     function updateBurnFee(
        uint256 _buyBurnFee,
        uint256 _sellBurnFee
    ) external onlyOwner {
        require(
            _sellBurnFee <= 200000,
            "sell fee should be less than 20%"
        );
        require(
            _buyBurnFee <= 200000, 
            "buy fee should be less than 20%"
        );
        
        buyBurnPercent = _buyBurnFee;
        sellBurnPercent = _sellBurnFee;           
    }
    function updateMaxWallet(
        uint256 _maxWallet
    ) external onlyOwner {
        maxWallet = _maxWallet;
    }

    function updateMaxTransaction(
        uint256 _maxTransaction
    ) external onlyOwner {
        maxTransaction = _maxTransaction;
    }
    function updateTaxReceiver(
        address taxReceiver_
    ) external onlyOwner {
        require(taxReceiver_ != address(0), "marketing wallet can't be 0");
        taxReceiver = payable(taxReceiver_);
    }
    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        require(
            automatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {        
        automatedMarketMakerPairs[pair] = value;
    }

    function setWhiteList(address _addr, bool value)
        public
        onlyOwner
    {
        require(
            whiteList[_addr] != value,
            "This address is already set to that value"
        );
        whiteList[_addr] = value;
    }

    function swapTokensToETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = IUniswapV2Router02(dexRouter).WETH();
        IUniswapV2Router02(dexRouter).swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BaseToken
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 baseTokenAmount) private {  
        IUniswapV2Router02(dexRouter).addLiquidityETH{value: baseTokenAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0xdead),
            block.timestamp
        );
    }
    
    
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        if(whiteList[from] == true || whiteList[to] == true){ //whitelisted address
            super._transfer(from, to, amount);
        }else{
            
            uint256 _swapFee;
            uint256 _rewardFee;
            uint256 _lpFee;
            uint256 _burnFee;
            uint256 initialBalance;
            uint256 balanceAfter;
            // Buy
            if (automatedMarketMakerPairs[from]) {
                uint256 toBalanceAfter;
                toBalanceAfter = IERC20(address(this)).balanceOf(to)+ amount;
                if(maxTransaction != 0){
                    require(amount <= maxTransaction, "Amount exceed maxTransaction");
                }
                if(maxWallet != 0){
                    require(toBalanceAfter <= maxWallet, "Holding exceed maxWallet");
                }
                whiteList[to] = true; // to avoid infinite looping for sending fees.
                if(buyFee != 0){ // buy tax exist
                    _swapFee = amount * buyFee / 1000000;
                    super._transfer(from, taxReceiver, _swapFee); // sending buy fee
                    amount = amount - _swapFee;
                }
                if(buyReward != 0){ // buy Reward exist
                    _rewardFee = amount * buyReward / 1000000;
                    if(rewardToken == 1){ //reward token type is base token
                        
                    }else if(rewardToken == 2){ //reward token type is eth, for this sell rewardFee and send it to to wallet
                        require(dexType==2, "Can't work reward for V3!");
                        amount = amount -_rewardFee;
                        super._transfer(from, address(this), _rewardFee);
                        //selling rewardFee to send reward as ETH type to to wallet
                        initialBalance = address(this).balance;
                        swapTokensToETH(_rewardFee);
                        balanceAfter = address(this).balance;
                        (bool success, ) = address(to).call{value: balanceAfter - initialBalance}("");
                        require(success, "Sending buy reward with ETH failed!");
                    }
                }
                if(lpBuyFee != 0){ // lp buy Fee existy
                    require(dexType == 2, "Can't work lp adding for V3!");
                    _lpFee = amount * lpBuyFee / 1000000; // need to split this two and sell one and add liquidity
                    super._transfer(from, address(this), _lpFee);
                    amount = amount - _lpFee;
                    uint256 lpBaseTokenAmount= _lpFee / 2;
                    initialBalance = address(this).balance;
                    swapTokensToETH(_lpFee- lpBaseTokenAmount);
                    balanceAfter = address(this).balance;
                    addLiquidity(lpBaseTokenAmount, balanceAfter - initialBalance);
                }
                if(buyBurnPercent != 0){
                    _burnFee = amount * buyBurnPercent / 1000000;
                    super._transfer(from, address(0xdead), _burnFee);
                }
                super._transfer(from, to, amount);

                whiteList[to] = false; 
                
            }
            // Sell
            else if (automatedMarketMakerPairs[to]) {
                if(maxTransaction != 0){
                    require(amount <= maxTransaction, "Amount exceed maxTransaction");
                }
                whiteList[from] = true; // to avoid infinite looping for sending fees.
                if(sellFee != 0){ //sell tax exist
                    _swapFee = amount * sellFee / 1000000;
                    super._transfer(from, taxReceiver, _swapFee); // sending sell fee
                    amount = amount - _swapFee;
                }
                if(sellReward != 0) { // sell Reward exist
                    _rewardFee = amount * sellReward / 1000000;
                    if(rewardToken == 1){ // reward token type is base token
                        amount = amount - _rewardFee;
                    }else if(rewardToken == 2){ // reward token type is eth
                        require(dexType == 2, "Can't work reward for V3!");
                        super._transfer(from, address(this), _rewardFee);
                        initialBalance = address(this).balance;
                        swapTokensToETH(_rewardFee);
                        balanceAfter = address(this).balance;
                        (bool success, ) = address(from).call{value: balanceAfter - initialBalance}("");
                        require(success, "Sending sell reward with ETH failed!");
                    }
                }
                if(lpSellFee != 0){ // lp sell Fee exist
                    require(dexType == 2, "Can't work lp adding for V3!");
                    _lpFee = amount * lpSellFee/1000000; // need to split this tow and sell one and add liquidity
                    amount = amount - _lpFee;
                    super._transfer(from, address(this), _lpFee);
                    uint256 lpBaseTokenAmount= _lpFee / 2;
                    initialBalance = address(this).balance;
                    swapTokensToETH(_lpFee- lpBaseTokenAmount);
                    balanceAfter = address(this).balance;
                    addLiquidity(lpBaseTokenAmount, balanceAfter - initialBalance);
                }
                if(sellBurnPercent != 0){
                    _burnFee = amount * sellBurnPercent / 1000000;
                    super._transfer(from, address(0xdead), _burnFee);
                }
                super._transfer(from, to, amount);
                whiteList[from] = false; // to avoid infinite looping for sending fees.
            }
        }
    }

    function withdrawETH() external onlyOwner {
        (bool success, )=address(owner()).call{value: address(this).balance}("");
        require(success, "Failed in withdrawal");
    }
    function withdrawToken(address token) external onlyOwner{
        require(address(this) != token, "Not allowed");
        IERC20(token).safeTransfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    receive() external payable {}
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}