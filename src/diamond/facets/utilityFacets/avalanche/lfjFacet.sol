pragma solidity ^0.8.0;


import {LBRouter} from "../../../../interfaces/arbitrumOne/LBRouter.sol";
import {ILBFactory} from "../../../../interfaces/arbitrumOne/ILBFactory.sol";
import { LibDiamond} from "src/diamond/libraries/LibDiamond.sol";
import {ILBRouter, LiquidityParameters, Path} from "src/interfaces/arbitrumOne/ILBRouter.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

error LBRouterFacet_NotInitialized();
error LBRouterFacet_AlreadyInitialized();
error LBRouterFacet_ZeroAddress();
error LBRouterFacet_DeadlinePassed();
error LBRouterFacet_InsufficientBalance();
error LBRouterFacet_ApprovalFailed();
error LBRouterFacet_PoolNotRegistered();
error LBRouterFacet_InvalidPath();
error LBRouterFacet_ArrayLengthMismatch();
error LBRouterFacet_TooManyBins();
error LBRouterFacet_Paused();
error LBRouterFacet_NotOwner();

//events
event LBRouterInitialized(address indexed router, address indexed factory, uint16 binStep);
event LiquidityAdded(address indexed pair, uint256 amountX, uint256 amountY, uint256[] depositIds);
event LiquidityRemoved(address indexed pair, uint256 amountX, uint256 amountY);
event SwapExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
event Swept(address indexed token, address indexed to, uint256 amount);
event Paused(bool paused);


//@notice This is a wrapper contract for user facing liquidity book v2 contract LBRouter which has all the swap and liquidity functions
contract lfgFacetV2 is ILBRouter {
    
    bytes32 internal constant STORAGE_SLOT = keccak256("traderjoe.v2.storage");

    struct Storage {
        address lbRouter;
        address lbFactory;
        uint16 defaultBinStep;
        bool initialized;
        bool paused;
    }

    function s() internal pure returns (Storage storage ds) {
        assembly { ds.slot := STORAGE_SLOT }
    }

    //modifiers
    modifier whenNotPaused(){
        if (s().paused) revert LBRouterFacet_Paused();
        _;
    }
    modifier onlyOwner(){
        LibDiamond.enforceIsContractOwner();
        _;
    }

    function _router() internal view returns (ILBRouter) {
        address router = s().lbRouter;
        if (router == address(0)) revert LBRouterFacet_NotInitialized();
        return ILBRouter(router);
    }
    function initTraderJoeV2(address _lbRouter,address _lbFactory, uint16 _binStep) external {
        LibDiamond.enforceIsContractOwner();
        Storage storage ds = s();
        
        if (ds.initialized) revert LBRouterFacet_AlreadyInitialized();
        if (_lbRouter == address(0) || _lbFactory == address(0)) revert LBRouterFacet_ZeroAddress();
        ds.lbFactory = _lbFactory;
        ds.defaultBinStep = _binStep;
        ds.lbRouter = _lbRouter;
        ds.initialized = true;

        emit LBRouterInitialized(_lbRouter, _lbFactory, _binStep);
    }
    
    //@notice  checks if a pool is registered in the liquidity pool registry
    //@param pair The address of the pair to be checked
    function _checkPoolRegistered(address pair) internal view {
        address registry = LibDiamond.liquidityPoolRegistry();
        if (!IPoolRegistry(registry).isPoolRegistered(pair)) {
            revert LBRouterFacet_PoolNotRegistered();
    }

    // validations and safe approve 
    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            if (!token.approve(spender, 0)) revert LBRouterFacet_ApprovalFailed();
        }
        if (!token.approve(spender, amount)) revert LBRouterFacet_ApprovalFailed();
    }

    function _validatePath(Path memory path) internal pure {
        if (path.pairBinSteps.length < 1 || path.tokenPath.length < 2) {
            revert LBRouterFacet_InvalidPath();
        }
        if (path.pairBinSteps.length != path.tokenPath.length - 1) {
            revert LBRouterFacet_ArrayLengthMismatch();
        }
    }
    //@notice  This is the primary pair creation function
    //@param tokenX The address of token X
    //@param tokenY The address of token Y
    //@param activeId The active id of the pair
    //@param binStep The bin step of the pair
    //@return pair The actual created pair
    function createLBPair(address tokenX,address tokenY,uint24 activeId, uint16 binStep) external onlyOwnerreturns (ILBPair pair) {
        Storage storage ds = s();
        if (binStep == 0) binStep = ds.defaultBinStep;
        pair = ILBFactory(ds.lbFactory).createLBPair(
            IERC20(tokenX),
            IERC20(tokenY),
            binStep,
            activeId
        );
        _checkPoolRegistered(address(pair));
    }

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //@notice All the view functions can be directly called from the LBRouter contract but  dosent seem necessary in this wrapper

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    //@notice This is primary liquidity addition function, not native only erc20 liquidity addition
    //@param liquidityParameters The struct containing all the liquidity parameters
    //@return amountXAdded The amount of token X added
    //@return amountYAdded The amount of token Y added
    //@return amountXLeft The amount of token X left        
    //@return amountYLeft The amount of token Y left
    //@return depositIds The deposit ids of the added liquidity
    //@return liquidityMinted The amount of liquidity minted
    function addLiquidity(LiquidityParameters calldata liquidityParameters) external whenNotPaused override returns (uint256 amountXAdded, uint256
    amountYAdded, uint256 amountXLeft, uint256 amountYLeft, uint256[] memory depositIds, uint256[] memory liquidityMinted) {
       if (block.timestamp > params.deadline) revert LBRouterFacet_DeadlinePassed();
        if (params.amountX > 0 && IERC20(params.tokenX).balanceOf(address(this)) < params.amountX)
            revert LBRouterFacet_InsufficientBalance();
        if (params.amountY > 0 && IERC20(params.tokenY).balanceOf(address(this)) < params.amountY)
            revert LBRouterFacet_InsufficientBalance();

        // Safe approval
        if (params.amountX > 0) _safeApprove(IERC20(params.tokenX), s().lbRouter, params.amountX);
        if (params.amountY > 0) _safeApprove(IERC20(params.tokenY), s().lbRouter, params.amountY);

        (amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted) = _router().addLiquidity(liquidityParameters);
        emit LiquidityAdded(params.tokenX, params.tokenY, amountXAdded, amountYAdded, depositIds);
    }

    //@notice This is primary liquidity addition function, native liquidity addition
    //@param liquidityParameters The struct containing all the liquidity parameters
    //@return amountXAdded The amount of token X added
    //@return amountYAdded The amount of token Y added
    //@return amountXLeft The amount of token X left        
    //@return amountYLeft The amount of token Y left
    //@return depositIds The deposit ids of the added liquidity
    //@return liquidityMinted The amount of liquidity minted    
    function addLiquidityNative(LiquidityParameters calldata liquidityParameters) external whenNotPaused payable returns (uint256 amountXAdded, uint256 amountYAdded, uint256 amountXLeft, uint256 amountYLeft, uint256[] memory depositIds, uint256[] memory liquidityMinted) {
        if (block.timestamp > params.deadline) revert LBRouterFacet_DeadlinePassed();
        if (msg.value == 0) revert LBRouterFacet_InsufficientBalance();
        if (params.amountX > 0) _safeApprove(IERC20(params.tokenX), s().lbRouter, params.amountX);
        (amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted) = _router().addLiquidityNative{value: msg.value}(liquidityParameters);
    emit LiquidityAdded(params.tokenX, address(0), amountXAdded, msg.value, depositIds);
    }
    
    
    /////////////////////////////////////////////////////////////////////
    //@notice This is primary liquidity remove function, non-native liquidity removal
    //@param tokenX The address of token X          
    //@param tokenY The address of token Y
    //@param binStepX The bin step of token X
    //@param binStepY The bin step of token Y
    //@param amountXMin The minimum amount of token X to be removed
    //@param amountYMin The minimum amount of token Y to be removed 
    //@param ids The deposit ids of the liquidity to be removed
    //@param amounts The amounts of liquidity to be removed
    //@param to The address to which the removed liquidity is sent
    //@param deadline The deadline for the liquidity removal
    //@return amountX The amount of token X removed
    //@return amountY The amount of token Y removed         

    function removeLiquidity(IERC20 tokenX,IERC20 tokenY,uint16 binStepX,uint16 binStepY,uint256 amountXMin,
    uint256 amountYMin,uint256[] memory ids,uint256[] memory amounts,address to,uint256 deadline) external whenNotPaused returns (uint256 amountX, uint256 amountY) {
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (ids.length != amounts.length) revert LBRouterFacet_ArrayLengthMismatch();
        if (ids.length > 50) revert LBRouterFacet_TooManyBins();    
            (amountX, amountY) = _router().removeLiquidity(
            tokenX, tokenY, binStepX, binStepY,amountXMin, amountYMin, ids, amounts, to, deadline);
        emit LiquidityRemoved(address(tokenX), address(tokenY), amountX, amountY);
    }
    //@notice This is primary liquidity removal function, native liquidity removal
    //@param token The address of token to be removed along with native token
    //@param binStep The bin step of the token      
    //@param amountTokenMin The minimum amount of token to be removed
    //@param amountNATIVEmin The minimum amount of native token to be removed
    //@param ids The deposit ids of the liquidity to be removed
    //@param amounts The amounts of liquidity to be removed
    //@param to The address to which the removed liquidity is sent
    //@param deadline The deadline for the liquidity removal
    //@return amountToken The amount of token removed
    //@return amountNATIVE The amount of native token removed

    function removeLiquidityNative(IERC20 token,uint16 binStep,uint256 amountTokenMin, uint256 amountNATIVEmin,uint256[] memory ids, uint256[] memory amounts, address payable to, uint256 deadline ) external whenNotPaused override returns( uint256 amountToken, uint256 amountNATIVE){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (ids.length != amounts.length) revert LBRouterFacet_ArrayLengthMismatch();
        if (ids.length > 50) revert LBRouterFacet_TooManyBins();
        (amountToken, amountNATIVE) = _router().removeLiquidityNative(token, binStep, amountTokenMin, amountNATIVEEmin,ids, amounts, to, deadline);
        emit LiquidityRemoved(address(token), address(0), amountToken, amountNATIVE);
    }

    
    //@notice swap functions 
    //@notice  standard swaps without fee on transfer tokens
    //@param amountIn The amount of input tokens
    //@param amountOutMin The minimum amount of output tokens
    //@param path The path of the swap  
    
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Path memory path, address to, uint256 deadline) external whenNotPaused override returns(uint256 amountOut){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        _validatePath(path);
        if (IERC20(path.tokenPath[0]).balanceOf(address(this)) < amountIn)
            revert LBRouterFacet_InsufficientBalance();

        _safeApprove(IERC20(path.tokenPath[0]), s().lbRouter, amountIn);
        amountOut = _router().swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
        emit TokensSwapped(path.tokenPath[0], path.tokenPath[path.tokenPath.length - 1], amountIn, amountOut);
    } 

    function swapExactTokensForNative(uint256 amountIn, uint256 amountOutMinNATIVE, Path memory path, address payable to, uint256 deadline) external whenNotPaused override returns(uint256 amountOut){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        _validatePath(path);
        if (IERC20(path.tokenPath[0]).balanceOf(address(this)) < amountIn)
            revert LBRouterFacet_InsufficientBalance();

        _safeApprove(IERC20(path.tokenPath[0]), s().lbRouter, amountIn);
        amountOut = _router().swapExactTokensForNative(amountIn, amountOutMinNATIVE, path, to, deadline);
        emit TokensSwapped(path.tokenPath[0], address(0), amountIn, amountOut);
    }

    function swapExactNativeForTokens(uint256 amountOutMin, Path memory path, address to, uint256 deadline) external whenNotPaused override payable returns(uint256 amountOut){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (msg.value == 0) revert LBRouterFacet_InsufficientBalance();
        _validatePath(path);
        amountOut = _router().swapExactNativeForTokens{value: msg.value}(amountOutMin, path, to, deadline);
        emit SwapExecuted(address(0), path.tokenPath[path.tokenPath.length - 1], msg.value, amountOut);

    }

    function swapTokensForExactTokens(uint256 amountOut, Path memory path, address to, uint256 deadline) external whenNotPaused override returns(uint256[] memory amountIn){

        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (amountOut == 0 || amountInMax == 0) revert LBRouterFacet_InvalidAmount();
        _validatePath(path);

        IERC20 tokenIn = IERC20(path.tokenPath[0]);
        if (tokenIn.balanceOf(address(this)) < amountInMax)
        revert LBRouterFacet_InsufficientBalance();

        _safeApprove(tokenIn, s().lbRouter, amountInMax);
        amountIn = _router().swapTokensForExactTokens(amountOut,amountInMax, path, to, deadline);
        emit SwapExecuted(path.tokenPath[0],path.tokenPath[path.tokenPath.length - 1],amountsIn[0],amountOut);
    
    
    }
    function swapTokensForExactNATIVE(uint256 amountOut, uint256 amountInMax, Path memory path, address payable to, uint256 deadline) external whenNotPaused override returns(uint256 amountsIn){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (amountOut == 0 || amountInMax == 0) revert LBRouterFacet_InvalidAmount();
            _validatePath(path);

        IERC20 tokenIn = IERC20(path.tokenPath[0]);
        if (tokenIn.balanceOf(address(this)) < amountInMax)
        revert LBRouterFacet_InsufficientBalance();

        _safeApprove(tokenIn, s().lbRouter, amountInMax);
        
        amountsIn = _router().swapTokensForExactNative(amountOut, amountInMax, path, to, deadline);
        emit SwapExecuted(path.tokenPath[0], address(0), amountsIn[0], amountOut);
    }
    function swapNATIVEForExactTokens(uint256 amountOut, Path memory path, address to, uint256 deadline) external payable whenNotPausedoverride returns (uint256[] memory amountsIn) {
           if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
            if (msg.value == 0 || amountOut == 0) revert LBRouterFacet_InvalidAmount();
            _validatePath(path);
        amountsIn = _router().swapNATIVEForExactTokens{value: msg.value}(amountOut, path, to, deadline);
        emit SwapExecuted(address(0), path.tokenPath[path.tokenPath.length - 1], msg.value, amountOut);
    }


    //@notice  swaps with fee on transfer tokens

    //@param amountIn The amount of input tokens
    //@param amountOutMin The minimum amount of output tokens
    //@param path The path of the swap
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, Path memory path, address to, uint256 deadline) external whenNotPaused override returns(uint256 amountOut){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (amountIn == 0) revert LBRouterFacet_InvalidAmount();
        _validatePath(path);

        IERC20 tokenIn = IERC20(path.tokenPath[0]);
        if (tokenIn.balanceOf(address(this)) < amountIn)
            revert LBRouterFacet_InsufficientBalance();

        _safeApprove(tokenIn, s().lbRouter, amountIn);

        amountOut = _router().swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, deadline);
        emit SwapExecuted(path.tokenPath[0], path.tokenPath[path.tokenPath.length - 1], amountIn, amountOut);
    }

    function swapExactTokensForNATIVESupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMinNATIVE, Path memory path, address payable to, uint256 deadline) external whenNotPaused override returns(uint256 amountOut){
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (amountIn == 0) revert LBRouterFacet_InvalidAmount();
        _validatePath(path);

            IERC20 tokenIn = IERC20(path.tokenPath[0]);
        if (tokenIn.balanceOf(address(this)) < amountIn)
            revert LBRouterFacet_InsufficientBalance();

        _safeApprove(tokenIn, s().lbRouter, amountIn);
        amountOut = _router().swapExactTokensForNATIVESupportingFeeOnTransferTokens(amountIn, amountOutMinNATIVE, path, to, deadline);
        emit SwapExecuted(path.tokenPath[0], address(0), amountIn, amountOut);
    }
    function swapExactNATIVEForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, Path memory path, address to, uint256 deadline) external payable whenNotPaused override returns(uint256 amountOut){  
        if (block.timestamp > deadline) revert LBRouterFacet_DeadlinePassed();
        if (msg.value == 0) revert LBRouterFacet_InsufficientBalance();
        _validatePath(path);
        amountOut = _router().swapExactNATIVEForTokensSupportingFeeOnTransferTokens{value: msg.value}(amountOutMin, path, to, deadline);
        emit SwapExecuted(address(0), path.tokenPath[path.tokenPath.length - 1], msg.value, amountOut);
    }


    //@dev these are originally admin based functions in main router
    function sweep(IERC20 token, uint256 amount,address to) external override{
        _router().sweep(to, amount, token);
    }

    function sweepLBToken(ILBToken _lbToken, address to, uint256[] calldata _ids, uint256[] calldata _amounts) external override {
        _router().sweepLBToken(_lbToken, to , _amounts);
    }

    //fallback 
    receive() external payable {}
}