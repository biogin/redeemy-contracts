// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@chainlink/v0.8/interfaces/LinkTokenInterface.sol';
import '@chainlink/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import '@chainlink/v0.8/VRFConsumerBaseV2.sol';

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "@redeemy/interfaces/IRewardPoolV1.sol";
import "@redeemy/interfaces/token/IERC1155RedeemTokenV1.sol";

import "./Authorised.sol";

contract RebelRunVRFConsumer is VRFConsumerBaseV2, Authorised, Ownable {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    IAssetPoolV1 ASSET_POOL;

    address public assetPool;

    struct Request {
        bool fulfilled;
        address [] addresses;
    }

    uint256 public constant MAX_WORDS = 500;

    uint256 public REBEL_TICKET_ID;

    uint32 public maxNumAddresses;
    uint32 public maxNumTickets;

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    address public vrfCoordinator;
    address public link;

    uint64 s_subscriptionId;

    bytes32 keyHash;
    uint32 callbackGasLimit;
    uint16 requestConfirmations;

    mapping(uint256 => Request) public _requests;

    mapping(uint256 => EnumerableSet.AddressSet) private _addresses;

    constructor(
        address _rewardPool,
        uint256 _rebelTicketId,

        uint32 _maxNumAddresses,
        uint32 _maxNumTickets,

        address _link,
        address _vrfCoordinator,

        uint64 _subscriptionId,
        bytes32 _key,
        uint32 _gasLimit,
        uint16 _confirmations
    )
    VRFConsumerBaseV2(_vrfCoordinator)
    Authorised(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(_link);

        REBEL_TICKET_ID = _rebelTicketId;

        assetPool = IRewardPoolV1(_rewardPool).getAssetPoolById(_rebelTicketId);
        require(assetPool != address(0));

        ASSET_POOL = IAssetPoolV1(assetPool);

        maxNumTickets = _maxNumTickets;
        maxNumAddresses = _maxNumAddresses;

        vrfCoordinator = _vrfCoordinator;
        link = _link;
        s_subscriptionId = _subscriptionId;
    }

    /* @notice Requests randoms words from chainlink */
    function requestRandomWords(
        address [] calldata addresses,
        uint32 amountOfTickets
    ) external
    onlyAuthorised
    returns (uint256 requestId)
    {
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            amountOfTickets
        );

        _requests[requestId] = Request({
        fulfilled : false,
        addresses : addresses
        });
    }

    /*
    @notice Fulfill the request and send randomness
    */
    function fulfillRandomWords(uint256 _requestId, uint256 [] memory _randomWords) internal override {
        Request memory req = _requests[_requestId];
        require(!req.fulfilled, "RebelRunAddressesVRFConsumer: invalid request id");

        _requests[_requestId].fulfilled = true;

        address [] memory addresses = req.addresses;
        uint256 len = addresses.length;

        for (uint i = 0; i < _randomWords.length && len > 0; ++i) {
            uint256 randomIndex = _randomWords[i] % len;
            address randomAddress = addresses[randomIndex];

            ASSET_POOL.transferRedeemTokenAmount(randomAddress, ASSET_POOL.getRedeemTokenAmount());

            // remove address from the array
            addresses[randomIndex] = addresses[len - 1];
            --len;
            assembly {
                mstore(addresses, len)
            }
        }
    }

    function setAssetPool(address pool) external onlyOwner {
        ASSET_POOL = IAssetPoolV1(IRewardPoolV1(pool).getAssetPoolById(REBEL_TICKET_ID));
    }

    function setRebelTicketId(uint256 id) external onlyOwner {
        REBEL_TICKET_ID = id;
    }

    function setMaxNumAddresses(uint32 _maxNumAddresses) external onlyOwner {
        maxNumAddresses = _maxNumAddresses;
    }

    function setMaxNumTickets(uint32 _maxNumTickets) external onlyOwner {
        maxNumTickets = _maxNumTickets;
    }
}
