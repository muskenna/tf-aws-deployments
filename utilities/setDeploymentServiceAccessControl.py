import logging
from msilib.schema import Error
import boto3
import json
import os 
import sys
from configparser import ConfigParser

deploymentServiceRoleName = 'MyDeploymentService'

def setAccessControl(session, trustEntityPrincipal):
    
    stsClient = session.client('sts')            
    userIdentity = stsClient.get_caller_identity()
    message = f"Configuring deployment service access control for account {userIdentity['Account']} using user {userIdentity['Arn']}"
    logging.info(message)
    print(message)

    iamClient = session.client('iam')
    assumeRolePolicyDocument = json.dumps({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": f'{trustEntityPrincipal}'
                },
                "Action": "sts:AssumeRole",
                "Condition": {}
            }
        ]
    })

    response = {}
    try:
        response = iamClient.create_role(
            RoleName=f'{deploymentServiceRoleName}',
            AssumeRolePolicyDocument=f'{assumeRolePolicyDocument}',
            Description='Role for DevOps automated task deployments service'
        )
    except iamClient.exceptions.EntityAlreadyExistsException:
        logging.info(f'The role {deploymentServiceRoleName} already exists')
    except Exception as error:
        raise error
    # 
    # Exception has occurred: MalformedPolicyDocumentException
    # An error occurred (MalformedPolicyDocument) when calling the CreateRole operation: Invalid principal in policy: "AWS":"arn:aws:iam::085167882865:user/cloud_user"

    response = {}
    try:
        response = iamClient.attach_role_policy(
            RoleName=f'{deploymentServiceRoleName}',
            PolicyArn='arn:aws:iam::aws:policy/AdministratorAccess'
        )
        if response['ResponseMetadata']['HTTPStatusCode'] == 200:
            message = f'The AWS managed policy "AdministratorAccess" was successful attached to the role {deploymentServiceRoleName}'
            logging.info(message)
            print(message)
        else:
            message = f'Something is wrong. Check the HTTP response'
            logging.info(message)
            print(message)

    except Exception as error:
        raise error

def getAWSCredeFilePath():
    awsConfFile = ''
    userHomeFolder = os.path.expanduser('~')
    if os.name == 'nt':
        awsConfFile = os.path.join(userHomeFolder, '.aws\config')
    else:
        awsCredFile = os.path.join(userHomeFolder, '.aws/config')

    if not os.path.exists(awsConfFile):
        awsConfFile = ''
    
    return awsConfFile

def getAccountsFilePath():
    folder = os.path.dirname(os.path.realpath(__file__))
    accountsFile = os.path.join(folder, 'accounts.json')
    if not os.path.exists(accountsFile):
        accountsFile = ''
    
    return accountsFile

def checkRequirements():
    awsCredFile = getAWSCredeFilePath()
    if not awsCredFile:
        print(f'The AWS credentials file {awsCredFile} was not found. Please, install the AWS CLI')
        sys.exit(0)
    accountsFile = getAccountsFilePath()
    if not accountsFile:
        print(f'The accounts file {accountsFile} was not found. Please, create it based on the template accounts.template.json')
        sys.exit(0)
    
def createDeploymentServerAWSProfile(deploymentServiceAccountName, roleName, deploymentServiceAccountNumber):
    '''
    https://docs.python.org/3.5/library/sys.html#sys.platform
    '''
    awsConfFile = getAWSCredeFilePath()

    configProfileName = f"profile {roleName}"
    parser = ConfigParser()
    parser.read(awsConfFile)
    section = [sectionName for sectionName in parser.sections() if sectionName == configProfileName]
    if not section:
        parser.add_section(configProfileName)
    parser.set(configProfileName, 'role_arn', f'arn:aws:iam::{deploymentServiceAccountNumber}:role/{roleName}')
    parser.set(configProfileName, 'source_profile', deploymentServiceAccountName)
    with open(awsConfFile, 'w') as file:    # save
        parser.write(file)    

checkRequirements()
configFile = getAccountsFilePath()

try:
    with open(configFile, 'r') as reader:
        deploymentConfiguration = json.loads(reader.read())
except IOError:
        raise IOError('IO operation failed')
except json.JSONDecodeError:
    raise json.JSONDecodeError('Invalid Json file')

if 'deploymentService' not in deploymentConfiguration and 'targets' not in deploymentConfiguration:
    raise ValueError('Invalid configuration file (json schema)')

deploymentServiceConfigPropertyNames = list((deploymentConfiguration['deploymentService']).keys())
if not ('roleName' in deploymentServiceConfigPropertyNames and 'localAWSCredentialsProfileName' in deploymentServiceConfigPropertyNames):
    raise ValueError('Invalid configuration file (json schema)')

#############################################################
###### Deployment Service Access Control Configuration ######
#############################################################

deploymentServiceConfiguration = deploymentConfiguration['deploymentService']
localAWSCredentialsProfileName = deploymentServiceConfiguration['localAWSCredentialsProfileName']
roleName = deploymentServiceConfiguration['roleName']

deploymentServiceSession = boto3.session.Session(profile_name=localAWSCredentialsProfileName)
iamClient = deploymentServiceSession.client('iam')
identity = deploymentServiceSession.client('sts').get_caller_identity()
identityArn = identity["Arn"]
deploymentServiceAccountName = identityArn.split('/')[-1]
deploymentServiceAccountNumber = identity["Account"]
deploymentServiceTrustEntityPrincipalUser = f'arn:aws:iam::{deploymentServiceAccountNumber}:user/{deploymentServiceAccountName}'

#responseAK= iamClient.create_access_key(UserName=deploymentServiceAccountName)
# accessKeyId = responseAK['AccessKey']['AccessKeyId']
# secretAccessKey = responseAK['AccessKey']['SecretAccessKey']
createDeploymentServerAWSProfile(localAWSCredentialsProfileName, roleName, deploymentServiceAccountNumber)
setAccessControl(deploymentServiceSession, deploymentServiceTrustEntityPrincipalUser)

#############################################################
######## Target Accounts Access Control Configuration #######
#############################################################

if 'targets' in deploymentConfiguration:
    targets = deploymentConfiguration['targets']
    for targetAccountConfig in targets:
        targetAccountConfigProperties = list(targetAccountConfig.keys())
        if not ('accountNumber' in targetAccountConfigProperties and 'localAWSProfileName' in targetAccountConfigProperties):
            raise ValueError('Invalid configuration file (json schema)')

    targetAccountsConfig = targets
    targetAccountTrustEntityPrincipal = f"arn:aws:iam::{deploymentServiceAccountNumber}:role/{deploymentServiceRoleName}"

    for targetAccountConfig in targetAccountsConfig:

        targetAccountSession = boto3.session.Session(profile_name=targetAccountConfig['localAWSProfileName'])
        setAccessControl(targetAccountSession, targetAccountTrustEntityPrincipal)    


print('End of access control configuration')