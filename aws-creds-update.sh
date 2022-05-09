#!/bin/bash

# Requirements:
# packages: jq awscli
# Usage: 
# add an alias like:
# alias token-aws='<PATH>/aws-creds-update.sh'
# rename/copy config.vars-temp to config.vars and edit it
# then:
# $ token-aws 000000 [another duration, in seconds, if needed]

# check requirements
type jq >/dev/null 2>&1 || { printf >&2 "jq is required for this script (snap install jq?), but it's not installed. Aborting."; exit 1; }
type aws >/dev/null 2>&1 || { printf >&2 "aws is required for this script (snap install aws-cli?), but it's not installed. Aborting."; exit 1; }

# preparing jq filter
jq_filter='.[].Credentials.AccessKeyId,.[].Credentials.SecretAccessKey,.[].Credentials.SessionToken,.[].Credentials.Expiration'

# preparing jq output file
jq_output_filename="aws-token-creds-"`date +%s`

if [ -f ~/.$jq_output_filename ] ; then
    rm ~/.$jq_output_filename
fi

# loading vars file
DIR="${BASH_SOURCE%/*}"

if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/config.vars"

read -p 'Token: ' token

# need another duration?
special_duration=$1
duration=${special_duration:=$token_duration}

# get the token
aws sts get-session-token --profile $aws_base_profile --token-code $token --serial-number $mfa_token_sn --duration-seconds $duration | jq --slurp -r $jq_filter > ~/.$jq_output_filename

# update aws profile
if [ $(sed '1q;d' ~/.$jq_output_filename) ]; then
    aws --profile $aws_update_profile configure set aws_access_key_id $(sed '1q;d' ~/.$jq_output_filename)
fi

if [ $(sed '2q;d' ~/.$jq_output_filename) ]; then
    aws --profile $aws_update_profile configure set aws_secret_access_key $(sed '2q;d' ~/.$jq_output_filename)
fi

if [ $(sed '3q;d' ~/.$jq_output_filename) ]; then
  aws --profile $aws_update_profile configure set aws_session_token $(sed '3q;d' ~/.$jq_output_filename)
fi

if [ $(sed '4q;d' ~/.$jq_output_filename) ]; then
    echo "Done! Valid until $(sed '4q;d' ~/.$jq_output_filename) (UTC)"
else
    echo "Epic Fail! Please read the docs."
fi

# final cleanup
if [ -f ~/.$jq_output_filename ] ; then
    rm ~/.$jq_output_filename
fi
