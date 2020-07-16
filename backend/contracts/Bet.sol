pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorInterface.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

// Adapted from https://github.com/stampery-labs/witnet-tokenprice-example-contracts/blob/master/contracts/TokenPriceContest.sol

// Adding only the ERC-20 function we need
interface DaiToken {
    function transfer(address dst, uint256 wad) external returns (bool);

    function balanceOf(address guy) external view returns (uint256);
}

contract Bet {
    using SignedSafeMath for int256;
    using SafeMath for uint256;
    using SafeMath for uint8;

    // Chainlink token refs
    AggregatorInterface[] internal chainlinkTokenRefs;

    // DAI token ref
    DaiToken internal dai;

    // Event emitted when a bet is placed by a contest participant
    event BetPlaced(uint8 day, uint8 tokenId, address sender, uint256 value);

    // Timestamp (as seconds since unix epoch) from which the constest starts counting (to enable certain operations)
    uint256 public firstDay;

    // Time period for each contest
    uint256 public contestPeriod;

    // States define the action allowed in the current contest window
    enum DayState {BET, DRAWING, PAYOUT, INVALID}

    // Structure with token participations in a contest period (e.g. day)
    struct TokenDay {
        uint256 totalAmount;
        mapping(address => uint256) participations;
        mapping(address => bool) paid;
        int256 startPrice;
        int256 endPrice;
    }

    // Mapping of token participations
    // Key: `uint16` contains two uint8 refering to day||TokenId
    mapping(uint16 => TokenDay) bets;

    // Structure with all the current bets information in a contest period (e.g. day)
    struct DayInfo {
        // total prize for a day
        uint256 grandPrize;
        // token prices: [token][start, end]
        int256[][2] prices;
    }

    // Mapping of day infos
    mapping(uint8 => DayInfo) dayInfos;

    /// @dev Creates a Token Prize Contest
    /// @param _firstDay timestamp of contest start time
    /// @param _contestPeriod time period (in seconds) of each contest window (e.g. a day)
    constructor(
        uint256 _firstDay,
        uint256 _contestPeriod,
        address _dai,
        address[] memory _chainlinkTokenAddresses
    ) public {
        firstDay = _firstDay;
        contestPeriod = _contestPeriod;
        dai = DaiToken(_dai);

        chainlinkTokenRefs = new AggregatorInterface[](
            _chainlinkTokenAddresses.length
        );
        for (uint8 i = 0; i < _chainlinkTokenAddresses.length; i++) {
            chainlinkTokenRefs[i] = AggregatorInterface(
                _chainlinkTokenAddresses[i]
            );
        }
    }

    // /// @dev Places a bet on a token identifier
    // /// @param _tokenId token identifier
    // function placeBet(uint8 _tokenId, uint256 amt) public payable {
    //   require(msg.value > 0, "Should insert a positive amount");
    //   require(_tokenId < tokenLimit, "Should insert a valid token identifier");

    //   // uint256 amt = msg.value;
    //   require(dai.balanceOf(msg.sender) >= amt && dai.allowance(msg.sender, address(this)) >= amt, "Should have enough dai");
    //   dai.transferFrom(msg.sender, address(this), amt);

    //   // Calculate the day of the current bet
    //   uint8 betDay = getCurrentDay();
    //   // Create Bet: u8Concat
    //   uint16 betId = u8Concat(betDay, _tokenId);

    //   // Upsert Bets mapping (day||tokenId) with TokenDay
    //   bets[betId].totalAmount = bets[betId].totalAmount + msg.value;
    //   bets[betId].participations[msg.sender] += msg.value;
    //   bets[betId].paid[msg.sender] = false;

    //   // Upsert DayInfo (day)
    //   dayInfos[betDay].grandPrize = dayInfos[betDay].grandPrize + msg.value;

    //   emit BetPlaced(betDay, _tokenId, msg.sender, msg.value);
    // }

    // /// @dev Pays out upon data request resolution (i.e. state should be `PAYOUT`)
    // /// @param _day contest day of the payout
    // function payout(uint8 _day) public payable {
    //   require(
    //     getDayState(_day) == DayState.PAYOUT,
    //     "Should be in PAYOUT state"
    //   );

    //   // Result was read but with an error (payout participations)
    //   if (dayInfos[_day].result.length == 0) {
    //     uint16 offset = u8Concat(_day, 0);
    //     for (uint16 i = 0; i<tokenLimit; i++) {
    //       if (bets[i+offset].paid[msg.sender] == false &&
    //         bets[i+offset].participations[msg.sender] > 0) {
    //         bets[i+offset].paid[msg.sender] = true;
    //         msg.sender.transfer(bets[i+offset].participations[msg.sender]);
    //       }
    //     }
    //   } else { // Result is Ok (payout to winners)
    //     // Check legit payout
    //     uint16 dayTokenId = u8Concat(_day, dayInfos[_day].ranking[0]);
    //     require(bets[dayTokenId].paid[msg.sender] == false, "Address already paid");
    //     require(bets[dayTokenId].participations[msg.sender] > 0, "Address has no bets in the winning token");
    //     // Prize calculation
    //     uint256 grandPrize = dayInfos[_day].grandPrize;
    //     uint256 winnerAmount = bets[dayTokenId].totalAmount;
    //     uint256 prize = bets[dayTokenId].participations[msg.sender] * grandPrize / winnerAmount;
    //     // Set paid flag and Transfer
    //     bets[dayTokenId].paid[msg.sender] = true;
    //     msg.sender.transfer(prize);
    //   }
    // }

    /// @dev Gets the timestamp of the current block as seconds since unix epoch
    /// @return timestamp
    function getTimestamp() public virtual returns (uint256) {
        return block.timestamp;
    }

    /// @dev Gets ranking from Witnet Bridge Interface in case that results are still not written into the contract
    /// @param _day contest day of the payout
    function getDayRankingFromChainlink(uint8 _day)
        public
        view
        returns (int256[] memory, uint8[] memory)
    {
        int256[] memory requestResult = new int256[](chainlinkTokenRefs.length);
        for (uint8 i = 0; i < chainlinkTokenRefs.length; i++) {
            uint16 betId = u8Concat(0, i);
            // TokenDay memory bet = bets[betId];
            int256 perf = 0;
            require(bets[betId].startPrice == 1, "s 1");
            require(bets[betId].endPrice == 3, "e 3");
            if (bets[betId].startPrice != 0 && bets[betId].endPrice != 0) {
                perf = (bets[betId].endPrice.sub(bets[betId].startPrice))
                    .div(bets[betId].startPrice)
                    .mul(100);
            }
            requestResult[i] = perf;
        }
        return (requestResult, rank(requestResult));
    }

    function saveCurrentDayRankingFromChainlink() public {
        uint8 betDay = getCurrentDay();
        for (uint8 i = 0; i < chainlinkTokenRefs.length; i++) {
            uint16 betId = u8Concat(0, i);
            int256 latest = 1; // getLatestTokenPrice(i);
            if (bets[betId].startPrice == 0) {
                bets[betId].startPrice = latest;
            } else {
                bets[betId].endPrice = latest;
            }
        }
    }

    function getLatestTokenPrice(uint256 tokenId)
        public
        virtual
        returns (int256)
    {
        AggregatorInterface ref = chainlinkTokenRefs[tokenId];
        return ref.latestAnswer();
    }

    // /// @dev Gets a contest day state
    // /// @param _day contest day
    // /// @return day state
    // function getDayState(uint8 _day) public returns (DayState) {
    //   uint8 currentDay = getCurrentDay();
    //   if (_day == currentDay) {
    //     return DayState.BET;
    //   } else if (_day > currentDay) {
    //     // Bet in the future
    //     return DayState.INVALID;
    //   } else if (dayInfos[_day].grandPrize == 0) {
    //     // BetDay is in the past but there were no bets
    //     return DayState.PAYOUT;
    //   } else if (_day == currentDay - 1) {
    //     // Drawing day
    //     return DayState.DRAWING;
    //   }  else {
    //     // BetDay is in the past with bets
    //     return DayState.PAYOUT;
    //   }
    // }

    // /// @dev Reads the total amount bet for a day and a token identifier
    // /// @param _day contest day
    // /// @param _tokenId token identifier
    // /// @return total amount of bets
    // function getTotalAmountTokenDay(uint8 _day, uint8 _tokenId) public view returns (uint256) {
    //   return bets[u8Concat(_day, _tokenId)].totalAmount;
    // }

    // /// @dev Reads the participations of the sender for a given day
    // /// @param _day contest day
    // /// @return array with the participations for each token
    // function getMyBetsDay(uint8 _day) public view returns (uint256[] memory) {
    //   uint256[] memory results = new uint256[](tokenLimit);
    //   uint16 offset = u8Concat(_day, 0);
    //   for (uint16 i = 0; i<tokenLimit; i++) {
    //     results[i] = bets[i+offset].participations[msg.sender];
    //   }
    //   return results;
    // }

    // /// @dev Reads the participations and wins of the sender for a given day
    // /// @param _day contest day
    // /// @return array with the participations for each token
    // function getMyBetsDayWins(uint8 _day) public view returns (uint256[] memory, uint256) {
    //   uint256[] memory results = getMyBetsDay(_day);
    //   uint256 amount = getMyDayWins(_day);
    //   return (results, amount);
    // }

    // function getMyDayWins(uint8 _day) public view returns (uint256) {
    //   uint256 amount;
    //   // Data request is not yet resolved or is still beeing resolved within Witnet
    //   if (dayInfos[_day].witnetRequestId == 0 || !isResultReady(_day)) {
    //     return amount;
    //   }

    //   // Data request is already in WBI or in the contract
    //   uint8[] memory ranking = new uint8[](tokenLimit);

    //   // Calculate Ranking
    //   if (dayInfos[_day].witnetReadResult) {
    //     ranking = dayInfos[_day].ranking;
    //   } else { // Data request is in WBI but not in contract -> read from WBI
    //     Witnet.Result memory result = witnetReadResult(dayInfos[_day].witnetRequestId);
    //     if (result.isOk()) {
    //       // Data Request is OK -> compute...
    //       ranking = rank(result.asInt128Array());
    //     }
    //   }

    //   // Empty ranking -> return back participations
    //   if (ranking.length == 0) {
    //     // Data request with ERROR -> return money to all participants
    //     uint16 offset = u8Concat(_day, 0);
    //     for (uint16 i = 0; i<tokenLimit; i++) {
    //       if (bets[i+offset].paid[msg.sender] == false &&
    //         bets[i+offset].participations[msg.sender] > 0) {
    //         // bets[i+offset].paid[msg.sender] = true;
    //         amount += bets[i+offset].participations[msg.sender];
    //       }
    //     }
    //     return amount;
    //   }

    //   // Ranking available -> compute prize for participant
    //   uint16 dayTokenId = u8Concat(_day, ranking[0]);
    //   // Already paid or not participated
    //   if (bets[dayTokenId].paid[msg.sender] || bets[dayTokenId].participations[msg.sender] == 0) {
    //     return amount;
    //   }
    //   // Prize calculation
    //   uint256 grandPrize = dayInfos[_day].grandPrize;
    //   uint256 winnerAmount = bets[dayTokenId].totalAmount;
    //   uint256 prize = bets[dayTokenId].participations[msg.sender] * grandPrize / winnerAmount;

    //   return prize;
    // }

    // /// @dev Reads day information
    // /// @param _day contest day
    // /// @return day info structure
    // function getDayInfo(uint8 _day) public view returns (DayInfo memory) {
    //   return dayInfos[_day];
    // }

    /// @dev Read last block timestamp and calculate difference with firstDay timestamp
    /// @return index of current day
    function getCurrentDay() public returns (uint8) {
        uint256 timestamp = getTimestamp();
        uint256 daysDiff = (timestamp - firstDay) / contestPeriod;

        return uint8(daysDiff);
    }

    /// @dev Concatenates two `uint8`
    /// @param _l left component
    /// @param _r right component
    /// @return _l||_r
    function u8Concat(uint8 _l, uint8 _r) internal pure returns (uint16) {
        return (uint16(_l) << 8) | _r;
    }

    /// @dev Ranks a given input array
    /// @param input array to be ordered
    /// @return ordered array
    function rank(int256[] memory input)
        internal
        pure
        returns (uint8[] memory)
    {
        // Ranks the given input array
        uint8[] memory ranked = new uint8[](input.length);
        uint8[] memory result = new uint8[](input.length);

        for (uint8 i = 0; i < input.length; i++) {
            uint8 curRank = 0;
            for (uint8 j = 0; j < i; j++) {
                if (input[j] > input[i]) {
                    curRank++;
                } else {
                    ranked[j]++;
                }
            }
            ranked[i] = curRank;
        }

        for (uint8 i = 0; i < ranked.length; i++) {
            result[ranked[i]] = i;
        }
        return result;
    }
}