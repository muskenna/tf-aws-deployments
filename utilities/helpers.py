import json
import sys

def _finditem(obj, key):
    if key in obj: return obj[key]
    for k, v in obj.items():
        if isinstance(v,dict):
            item = _finditem(v, key)
            if item is not None:
                return item

def getAWSAuthorizedAccountIds():
    #workingDir = os.getcwd()
    #deploymentsFile = os.path.join(workingDir, "deployments.json")
    try:
        #deploymentsFileObject = open(deploymentsFile)
        deploymentsFileObject = open("deployments.json")
    except:
        raise Exception
    deployments = json.load(deploymentsFileObject)
    accountIds = []
    for k, v in deployments['deployments'].items():
        accountId = _finditem(v, "account_id")
        accountIds.append(accountId)

    sys.stdout.write(",".join(accountIds))
    sys.stdout.flush()
    sys.exit(0)
#deployments['production']['regions']['ca-central-1']['account_id']