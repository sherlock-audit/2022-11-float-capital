# pip install -U pycoingecko
# https://www.coingecko.com/en/api/documentation

import numpy as np
import json
from datetime import datetime
from pycoingecko import CoinGeckoAPI

epoch_length = 3600
mewt = 10

fetchPricesFromCG = False

if fetchPricesFromCG:
    now = int(datetime.now().timestamp())
    past = now - 90*24*60*60

    cg = CoinGeckoAPI()
    data = cg.get_coin_market_chart_range_by_id(id='ethereum', vs_currency='usd', from_timestamp=str(past), to_timestamp=str(now), interval='hourly')

    with open("eth_data.json", "w") as f:
        f.write(json.dumps(data))
else:
    with open("eth_data.json", "r") as f:
        data = json.load(f)

first_epoch_starttime = int(data['prices'][0][0] / 1000) // epoch_length * epoch_length

# array of tuples (epoch_starttime, epoch_price)
epochs = np.array([[]])
epoch_index = 0

for timestamp_millis, price in data['prices']:
    timestamp = int(timestamp_millis / 1000)
    epoch_starttime = first_epoch_starttime + epoch_index * epoch_length
    if epoch_starttime + mewt < timestamp:
        if epochs.size == 0:
            epochs = np.array([[epoch_starttime, price]])
        else:
            epochs = np.append(epochs, [[epoch_starttime, price]], axis=0)
        epoch_index += 1

# outputs the solidity code for adding prices to an array
price_list = ""
i = 0
for timestamp, price in epochs:
    price_list += f"prices[{i}] = {int(price*1e18)};\n"
    i += 1
with open("eth_price_list.txt", "w") as f:
    f.write(price_list)
