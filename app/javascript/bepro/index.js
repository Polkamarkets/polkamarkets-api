// bepro-js library interaction with PredictionMarket contract
import * as beprojs from 'bepro-js'
import $ from 'jquery'

const bepro = new beprojs.Application({ mainnet: false })

const getContract = () => {
  return bepro.getPredictionMarketContract({
    contractAddress: process.env.ETHEREUM_CONTRACT_ADDRESS
  })
}

document.addEventListener("turbolinks:load", async (_event) => {
  // starting bepro js (enforcing login immediately)
  bepro.start()
  await bepro.login()

  $('.btn-bepro-create').each(async (_index, btn) => {
    $(btn).on('click', async (event) => {
      const target = event.target

      const contract = getContract()
      try {
        const res = await contract.createMarket({
          name: target.dataset.name,
          duration: target.dataset.duration,
          oracleAddress: target.dataset.oracleAddress,
          outcome1Name: target.dataset.outcome1Name,
          outcome2Name: target.dataset.outcome2Name,
          ethAmount: target.dataset.ethAmount
        })

        // TODO: improve this
        const ethMarketId = parseInt(res.logs[1]['topics'][1])

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
      const contract = getContract()

      // adding text to modal for confirmation purposes
      $(`#bepro-resolve-confirmation-${target.dataset.marketId}`).text(`Waiting resolution tx for ${btn.innerText}...`)

      try {
        const res = await contract.resolveMarketOutcome({
          marketId: target.dataset.ethMarketId,
          outcomeId: target.dataset.ethOutcomeId,
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
})
