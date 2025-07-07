# Default set
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region $AWS_REGION
aws configure set default.output "json"

#--------------------------------------------------------------------------------

# Make SSH RSA key
ssh-keygen -t rsa -b 4096 -f $HOME/ssh -N ""
mv $HOME/ssh $HOME/ssh.pem

# Upload a new key pair
sudo aws s3 cp $HOME/ssh.pem s3://$PROJECT_NAME-$CLUSTER_UUID/keypair.pem

# Make a new S3 bucket for this project
aws s3 mb s3://$PROJECT_NAME-$CLUSTER_UUID