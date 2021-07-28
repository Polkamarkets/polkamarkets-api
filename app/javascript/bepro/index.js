// bepro-js library interaction with PredictionMarket contract
import "regenerator-runtime/runtime.js";
import * as beprojs from 'bepro-js'
import $ from 'jquery'

const bepro = new beprojs.Application({ mainnet: false })

const getBeproContract = () => {
  return bepro.getPredictionMarketContract({
    contractAddress: process.env.ETHEREUM_CONTRACT_ADDRESS
  })
}

const getRealitioContract = () => {
  return bepro.getRealitioERC20Contract({
    contractAddress: process.env.ETHEREUM_REALITIO_ERC20_CONTRACT_ADDRESS
  })
}

document.addEventListener("turbolinks:load", async (_event) => {
  // starting bepro js (enforcing login immediately)
  bepro.start()
  await bepro.login()

  const contract = getBeproContract()
  console.log(contract);

  $('.btn-bepro-create').each(async (_index, btn) => {
    $(btn).on('click', async (event) => {
      const target = event.target

      const contract = getBeproContract()
      try {
        const res = await contract.createMarket({
          name: target.dataset.name,
          duration: target.dataset.duration,
          oracleAddress: target.dataset.oracleAddress,
          outcomes: [target.dataset.outcome1Name, target.dataset.outcome2Name],
          ethAmount: target.dataset.ethAmount
        })

        const ethMarketId = parseInt(res.events.MarketLiquidity.returnValues[0])

        $.post(
          `/admin/markets/${target.dataset.marketId}/publish`,
          { eth_market_id: ethMarketId }
        )
      } catch (e) {
        // do nothing, only take action when successful
        console.log('Error creating market')
        console.log(e)
      }
    })
  })

  $('.btn-bepro-resolve').each(async (_index, btn) => {
    $(btn).on('click', async (event) => {
      const target = event.target
      const contract = getBeproContract()

      try {
        const res = await contract.resolveMarketOutcome({
          marketId: target.dataset.ethMarketId
        })

        $.post(
          `/admin/markets/${target.dataset.marketId}/resolve`
        )
      } catch (e) {
        // do nothing, only take action when successful
        console.log('Error resolving market')
        console.log(e)
      }
    })
  })

  $('.btn-bepro-answer').each(async (_index, btn) => {
    $(btn).on('click', async (event) => {
      const target = event.target
      const realitioContract = getRealitioContract()
      const answerId = realitioContract.params.web3.eth.abi.encodeParameter('int256', String(target.dataset.ethOutcomeId));
      const amount = parseInt(target.dataset.erc20Amount) || 1;

      // adding text to modal for confirmation purposes
      $(`#bepro-resolve-confirmation-${target.dataset.marketId}`).text(`Waiting resolution tx for ${btn.innerText}...`)

      try {
        const res = await realitioContract.submitAnswerERC20({
          questionId: target.dataset.questionId,
          answerId,
          amount
        })
      } catch (e) {
        // do nothing, only take action when successful
        console.log('Error answering market')
        console.log(e)
      }
    })
  })
})
