import numpy as np
import json
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd

epoch_length = 3600
mewt = 10

pool_types = ["short", "long", "float"]

def get_token_data(first_epoch_starttime):
    epochs = np.array([{"epoch": 0}])

    with open("token_price_data.txt", "r") as f:
        for line in f:
            try:
                line.index("currentEpochIndex")
                s = line.split(" ")
                epochs = np.append(epochs, {
                    "epoch": int(s[3]),
                    "timestamp": first_epoch_starttime + int(s[3]) * epoch_length
                })
            except Exception:
                try:
                    line.index("price")
                    s = line.split(":")[-1].split(" ")
                    a = pool_types[int(s[1])]
                    if a in epochs[-1]:
                        epochs[-1][a][int(s[2])] = float(s[3]) / 1e18
                    else:
                        epochs[-1][a] = {int(s[2]): float(s[3]) / 1e18}
                except Exception:
                    try:
                        line.index("Diff")
                        s = line.split(":")[-1].split(" ")
                        a = int(s[1])
                        epochs[-1]["diff"] = a
                    except Exception:
                        continue
    return epochs


def get_epoch_data():
    first_epoch_starttime = 0
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
    return (epochs, first_epoch_starttime)


def get_scatter(dataframe, name):
    return go.Scatter(x=dataframe["timestamp"], y=dataframe["price"], name=name, line=dict(dash='solid'))


(arr_epoch_data, first_epoch_starttime) = get_epoch_data()
df = pd.DataFrame(arr_epoch_data[:399], columns = ['timestamp', 'price'])

arr_token_data = get_token_data(first_epoch_starttime)[1:]
short_0 = pd.DataFrame(np.array([[i["timestamp"], i["short"][0]] for i in arr_token_data]), columns = ['timestamp', "price"])
short_1 = pd.DataFrame(np.array([[i["timestamp"], i["short"][1]] for i in arr_token_data]), columns = ['timestamp', "price"])
long_0 = pd.DataFrame(np.array([[i["timestamp"], i["long"][0]] for i in arr_token_data]), columns = ['timestamp', "price"])
long_1 = pd.DataFrame(np.array([[i["timestamp"], i["long"][1]] for i in arr_token_data]), columns = ['timestamp', "price"])
float_0 = pd.DataFrame(np.array([[i["timestamp"], i["float"][0]] for i in arr_token_data]), columns = ['timestamp', "price"])
diff = pd.DataFrame(np.array([[i["timestamp"], i["diff"]] for i in arr_token_data]), columns = ['timestamp', "price"])

plot = make_subplots(specs=[[{"secondary_y": True}]])

#plot.add_trace(get_scatter(short_0, "short 1x"), secondary_y=False)
#plot.add_trace(get_scatter(short_1, "short 3x"), secondary_y=False)
#plot.add_trace(get_scatter(long_0, "long 1x"), secondary_y=False)
#plot.add_trace(get_scatter(long_1, "long 2x"), secondary_y=False)
#plot.add_trace(get_scatter(float_0, "float_0"), secondary_y=False)
plot.add_trace(get_scatter(diff, "Diff"), secondary_y=False)
plot.add_trace(get_scatter(df, "ETH"), secondary_y=True)

plot.update_layout(
    title_text=f'Leaking of total liquidity',
    title_x=0.5,
)
plot.update_xaxes(title_text='Timestamp')
plot.update_yaxes(title_text='Token Price', secondary_y=False)
plot.update_yaxes(title_text='ETH Price', secondary_y=True)

plot.show()
