import web3
import csv
import json
import os
import argparse

def find_index_by_property(array, property_name, property_value):

    """Finds the index of an object in an array of objects based on a single property.

    Args:
        array: A list of objects.
        property_name: The name of the property to match.
        property_value: The value of the property to match.

    Returns:
        The index of the object in the array, or -1 if the object is not found.
    """

    for i in range(len(array)):
        object = array[i]
        if object[property_name] == property_value:
            return i
    return -1

output_directory = './outputs'
os.makedirs(output_directory, exist_ok=True)

parser = argparse.ArgumentParser()
parser.add_argument("--filterAmount", type=float, default=0, help="Amount of tokens minimum to be included in the filter")
args = parser.parse_args()

filter_amount = web3.Web3.toWei(args.filterAmount, "ether")

with open("./holders0.csv", "r") as etherscan_export:
    reader = csv.reader(etherscan_export)
    
    holders = []
    balances = []
    offset_tier1 = 0
    offset_tier2 = 0

    with open("./excludedAddresses.json", "r") as excluded_addresses:
        excluded = json.load(excluded_addresses)
        excluded = excluded["exclusions"]
        for row in reader:
            # Filter balances
            balanceString = float(row[1].replace(",", ""))
            balance = web3.Web3.toWei(balanceString, "ether")
            if(balance < filter_amount):
                continue

            # Modify address into checksum version
            addressString = row[0]
            address = web3.Web3.toChecksumAddress(addressString)
            # Check if address is excluded
            exclusionIndex = find_index_by_property(excluded, "address", address)
            if exclusionIndex == -1:
                holders.append(address)
                balances.append(balance)
            # IF excluded and not excluded in token, then add to tier offset
            elif not(excluded[exclusionIndex]["excludedInToken"]):
                if(balance >= web3.Web3.toWei(50_000, "ether")):
                    offset_tier1 += balance
                elif(balance >= web3.Web3.toWei(1_000, "ether")):
                    offset_tier2 += balance

    with open(output_directory + "/holders0.json", "w") as holders_json:
        obj = {
            "input": {
                "holders": holders,
                "balances": balances,
                "offset_tier1": offset_tier1,
                "offset_tier2": offset_tier2
            }
        }
        json.dump(obj, holders_json)

