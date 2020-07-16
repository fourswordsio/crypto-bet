const BetTestHelper = artifacts.require("BetTestHelper")
const truffleAssert = require("truffle-assertions")

const NOOP_ADDR = "0x0853E36EeAd0eAA08D61E94237168696383869DD"
const NO_OF_TOKENS = 3
const FIRST_DAY = Math.round(new Date().getTime() / 1000 - 100)

contract("BetTestHelper", (accounts) => {
  const DayState = {
    BET: 0,
    DRAWING: 1,
    PAYOUT: 2,
    INVALID: 3,
  }
  let contest

  before(async () => {
    const day = 60 * 60 * 24
    contest = await BetTestHelper.new(
      FIRST_DAY,
      day,
      NOOP_ADDR,
      new Array(NO_OF_TOKENS).fill("0x0853E36EeAd0eAA08D61E94237168696383869DD")
    )
  })

  xdescribe("Concatenate uint8 into uint16: ", () => {
    it("should concat 0xff 0xee", async () => {
      const result = await contest.u8ConcatPub.call(
        web3.utils.hexToBytes("0xff"),
        web3.utils.hexToBytes("0xee")
      )
      assert.equal(web3.utils.toHex(result), "0xffee")
    })
    it("should concat 0x00 0xee", async () => {
      const result = await contest.u8ConcatPub.call(
        web3.utils.hexToBytes("0x00"),
        web3.utils.hexToBytes("0xee")
      )
      assert.equal(web3.utils.toHex(result), 0xee)
    })
    it("should concat 0xff 0x00", async () => {
      const result = await contest.u8ConcatPub.call(
        web3.utils.hexToBytes("0xff"),
        web3.utils.hexToBytes("0x00")
      )
      assert.equal(web3.utils.toHex(result), "0xff00")
    })
  })

  xdescribe("Rank int128 array: ", () => {
    it("should rank [3, 0, 15, 5, 6, 8, 6, 1]", async () => {
      const result = await contest.rankPub.call([3, 0, 15, 5, 6, 8, 6, 1])
      const expected = [2, 5, 6, 4, 3, 0, 7, 1]
      var i
      for (i = 0; i < result.length; i++) {
        assert.equal(web3.utils.toHex(result[i]), expected[i])
      }
    })
    it("should rank [1, 4, 16, 12, 0, 7, 3]", async () => {
      const result = await contest.rankPub.call([1, 4, 16, 12, 0, 7, 3])
      const expected = [2, 3, 5, 1, 6, 0, 4]
      var i
      for (i = 0; i < result.length; i++) {
        assert.equal(web3.utils.toHex(result[i]), expected[i])
      }
    })
  })

  // describe("Get day states: ", () => {
  //   const day0 = Math.round(new Date().getTime() / 1000)
  //   const now0 = day0 + 2 * 60 * 60
  //   const now1 = day0 + 26 * 60 * 60

  //   it("should get day state BET because its today", async () => {
  //     const tx = contest.setTimestamp(now0)
  //     waitForHash(tx)
  //     const result = await contest.getDayState.call(0)
  //     assert.equal(result.toNumber(), DayState.BET)
  //   })
  //   it("should get day state PAYOUT because (for yesterday and no bets)", async () => {
  //     const tx = contest.setTimestamp(now1)
  //     waitForHash(tx)
  //     const result = await contest.getDayState.call(0)
  //     assert.equal(result.toNumber(), DayState.PAYOUT)
  //   })
  //   it("should get day state INVALID because is for tomorrow", async () => {
  //     const tx = contest.setTimestamp(now0)
  //     waitForHash(tx)
  //     const result = await contest.getDayState.call(1)
  //     assert.equal(result.toNumber(), DayState.INVALID)
  //   })
  // })

  describe("Cron: ", () => {
    it("Should set latest price", async () => {
      await contest.setTimestamp(FIRST_DAY, {
        from: accounts[1],
      })
      console.log((await contest.getCurrentDay.call()).toNumber())
      // let result = await contest.getDayRankingFromChainlink.call(0)
      //
      await contest.setLatestTokenPrice(1, {
        from: accounts[1],
      })
      await contest.saveCurrentDayRankingFromChainlink.call({
        from: accounts[1],
      })
      //
      await contest.setLatestTokenPrice(3, {
        from: accounts[1],
      })
      await contest.saveCurrentDayRankingFromChainlink.call({
        from: accounts[1],
      })
      //
      result = await contest.getDayRankingFromChainlink.call(0)
      assert.equal(result["0"][0].toNumber(), 200)
      assert.equal(result["1"][0].toNumber(), 2)
      assert.equal(result["1"][1].toNumber(), 1)
      assert.equal(result["1"][2].toNumber(), 0)
    })
  })

  xdescribe("Place bets: ", () => {
    const day0 = Math.round(new Date().getTime() / 1000)
    const now1 = day0 + 26 * 60 * 60
    const now2 = day0 + 52 * 60 * 60
    const now3 = day0 + 74 * 60 * 60

    it("Should set timestamp to now", async () => {
      await contest.setTimestamp(day0, {
        from: accounts[1],
      })
      const result = await contest.getTimestamp.call()
      assert.equal(day0, result)
    })

    //   it("should read that there is no bet", async () => {
    //     const result = await contest.getTotalAmountTokenDay.call(0, 0)
    //     assert.equal(result, web3.utils.toWei("0", "ether"))
    //   })
    //   it("should be able to place bet", async () => {
    //     const tx = contest.placeBet(0, {
    //       from: accounts[0],
    //       value: web3.utils.toWei("1000", "wei"),
    //     })
    //     waitForHash(tx)
    //   })
    //   it("should be revert due to place bet with 0 value", async () => {
    //     await truffleAssert.reverts(
    //       contest.placeBet(0, {
    //         from: accounts[0],
    //         value: web3.utils.toWei("0", "wei"),
    //       }),
    //       "Should insert a positive amount"
    //     )
    //   })
    //   it("should read the total amount of previous bet", async () => {
    //     const result = await contest.getTotalAmountTokenDay.call(0, 0)
    //     assert.equal(result, web3.utils.toWei("1000", "wei"))
    //   })
    //   it("should be able to place a second bet", async () => {
    //     const tx = contest.placeBet(1, {
    //       from: accounts[0],
    //       value: web3.utils.toWei("1000", "wei"),
    //     })
    //     waitForHash(tx)
    //   })
    //   it("should read the total amount of the day", async () => {
    //     const result = await contest.getDayInfo.call(0)
    //     assert.equal(result[0], web3.utils.toWei("2000", "wei"))
    //   })
    //   it("should read my total bets of the day", async () => {
    //     const result = await contest.getMyBetsDay.call(0)
    //     assert.equal(result[0], web3.utils.toWei("1000", "wei"))
    //     assert.equal(result[1], web3.utils.toWei("1000", "wei"))
    //     assert.equal(result[6], web3.utils.toWei("0", "wei"))
    //   })
    //   it("should be able to place a third bet from another address", async () => {
    //     const tx = contest.placeBet(6, {
    //       from: accounts[1],
    //       value: web3.utils.toWei("1000", "wei"),
    //     })
    //     waitForHash(tx)
    //   })
    //   it("should read bets from another address", async () => {
    //     const result = await contest.getMyBetsDay.call(0, {from: accounts[1]})
    //     assert.equal(result[0], web3.utils.toWei("0", "wei"))
    //     assert.equal(result[1], web3.utils.toWei("0", "wei"))
    //     assert.equal(result[6], web3.utils.toWei("1000", "wei"))
    //   })
    //   it("should get day state WAIT because (for yesterday and we have bets)", async () => {
    //     const tx = contest.setTimestamp(now1, {
    //       from: accounts[1],
    //     })
    //     waitForHash(tx)
    //     const result = await contest.getDayState.call(0)
    //     assert.equal(result.toNumber(), DayState.WAIT)
    //   })
    //   it("should be able to place a bet in the second day", async () => {
    //     const tx = contest.placeBet(6, {
    //       from: accounts[1],
    //       value: web3.utils.toWei("1000", "wei"),
    //     })
    //     waitForHash(tx)
    //   })
    //   it("should be able to place a second bet in the second day", async () => {
    //     const tx = contest.placeBet(3, {
    //       from: accounts[2],
    //       value: web3.utils.toWei("1000", "wei"),
    //     })
    //     waitForHash(tx)
    //   })
    //   it("should revert due to bet are not in RESOLVE state", async () => {
    //     await truffleAssert.reverts(
    //       contest.resolve(0, {
    //         from: accounts[0],
    //         value: 2,
    //       }),
    //       "Should be in RESOLVE state"
    //     )
    //   })
    //   it("should get day state RESOLVE because (for 2 days ago with bets)", async () => {
    //     const tx = contest.setTimestamp(now2, {
    //       from: accounts[1],
    //     })
    //     waitForHash(tx)
    //     const result = await contest.getDayState.call(0)
    //     assert.equal(result.toNumber(), DayState.RESOLVE)
    //   })
    //   it("should revert due to have not enough value to resolve the data request", async () => {
    //     const tx = contest.setTimestamp(now2, {
    //       from: accounts[1],
    //     })
    //     waitForHash(tx)
    //     await truffleAssert.reverts(
    //       contest.resolve(0, {
    //         from: accounts[0],
    //         value: 0,
    //       }),
    //       "Not enough value to resolve the data request"
    //     )
    //   })
    //   it("should revert due to bet are not in WAIT_RESULT or PAYOUT state", async () => {
    //     await truffleAssert.reverts(
    //       contest.payout(0, {
    //         from: accounts[0],
    //       }),
    //       "Should be in WAIT_RESULT or PAYOUT state"
    //     )
    //   })
    //   it("should get day state WAIT_RESULT after calling resolve)", async () => {
    //     const tx = contest.setTimestamp(now2, {
    //       from: accounts[1],
    //     })
    //     waitForHash(tx)
    //     const resolveTx = contest.resolve(0, {
    //       from: accounts[1],
    //       value: 2,
    //     })
    //     waitForHash(resolveTx)
    //     const result = await contest.getDayState.call(0, {
    //       from: accounts[1],
    //     })
    //     assert.equal(result.toNumber(), DayState.WAIT_RESULT)
    //   })
    //   it("should revert when trying to read a result that is not ready", async () => {
    //     await truffleAssert.reverts(
    //       contest.payout.call(0, {
    //         from: accounts[0],
    //       }),
    //       "Found empty buffer when parsing CBOR value"
    //     )
    //   })
    //   it("should call payout with succesful result and refund winnet", async () => {
    //     const resBytes = web3.utils.hexToBytes("0x8A1A0001869F02030405060708090A")
    //     let balanceBefore = await web3.eth.getBalance(contest.address)
    //     await wbi.setDrResult(resBytes, 1, {
    //       from: accounts[1],
    //     })
    //     await contest.payout(0, {
    //       from: accounts[0],
    //     })

    //     let balanceAfter = await web3.eth.getBalance(contest.address)
    //     assert.equal(parseInt(balanceAfter), parseInt(balanceBefore) - 3000)
    //   })
    //   it("should revert because contestant already paid", async () => {
    //     await truffleAssert.reverts(
    //       contest.payout(0, {
    //         from: accounts[0],
    //       }),
    //       "Address already paid"
    //     )
    //   })
    //   it("should revert because contestant has no bets in the winning token", async () => {
    //     await truffleAssert.reverts(
    //       contest.payout(0, {
    //         from: accounts[2],
    //       }),
    //       "Address has no bets in the winning token"
    //     )
    //   })
    //   it("should get day state WAIT_RESULT after calling resolve the second day", async () => {
    //     const tx = contest.setTimestamp(now3, {
    //       from: accounts[1],
    //     })
    //     waitForHash(tx)
    //     const resolveTx = contest.resolve(1, {
    //       from: accounts[1],
    //       value: 2,
    //     })
    //     waitForHash(resolveTx)
    //     const result = await contest.getDayState.call(1, {
    //       from: accounts[1],
    //     })
    //     assert.equal(result.toNumber(), DayState.WAIT_RESULT)
    //   })

    //   it("should call payout with unsuccesful result and pay each one their bet", async () => {
    //     const resBytes = web3.utils.hexToBytes("0xD8270001869F02030405060708090A")
    //     let balanceBefore = await web3.eth.getBalance(contest.address)
    //     await wbi.setDrResult(resBytes, 2, {
    //       from: accounts[1],
    //     })
    //     await contest.payout(1, {
    //       from: accounts[1],
    //     })

    //     let balanceAfter = await web3.eth.getBalance(contest.address)
    //     assert.equal(parseInt(balanceAfter), parseInt(balanceBefore) - 1000)
    //   })
  })
})