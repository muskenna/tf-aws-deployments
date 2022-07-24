import logging
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
    awsCredFile = ''
    userHomeFolder = os.path.expanduser('~')
    if os.name == 'nt':
        awsCredFile = os.path.join(userHomeFolder, '.aws\credentials')
    else:
        awsCredFile = os.path.join(userHomeFolder, '.aws/credentials')

    if not os.path.exists(awsCredFile):
        awsCredFile = ''
    
    return awsCredFile, awsCredFile.replace('credentials', 'config')

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
    
def createDeploymentServerAWSProfile(deploymentServiceAccountName, accessKey, secretKey, localAWSConfigProfileName, deploymentServiceAccountNumber, roleArn):
    '''
    https://docs.python.org/3.5/library/sys.html#sys.platform
    '''
    awsCredFile, awsConfFile = getAWSCredeFilePath()
    parser = ConfigParser()
    parser.read(awsCredFile)
    section = [sectionName for sectionName in parser.sections() if sectionName == deploymentServiceAccountName]
    if not section:
        parser.add_section(deploymentServiceAccountName)
    parser.set(deploymentServiceAccountName, 'aws_access_key_id', accessKey)
    parser.set(deploymentServiceAccountName, 'aws_secret_access_key', secretKey)
    with open(awsCredFile, 'w') as file:    # save
        parser.write(file)

    configProfileName = f"profile {localAWSConfigProfileName}"
    parser = ConfigParser()
    parser.read(awsConfFile)
    section = [sectionName for sectionName in parser.sections() if sectionName == configProfileName]
    if not section:
        parser.add_section(configProfileName)
    parser.set(configProfileName, 'role_arn', roleArn)
    parser.set(configProfileName, 'source_profile', deploymentServiceAccountName)
    with open(awsConfFile, 'w') as file:    # save
        parser.write(file)    

checkRequirements()
configFile = getAccountsFilePath()

try:
    with open(configFile, 'r') as reader:
        accounts = json.loads(reader.read())
except IOError:
        raise IOError('IO operation failed')
except json.JSONDecodeError:
    raise json.JSONDecodeError('Invalid Json file')

if 'deploymentService' not in accounts and 'targets' not in accounts:
    raise ValueError('Invalid configuration file (json schema)')

deploymentServiceConfigProperties = list((accounts['deploymentService']).keys())
if not ('accountAlias' in deploymentServiceConfigProperties and 'accountNumber' in deploymentServiceConfigProperties and 'localAWSProfileName' in deploymentServiceConfigProperties):
    raise ValueError('Invalid configuration file (json schema)')

#############################################################
###### Deployment Service Access Control Configuration ######
#############################################################

deploymentAccountConfig = accounts['deploymentService']
deploymentServiceAccountName = accounts['deploymentService']['deploymentServiceAccountName']
localAWSConfigProfileName = accounts['deploymentService']['localAWSConfigProfileName']
deploymentServiceAccountNumber = deploymentAccountConfig['accountNumber']
#deploymentServiceTrustEntityPrincipal = f"arn:aws:iam::{deploymentServiceAccountNumber}:root"
deploymentServiceTrustEntityPrincipalSelf = f'arn:aws:iam::{deploymentServiceAccountNumber}:user/{deploymentServiceAccountName}'
deploymentServiceTrustEntityPrincipal = f'arn:aws:iam::{deploymentServiceAccountNumber}:role/{localAWSConfigProfileName}'
deploymentServiceSession = boto3.session.Session(profile_name=deploymentAccountConfig['localAWSProfileName'])
iamClient = deploymentServiceSession.client('iam')

try:
    response = iamClient.create_user(UserName=deploymentServiceAccountName)
except:
    print("User already exist or error")

responseAK= iamClient.create_access_key(UserName=deploymentServiceAccountName)
createDeploymentServerAWSProfile(deploymentServiceAccountName, responseAK['AccessKey']['AccessKeyId'], responseAK['AccessKey']['SecretAccessKey'], localAWSConfigProfileName, deploymentServiceAccountNumber, deploymentServiceTrustEntityPrincipal)
setAccessControl(deploymentServiceSession, deploymentServiceTrustEntityPrincipalSelf)

#############################################################
######## Target Accounts Access Control Configuration #######
#############################################################

if 'targets' in accounts:
    
    for targetAccountConfig in accounts['targets']:
        targetAccountConfigProperties = list(targetAccountConfig.keys())
        if not ('accountAlias' in targetAccountConfigProperties and 'accountNumber' in targetAccountConfigProperties and 'localAWSProfileName' in targetAccountConfigProperties):
            raise ValueError('Invalid configuration file (json schema)')

    targetAccountsConfig = accounts['targets']
    targetAccountTrustEntityPrincipal = f"arn:aws:iam::{deploymentServiceAccountNumber}:role/{deploymentServiceRoleName}"

    for targetAccountConfig in targetAccountsConfig:

        targetAccountSession = boto3.session.Session(profile_name=targetAccountConfig['localAWSProfileName'])
        setAccessControl(targetAccountSession, targetAccountTrustEntityPrincipal)    


print('End of access control configuration')